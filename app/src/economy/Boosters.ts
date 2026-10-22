import type { IInventory, LevelDefinition } from '../contracts';

export type BoosterId = 'boost_hint' | 'boost_drone' | 'boost_battery' | 'boost_budget';

/** Efectos numéricos de los boosters (fuente única para juego, UI y balance). */
export const BOOSTER_EFFECTS = {
  /** kWh ya cargados que suma la batería de emergencia (PlantState.bonusKwh). */
  batteryBonusKwh: 4,
  /** Multiplicador de presupuesto de obra del nivel. */
  budgetMultiplier: 1.15,
} as const;

/** Uso de boosters: consume del inventario y devuelve si se pudo. Los efectos los aplica el juego. */
export class Boosters {
  constructor(private readonly inventory: IInventory) {}

  available(id: BoosterId): number { return this.inventory.count(id); }

  use(id: BoosterId): boolean { return this.inventory.consume(id); }

  /** Presupuesto de obra con o sin boost_budget. Las estrellas se siguen midiendo contra level.budget. */
  budgetFor(level: LevelDefinition, boosted: boolean): number {
    return boosted ? Math.round(level.budget * BOOSTER_EFFECTS.budgetMultiplier) : level.budget;
  }

  /** Valor para PlantState.bonusKwh. */
  bonusKwh(boosted: boolean): number { return boosted ? BOOSTER_EFFECTS.batteryBonusKwh : 0; }
}
