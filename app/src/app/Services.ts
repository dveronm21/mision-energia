/**
 * Servicios de dominio (composition root del dominio), en el orden recomendado:
 * store → bus → audio → wallet → inventory → catalog → shop(DemoPaymentProvider) → rewards → levels → progress.
 * El audio se crea una sola vez (sobrevive a "Reiniciar progreso").
 */
import type { IAudio, IEventBus } from '../contracts';
import { EventBus } from '../core/EventBus';
import { SaveStore } from '../core/SaveStore';
import { Boosters } from '../economy/Boosters';
import { Catalog } from '../economy/Catalog';
import { Inventory } from '../economy/Inventory';
import { ParentalGate } from '../economy/ParentalGate';
import { RewardService } from '../economy/RewardService';
import { Shop } from '../economy/Shop';
import { Wallet } from '../economy/Wallet';
import { DemoPaymentProvider } from '../economy/payments/DemoPaymentProvider';
import { LevelCatalog } from '../levels/LevelCatalog';
import { LevelManager } from '../levels/LevelManager';

export class Services {
  readonly wallet: Wallet;
  readonly inventory: Inventory;
  readonly catalog: Catalog;
  readonly shop: Shop;
  readonly rewards: RewardService;
  readonly levels: LevelCatalog;
  readonly progress: LevelManager;
  readonly boosters: Boosters;
  readonly gate = new ParentalGate();

  constructor(readonly store: SaveStore, readonly bus: IEventBus, readonly audio: IAudio) {
    this.wallet = new Wallet(store, bus);
    this.inventory = new Inventory(store);
    this.catalog = new Catalog();
    this.shop = new Shop(this.catalog, this.wallet, this.inventory, new DemoPaymentProvider(), store, bus);
    this.rewards = new RewardService(this.wallet, store);
    this.levels = new LevelCatalog();
    this.progress = new LevelManager(this.levels, store, this.wallet);
    this.boosters = new Boosters(this.inventory);
  }

  static createBus(): EventBus {
    return new EventBus((err) => console.error('[bus]', err));
  }
}
