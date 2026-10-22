import type { IPaymentProvider, PaymentResult, Product } from '../../contracts';

/**
 * STUB de Mercado Pago (Checkout Pro). Hoy rechaza todo con status 'failed'.
 *
 * Flujo real a implementar (nunca acreditar desde el cliente sin confirmación del servidor):
 *  1. purchase(product): POST {backendUrl}/payments/preferences { productId, installId }.
 *     El BACKEND (con el access token privado, que jamás viaja a la app) crea la preferencia en
 *     la API de Mercado Pago con el precio del catálogo del servidor (no el del cliente),
 *     external_reference = orderId propio y notification_url = webhook. Devuelve { orderId, initPoint }.
 *  2. La app abre initPoint (Checkout Pro) en un Custom Tab / navegador externo desde el WebView
 *     (puente nativo Android). Las back_urls vuelven a la app con deep link misionenergia://pago.
 *  3. Mercado Pago notifica al webhook del backend; el backend consulta GET /v1/payments/{id},
 *     valida monto, moneda y external_reference, y marca la orden como 'approved' (idempotente).
 *  4. Al volver a la app, purchase resuelve { status: 'pending', orderId }; la UI hace polling a
 *     verifyOnServer(result) → GET {backendUrl}/payments/orders/{orderId} → true solo si 'approved'.
 *     Recién ahí el Shop acredita los Soles (una vez por orderId).
 *  Nota: para apps distribuidas por Google Play, los bienes digitales deben venderse con
 *  Google Play Billing (GooglePlayBillingProvider); Mercado Pago aplica a otras distribuciones.
 */
export class MercadoPagoProvider implements IPaymentProvider {
  readonly id = 'mercadopago' as const;
  readonly isDemo = false;

  constructor(private readonly backendUrl: string | null = null) {}

  async purchase(product: Product): Promise<PaymentResult> {
    void this.backendUrl;
    return { status: 'failed', orderId: '', productId: product.id, message: 'Pagos reales aún no configurados' };
  }

  async verifyOnServer(_result: PaymentResult): Promise<boolean> {
    return false;
  }
}
