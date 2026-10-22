/**
 * Jugador automático para tests y balance: reproduce lo que haría el mundo 3D
 * (fallas, Zonda, defensa, limpieza) contra el simulador real, con paso fijo.
 */
import type { LevelDefinition, LevelResult, PlantState, Purchase } from '../../src/contracts';
import { EnergySimulator } from '../../src/sim/EnergySimulator';
import { Scoring } from '../../src/sim/Scoring';
import { StormImpact } from '../../src/sim/StormImpact';
import { WeatherSchedule } from '../../src/sim/WeatherSchedule';
import { LevelCatalog } from '../../src/levels/LevelCatalog';

export interface Strategy {
  repairConnector: boolean;
  cleanAfterZonda: boolean;
  /** 'defense': pone filas en horizontal durante aviso+tormenta. 'none': no hace nada. (El kit va en Purchase.) */
  zonda: 'defense' | 'none';
  shedNonEssentialAtNight: boolean;
  bonusKwh: number;
}

export const PERFECT: Strategy = { repairConnector: true, cleanAfterZonda: true, zonda: 'defense', shedNonEssentialAtNight: false, bonusKwh: 0 };

export interface PlayOutcome { result: LevelResult; blackoutHour: number | null; minSocPct: number; }

export function distribute(level: LevelDefinition, panels: number): number[] {
  const rows: number[] = [];
  let left = panels;
  for (let r = 0; r < level.rows; r++) { const n = Math.min(level.panelsPerRow, left); rows.push(n); left -= n; }
  return rows;
}

export function play(level: LevelDefinition, buy: Purchase, s: Strategy = PERFECT, dt = 0.05): PlayOutcome {
  const catalog = new LevelCatalog([level]);
  const sim = new EnergySimulator();
  const weather = new WeatherSchedule(level.events);
  const storm = new StormImpact();
  const spent = catalog.cost(level, buy);
  const rows = level.rows;
  let plant: PlantState = {
    panelsPerRow: distribute(level, buy.panels),
    rowOpen: Array.from({ length: rows }, (_, r) => level.events.looseConnector && r === 0 && !s.repairConnector),
    rowDirty: new Array(rows).fill(false),
    rowDefense: new Array(rows).fill(false),
    batteries: buy.batteries, protectionInstalled: true, cablesOk: true, shedLoads: [], bonusKwh: s.bonusKwh,
  };
  sim.start(level, plant);
  let panelsLost = 0, stormApplied = false, minSoc = 1;
  let snap = sim.snapshot();
  const nonEssential = level.loads.filter((l) => !l.essential).map((l) => l.label);
  while (!snap.finished) {
    const phase = weather.phaseAt(snap.hour);
    const defend = s.zonda === 'defense' && !buy.kitZonda && (phase === 'zonda-warning' || phase === 'zonda-storm');
    plant = { ...plant, rowDefense: plant.rowDefense.map(() => defend) };
    if (phase === 'zonda-storm' && !stormApplied) {
      const hit = storm.apply(plant, buy.kitZonda);
      plant = hit.plant; panelsLost += hit.panelsLost; stormApplied = true;
    }
    if (phase === 'zonda-over' && s.cleanAfterZonda) plant = { ...plant, rowDirty: plant.rowDirty.map(() => false) };
    plant = { ...plant, shedLoads: s.shedNonEssentialAtNight && snap.isNight ? nonEssential : [] };
    snap = sim.step(dt, plant, phase);
    if (snap.hour > 20) minSoc = Math.min(minSoc, snap.socPct);
  }
  const blackoutHour = snap.blackout ? snap.hour : null;
  const result = new Scoring().evaluate(level, {
    won: snap.won, finalSocPct: snap.socPct, spent, panelsLost, blackoutHour, durationSec: 90,
    hadOpenRowAtEnd: plant.rowOpen.some(Boolean), hadDirtyRowAtEnd: plant.rowDirty.some(Boolean),
    batteries: buy.batteries, panels: buy.panels, nonEssentialOn: !s.shedNonEssentialAtNight && nonEssential.length > 0,
  });
  return { result, blackoutHour, minSocPct: minSoc };
}

/** Todas las compras posibles dentro del presupuesto (con al menos minPanels y 1 batería). */
export function affordablePurchases(level: LevelDefinition, budget = level.budget): Purchase[] {
  const catalog = new LevelCatalog([level]);
  const out: Purchase[] = [];
  const kits = level.events.zondaAtHour !== null ? [false, true] : [false];
  for (let p = level.minPanels; p <= level.rows * level.panelsPerRow; p++)
    for (let b = 1; b <= level.batterySlots; b++)
      for (const k of kits) {
        const buy = { panels: p, batteries: b, kitZonda: k };
        if (catalog.cost(level, buy) <= budget) out.push(buy);
      }
  return out;
}

/** Mejor compra con juego perfecto (más estrellas, después más puntaje). */
export function bestPurchase(level: LevelDefinition): { buy: Purchase; outcome: PlayOutcome } | null {
  let best: { buy: Purchase; outcome: PlayOutcome } | null = null;
  for (const buy of affordablePurchases(level)) {
    const o = play(level, buy);
    if (!best || o.result.stars > best.outcome.result.stars ||
      (o.result.stars === best.outcome.result.stars && o.result.score > best.outcome.result.score)) best = { buy, outcome: o };
  }
  return best;
}
