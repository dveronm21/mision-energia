import type { Product, ProductKind } from '../contracts';

/**
 * Catálogo de productos. Principios (público infantil/familiar):
 *  - Toda la campaña se puede terminar sin pagar (los Soles se ganan con estrellas, regalo y bono diario).
 *  - Nada aleatorio pago: cada producto dice exactamente lo que da.
 *  - Los boosters ayudan pero no reemplazan aprender (no ganan el nivel solos).
 * Precios de packs en centavos de ARS: son PRECIOS DE PRUEBA mientras el pago real no esté configurado.
 */
export const PRODUCTS: Product[] = [
  { id: 'pack_small', kind: 'token-pack', title: 'Bolsita de Soles', description: '120 Soles.', soles: 120, priceCents: 99900, currency: 'ARS', icon: 'sun-small' },
  { id: 'pack_medium', kind: 'token-pack', title: 'Caja de Soles', description: '500 Soles + 150 de regalo.', soles: 650, priceCents: 399900, currency: 'ARS', icon: 'sun-medium' },
  { id: 'pack_large', kind: 'token-pack', title: 'Cofre de Soles', description: '1000 Soles + 400 de regalo.', soles: 1400, priceCents: 699900, currency: 'ARS', icon: 'sun-large' },

  { id: 'boost_hint', kind: 'booster', title: 'Pista', description: 'Resalta el próximo paso de la obra.', costSoles: 10, consumable: true, icon: 'hint' },
  { id: 'boost_drone', kind: 'booster', title: 'Dron limpiador', description: 'Después del Zonda, limpia el polvo de todas las filas.', costSoles: 25, consumable: true, icon: 'drone' },
  { id: 'boost_battery', kind: 'booster', title: 'Batería de emergencia', description: 'Suma 4 kWh ya cargados, una sola vez.', costSoles: 35, consumable: true, icon: 'battery-plus' },
  { id: 'boost_budget', kind: 'booster', title: 'Presupuesto extra', description: '+15% de créditos de obra en un nivel.', costSoles: 40, consumable: true, icon: 'coins' },

  { id: 'skin_helmet_blue', kind: 'cosmetic', title: 'Casco azul', description: 'Casco de técnico color azul.', costSoles: 60, consumable: false, icon: 'helmet' },
  { id: 'skin_helmet_orange', kind: 'cosmetic', title: 'Casco naranja', description: 'Casco de técnico color naranja.', costSoles: 60, consumable: false, icon: 'helmet' },
  { id: 'skin_helmet_white', kind: 'cosmetic', title: 'Casco blanco', description: 'Casco de ingeniería, blanco.', costSoles: 90, consumable: false, icon: 'helmet' },
  { id: 'skin_vest_green', kind: 'cosmetic', title: 'Chaleco verde', description: 'Chaleco reflectivo verde.', costSoles: 60, consumable: false, icon: 'vest' },
  { id: 'skin_vest_yellow', kind: 'cosmetic', title: 'Chaleco amarillo', description: 'Chaleco reflectivo amarillo.', costSoles: 60, consumable: false, icon: 'vest' },
  { id: 'skin_vest_violet', kind: 'cosmetic', title: 'Chaleco violeta', description: 'Chaleco reflectivo violeta.', costSoles: 90, consumable: false, icon: 'vest' },
];

/** Colores (hex) de cada cosmético, para WorkerRig.setCosmetics. */
export const COSMETIC_COLORS: Record<string, number> = {
  skin_helmet_blue: 0x2f7be0, skin_helmet_orange: 0xf28c28, skin_helmet_white: 0xf4f4f0,
  skin_vest_green: 0x3cc65a, skin_vest_yellow: 0xf2d22e, skin_vest_violet: 0x8b5cf6,
};

export class Catalog {
  constructor(private readonly products: Product[] = PRODUCTS) {}

  all(): Product[] { return this.products.map((p) => ({ ...p })); }

  find(id: string): Product | null {
    const p = this.products.find((x) => x.id === id);
    return p ? { ...p } : null;
  }

  get(id: string): Product {
    const p = this.find(id);
    if (!p) throw new Error(`Producto desconocido: ${id}`);
    return p;
  }

  byKind(kind: ProductKind): Product[] { return this.all().filter((p) => p.kind === kind); }

  /** Slot de un cosmético según su id ('skin_helmet_*' / 'skin_vest_*'), o null. */
  cosmeticSlot(id: string): 'helmet' | 'vest' | null {
    if (id.startsWith('skin_helmet_')) return 'helmet';
    if (id.startsWith('skin_vest_')) return 'vest';
    return null;
  }
}
