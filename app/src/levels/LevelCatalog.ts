import type { ILevelCatalog, LevelDefinition, LevelId } from '../contracts';
import { LEVELS } from './levels';

/** Catálogo inmutable de niveles, ordenado por `order`. Se le pueden inyectar definiciones (tests/balance). */
export class LevelCatalog implements ILevelCatalog {
  private readonly levels: LevelDefinition[];

  constructor(levels: LevelDefinition[] = LEVELS) {
    this.levels = [...levels].sort((a, b) => a.order - b.order);
  }

  all(): LevelDefinition[] { return [...this.levels]; }

  get(id: LevelId): LevelDefinition {
    const l = this.levels.find((x) => x.id === id);
    if (!l) throw new Error(`Nivel desconocido: ${id}`);
    return l;
  }

  /** Nivel que se desbloquea al completar `id` (el que lo tiene en `requires`), o null. */
  next(id: LevelId): LevelDefinition | null {
    return this.levels.find((x) => x.requires === id) ?? null;
  }

  /** Costo de una compra del taller con los precios del nivel. */
  cost(level: LevelDefinition, p: { panels: number; batteries: number; kitZonda: boolean }): number {
    const pr = level.prices;
    return pr.basePackage + p.panels * pr.panel + p.batteries * pr.battery + (p.kitZonda ? pr.kitZonda : 0);
  }
}
