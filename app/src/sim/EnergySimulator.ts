import type { IEnergySimulator, LevelDefinition, PlantState, SimSnapshot, WeatherPhase } from '../contracts';
import { cloudFactor, loadKw, sunFactor } from './solar';

export interface SimulatorOptions {
  /** Eficiencia de carga de baterías (0..1). */
  chargeEfficiency: number;
  /** Pérdida de una fila con polvo (0..1). */
  dustLoss: number;
  /** Rendimiento de una fila en posición de defensa (horizontal). */
  defenseFactor: number;
  /** Irradiancia remanente durante la tormenta de Zonda. */
  stormFactor: number;
  /** Paso interno máximo (h) para que el resultado no dependa del frame rate. */
  maxSubstepHours: number;
}

export const DEFAULT_SIM_OPTIONS: SimulatorOptions = {
  chargeEfficiency: 0.95, dustLoss: 0.35, defenseFactor: 0.55, stormFactor: 0.25, maxSubstepHours: 0.05,
};

/**
 * Simulador energético puro y determinista (acople en CC simplificado):
 * generación → consumo directo; excedente carga baterías (η=0.95); déficit lo cubren las baterías.
 * Batería vacía con déficit = apagón (pierde). Llegar a endHour = gana.
 * La capacidad del banco se fija en start() (batteries × batteryKwh + bonusKwh).
 */
export class EnergySimulator implements IEnergySimulator {
  private level: LevelDefinition | null = null;
  private snap: SimSnapshot = EnergySimulator.emptySnapshot();

  constructor(private readonly opts: SimulatorOptions = DEFAULT_SIM_OPTIONS) {}

  private static emptySnapshot(): SimSnapshot {
    return { hour: 0, irradiance: 0, genKw: 0, loadKw: 0, netKw: 0, socKwh: 0, capKwh: 0, socPct: 0, isNight: true, blackout: false, finished: false, won: false };
  }

  start(level: LevelDefinition, plant: PlantState): void {
    this.level = level;
    const bonus = Math.max(0, plant.bonusKwh ?? 0);
    const cap = Math.max(0, plant.batteries) * level.batteryKwh + bonus;
    const soc = Math.min(cap, Math.max(0, plant.batteries) * level.batteryKwh * level.startSoc + bonus);
    this.snap = this.compute(level.startHour, plant, 'calm', soc, cap);
  }

  step(dtHours: number, plant: PlantState, weather: WeatherPhase): SimSnapshot {
    const level = this.level;
    if (!level) throw new Error('EnergySimulator: llamá a start() antes de step()');
    if (this.snap.finished || !(dtHours > 0)) return this.snapshot();
    let remaining = Math.min(dtHours, level.endHour - this.snap.hour);
    let { hour, socKwh } = this.snap;
    const cap = this.snap.capKwh;
    let s = this.snap;
    while (remaining > 1e-9) {
      const h = Math.min(this.opts.maxSubstepHours, remaining);
      remaining -= h;
      hour += h;
      s = this.compute(hour, plant, weather, socKwh, cap);
      const delta = s.netKw * h * (s.netKw > 0 ? this.opts.chargeEfficiency : 1);
      socKwh = Math.min(cap, socKwh + delta);
      if (socKwh <= 1e-9 && s.netKw < 0) {
        this.snap = { ...s, socKwh: 0, socPct: 0, blackout: true, finished: true, won: false };
        return this.snapshot();
      }
      s = { ...s, socKwh, socPct: cap > 0 ? socKwh / cap : 0 };
    }
    if (hour >= level.endHour - 1e-9) s = { ...s, hour: level.endHour, finished: true, won: true };
    this.snap = s;
    return this.snapshot();
  }

  snapshot(): SimSnapshot { return { ...this.snap }; }

  /** Generación efectiva de la planta en "paneles equivalentes" (pura, pública para tests y HUD). */
  effectivePanels(plant: PlantState): number {
    if (!plant.cablesOk || !plant.protectionInstalled) return 0;
    let n = 0;
    plant.panelsPerRow.forEach((count, r) => {
      if (plant.rowOpen[r]) return;
      let k = count;
      if (plant.rowDirty[r]) k *= 1 - this.opts.dustLoss;
      if (plant.rowDefense[r]) k *= this.opts.defenseFactor;
      n += k;
    });
    return n;
  }

  private compute(hour: number, plant: PlantState, weather: WeatherPhase, socKwh: number, capKwh: number): SimSnapshot {
    const level = this.level!;
    const sun = sunFactor(hour);
    const irradiance = sun * cloudFactor(level.events.clouds, hour) * (weather === 'zonda-storm' ? this.opts.stormFactor : 1);
    const genKw = Math.min(level.inverterKw, this.effectivePanels(plant) * level.panelKw * irradiance);
    const load = loadKw(level.loads, hour, plant.shedLoads);
    return {
      hour, irradiance, genKw, loadKw: load, netKw: genKw - load, socKwh, capKwh,
      socPct: capKwh > 0 ? socKwh / capKwh : 0, isNight: sun <= 0, blackout: false, finished: false, won: false,
    };
  }
}
