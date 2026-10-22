import type { IEventBus, IInventory, IPaymentProvider, ISaveStore, IShop, IWallet, PaymentResult, Product } from '../contracts';
import type { Catalog } from './Catalog';

const ORDERS_KEY = 'shop.creditedOrders';

/**
 * Tienda. Packs de Soles: proveedor.purchase → proveedor.verifyOnServer → recién ahí acredita
 * (y una sola vez por orderId). Boosters/cosméticos: se pagan con Soles.
 * La UI debe pasar el IParentalGate ANTES de llamar a buyTokenPack.
 */
export class Shop implements IShop {
  private credited: string[];

  constructor(
    private readonly products: Catalog,
    private readonly wallet: IWallet,
    private readonly inventory: IInventory,
    private readonly payments: IPaymentProvider,
    private readonly store: ISaveStore,
    private readonly bus: IEventBus | null = null,
  ) {
    this.credited = store.load<string[]>(ORDERS_KEY, []);
  }

  catalog(): Product[] { return this.products.all(); }

  /** true si el proveedor actual es de demostración (la UI muestra "precio de prueba"). */
  isDemo(): boolean { return this.payments.isDemo; }

  async buyTokenPack(productId: string): Promise<PaymentResult> {
    const p = this.products.find(productId);
    if (!p || p.kind !== 'token-pack' || !p.soles) {
      return { status: 'failed', orderId: '', productId, message: 'Ese producto no es un pack de Soles.' };
    }
    let result: PaymentResult;
    try { result = await this.payments.purchase(p); } catch {
      return { status: 'failed', orderId: '', productId, message: 'No se pudo iniciar el pago.' };
    }
    if (result.status !== 'approved') return result;
    let verified = false;
    try { verified = await this.payments.verifyOnServer(result); } catch { verified = false; }
    if (!verified) return { ...result, status: 'failed', message: 'No pudimos confirmar el pago. No se cobró ningún Sol.' };
    if (this.credited.includes(result.orderId)) return { ...result, message: 'Esta compra ya estaba acreditada.' };
    this.credited.push(result.orderId);
    this.store.save(ORDERS_KEY, this.credited);
    this.wallet.add(p.soles, `Compra ${p.id} (${result.orderId})`);
    this.bus?.emit({ type: 'sfx', name: 'coin' });
    return { ...result, message: `¡Listo! Sumaste ${p.soles} Soles.` };
  }

  buyWithSoles(productId: string): boolean {
    const p = this.products.find(productId);
    if (!p || (p.kind !== 'booster' && p.kind !== 'cosmetic') || p.costSoles === undefined) return false;
    if (p.kind === 'cosmetic' && this.inventory.count(p.id) > 0) return false; // permanente: ya lo tenés
    if (!this.wallet.spend(p.costSoles, `Tienda: ${p.title}`)) return false;
    this.inventory.grant(p.id, 1);
    this.bus?.emit({ type: 'sfx', name: 'coin' });
    return true;
  }
}
