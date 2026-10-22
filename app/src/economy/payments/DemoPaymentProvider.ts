import type { IPaymentProvider, PaymentResult, Product } from '../../contracts';

export interface DemoPaymentOptions {
  delayMs?: number;
  /** Para ids reproducibles en tests. */
  idGen?: () => string;
}

/** Pago SIMULADO: espera ~600 ms y aprueba. Órdenes con prefijo "DEMO-". No mueve dinero real. */
export class DemoPaymentProvider implements IPaymentProvider {
  readonly id = 'demo' as const;
  readonly isDemo = true;
  private readonly delayMs: number;
  private readonly idGen: () => string;

  constructor(opts: DemoPaymentOptions = {}) {
    this.delayMs = opts.delayMs ?? 600;
    let seq = 0;
    this.idGen = opts.idGen ?? (() => `${Date.now().toString(36)}-${(++seq).toString(36)}`);
  }

  purchase(product: Product): Promise<PaymentResult> {
    return new Promise((resolve) => {
      setTimeout(() => resolve({ status: 'approved', orderId: `DEMO-${this.idGen()}`, productId: product.id, message: 'Pago de prueba aprobado.' }), this.delayMs);
    });
  }

  async verifyOnServer(result: PaymentResult): Promise<boolean> {
    return result.status === 'approved' && result.orderId.startsWith('DEMO-');
  }
}
