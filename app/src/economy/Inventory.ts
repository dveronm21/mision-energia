import type { IInventory, Inventory as InventoryMap, ISaveStore } from '../contracts';

type Slot = 'helmet' | 'vest';
interface InventoryData { items: InventoryMap; equipped: Record<Slot, string | null>; }
const KEY = 'inventory';

/** Inventario persistente: boosters (consumibles) y cosméticos (permanentes, uno equipado por slot). */
export class Inventory implements IInventory {
  private data: InventoryData;

  constructor(private readonly store: ISaveStore) {
    const d = store.load<InventoryData>(KEY, { items: {}, equipped: { helmet: null, vest: null } });
    this.data = { items: { ...(d.items ?? {}) }, equipped: { helmet: d.equipped?.helmet ?? null, vest: d.equipped?.vest ?? null } };
  }

  count(productId: string): number { return this.data.items[productId] ?? 0; }

  grant(productId: string, qty: number): void {
    const q = Math.floor(qty);
    if (!(q > 0)) return;
    this.data.items[productId] = this.count(productId) + q;
    this.persist();
  }

  consume(productId: string): boolean {
    const c = this.count(productId);
    if (c <= 0) return false;
    if (c === 1) delete this.data.items[productId]; else this.data.items[productId] = c - 1;
    this.persist();
    return true;
  }

  equippedCosmetic(slot: Slot): string | null { return this.data.equipped[slot]; }

  /** Equipa un cosmético que se tenga (o null para el default). Si no se tiene, no hace nada. */
  equip(slot: Slot, productId: string | null): void {
    if (productId !== null && this.count(productId) <= 0) return;
    this.data.equipped[slot] = productId;
    this.persist();
  }

  private persist(): void { this.store.save(KEY, this.data); }
}
