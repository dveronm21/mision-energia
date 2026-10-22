import type { LevelEvents, WeatherPhase } from '../contracts';
import { cloudFactor } from './solar';

export interface WeatherTiming { warningHours: number; stormHours: number; }
export const DEFAULT_WEATHER_TIMING: WeatherTiming = { warningHours: 0.7, stormHours: 0.3 };

/**
 * Calendario climático del nivel. El juego lo consulta cada frame con la hora de juego:
 * calm → zonda-warning (aviso, ~0.7 h) → zonda-storm (~0.3 h, polvo y riesgo de perder paneles) → zonda-over.
 * Sugerencia: el juego puede ralentizar el reloj durante el aviso para dar tiempo a reaccionar.
 */
export class WeatherSchedule {
  constructor(private readonly events: LevelEvents, private readonly timing: WeatherTiming = DEFAULT_WEATHER_TIMING) {}

  phaseAt(hour: number): WeatherPhase {
    const z = this.events.zondaAtHour;
    if (z === null) return 'calm';
    if (hour < z) return 'calm';
    if (hour < z + this.timing.warningHours) return 'zonda-warning';
    if (hour < z + this.timing.warningHours + this.timing.stormHours) return 'zonda-storm';
    return 'zonda-over';
  }

  /** Ventana del Zonda en horas de juego, o null si el nivel no tiene. */
  zondaWindow(): { warnFrom: number; stormFrom: number; stormTo: number } | null {
    const z = this.events.zondaAtHour;
    if (z === null) return null;
    const stormFrom = z + this.timing.warningHours;
    return { warnFrom: z, stormFrom, stormTo: stormFrom + this.timing.stormHours };
  }

  /** Nubosidad visual 0..1 (0 = despejado) para el ambiente 3D. */
  cloudinessAt(hour: number): number {
    return 1 - cloudFactor(this.events.clouds, hour);
  }

  /** Horas restantes de aviso (para el cartel "Llega en…"); 0 fuera del aviso. */
  warningRemaining(hour: number): number {
    const w = this.zondaWindow();
    return w && hour >= w.warnFrom && hour < w.stormFrom ? w.stormFrom - hour : 0;
  }
}
