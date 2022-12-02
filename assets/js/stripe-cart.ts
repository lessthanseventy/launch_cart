import { html, LitElement } from 'lit'
import { customElement, property, query, state } from 'lit/decorators.js'
import { liveState, liveStateConfig } from 'phx-live-state';

type CartItem = {
  product: Product;
  quantity: number;
  price: number
}

type Product = {
  description: string;
  id: string;
  images: string[];
}

type Cart = {
  items: Array<CartItem>;
  total: number;
}

@customElement('stripe-cart')
@liveState({
  properties: ['cart'],
  provide: {
    scope: window,
    name: 'cartState'
  },
  events: {
    send: ['checkout'],
    receive: ['checkout_redirect', 'cart_created', 'checkout_complete']
  }
})
export class StripeCartElement extends LitElement {

  @property()
  @liveStateConfig('url')
  url: string | undefined;
  
  @property({attribute: "store-id"})
  @liveStateConfig('params.store_id')
  storeId: string;

  @state()
  cart: Cart | undefined;

  @query('sl-dialog#cart-details')
  cartDetails: HTMLElement | undefined;

  @query('sl-dialog#thank-you')
  thanks: HTMLElement | undefined;

  @liveStateConfig('topic')
  get channelName() { 
    const cartId =  window.localStorage.getItem('cart_id');
    return cartId ? `stripe_cart:${cartId}` : 'stripe_cart:new';
  }

  constructor() {
    super();
    this.addEventListener('checkout_redirect', (e: CustomEvent<{ checkout_url: string }>) => {
      window.location.href = e.detail.checkout_url;
    });
    this.addEventListener('checkout_complete', (e: CustomEvent) => {
      this.showThanks();
      window.localStorage.removeItem('cart_id');
    });
    this.addEventListener('cart_created', (e: CustomEvent<{ cart_id: string }>) => {
      console.log('cart created')
      window.localStorage.setItem('cart_id', e.detail.cart_id);
    });
  }

  itemCount() {
    return this.cart && this.cart.items && this.cart.items.length > 0 ? html`
      <sl-badge pill>${this.cart.items.length}</sl-badge>
    ` : ``;
  }

  expandCart() {
    this.cartDetails && (this.cartDetails as any).show();
  }

  showThanks() {
    this.thanks && (this.thanks as any).show();
  }

  render() {
    return html`
    <sl-dialog id="thank-you">
      Thanks for purchasing!
    </sl-dialog>
    <sl-dialog id="cart-details">
      <table>
        <thead>
          <tr>
            <th>Item</th>
            <th>Quantity</th>
            <th>Price</th>
          </tr>
        </thead>
        <tbody>
          ${this.cart?.items.map(item => html`
          <tr>
            <td>${item.product.description}</td>
            <td>${item.quantity}</td>
            <td>${item.price}</td>
          </tr>
          `)}
        </tbody>
      </table>
      <button @click=${this.checkout}>Check out</button>
    </sl-dialog>
    <sl-button @click=${this.expandCart}>
      <sl-icon name="cart" style="font-size: 2em;"></sl-icon>
      ${this.itemCount()}
    </sl-button>
    `;
  }

  checkout(_e: Event) {
    this.dispatchEvent(new CustomEvent('checkout', { detail: { return_url: window.location.href } }))
  }

}

declare global {
  interface HTMLElementEventMap {
    'checkout_redirect': CustomEvent<{ checkout_url: string }>;
  }
}