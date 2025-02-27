defmodule LaunchCartWeb.LaunchCartChannelTest do
  use LaunchCartWeb.ChannelCase

  alias LaunchCart.Carts
  alias LaunchCart.Test.FakeLaunch

  import Phoenix.ChannelTest
  import LaunchCart.Factory

  setup do
    stripe_account = insert(:stripe_account, stripe_id: "acc_valid_account")

    {:ok,
     %{
       products: FakeLaunch.populate_cache(),
       store: insert(:store, stripe_account: stripe_account)
     }}
  end

  describe "joining with new cart" do
    setup %{store: store} do
      {:ok, _, socket} =
        LaunchCartWeb.UserSocket
        |> socket("user_id", %{some: :assign})
        |> subscribe_and_join(LaunchCartWeb.LaunchCartChannel, "launch_cart:#{store.id}", %{
          "cart_id" => ""
        })

      %{socket: socket}
    end

    test "joining adds store id to assigns", %{
      socket: %{assigns: %{store_id: store_id}},
      store: store
    } do
      assert store_id == store.id
    end

    test "add_item", %{socket: socket, store: %{id: store_id}} do
      push(socket, "lvs_evt:add_cart_item", %{"stripe_price" => "price_123"})

      assert_push("state:change", %{
        state: %{cart: %{id: cart_id, items: [%{stripe_price_id: "price_123"}]}},
        version: 1
      })

      assert_push("cart_created", %{cart_id: ^cart_id})

      assert %{store_id: ^store_id} = Carts.get_cart!(cart_id)
    end
  end

  describe "joining with existing cart" do
    setup %{store: %{id: store_id}} do
      {:ok, cart} = Carts.create_cart(store_id)
      {:ok, cart} = Carts.add_item(cart, "price_123")

      {:ok, _, socket} =
        LaunchCartWeb.UserSocket
        |> socket("user_id", %{some: :assign})
        |> subscribe_and_join(LaunchCartWeb.LaunchCartChannel, "launch_cart:#{store_id}", %{
          "cart_id" => cart.id
        })

      %{socket: socket, cart: cart}
    end

    test "loads existing cart into state", %{cart: %{id: cart_id}} do
      assert_push("state:change", %{
        state: %{cart: %{id: ^cart_id, items: [%{stripe_price_id: "price_123"}]}},
        version: 0
      })
    end

    test "increase_quanitty", %{cart: %{id: cart_id, items: [%{id: item_id}]}, socket: socket} do
      push(socket, "lvs_evt:increase_quantity", %{"item_id" => item_id})

      assert_push("state:change", %{
        state: %{cart: %{id: cart_id, items: [%{stripe_price_id: "price_123", quantity: 2}]}},
        version: 1
      })
    end

    test "checking out", %{cart: %{id: cart_id}, socket: socket} do
      push(socket, "lvs_evt:checkout", %{"return_url" => "http://foo.bar"})

      assert_push("state:change", %{state: %{cart: %{id: ^cart_id, status: :checkout_started}}})
      assert_push("checkout_redirect", %{checkout_url: checkout_url})
      assert checkout_url
    end
  end

  test "joining with non-existent cart and adding an item", %{store: %{id: store_id}} do
    {:ok, _, socket} =
      LaunchCartWeb.UserSocket
      |> socket("my_socket", %{})
      |> subscribe_and_join(LaunchCartWeb.LaunchCartChannel, "launch_cart:#{store_id}", %{
        "cart_id" => "garbage"
      })

    assert_push("state:change", %{state: %{}})
    push(socket, "lvs_evt:add_cart_item", %{"stripe_price" => "price_123"})

    assert_push("state:change", %{
      state: %{cart: %{id: cart_id, items: [%{stripe_price_id: "price_123"}]}}
    })

    assert_push("cart_created", %{cart_id: ^cart_id})
  end

  test "joining with completed cart" do
    cart = insert(:cart, status: :checkout_complete)

    {:ok, _, socket} =
      LaunchCartWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(LaunchCartWeb.LaunchCartChannel, "launch_cart:#{cart.store_id}", %{
        "cart_id" => cart.id
      })

    assert_push("state:change", %{state: %{}})
    assert_push("checkout_complete", %{})
  end
end
