import { BTN, type InputState, type IInputSource, type PlayerIntent, type PlayerSlot, type TapCounters } from './protocol';

export interface StickTuning {
  /** Zona muerta radial (0..0.9). Debajo de este radio el personaje no se mueve. */
  deadZone: number;
  /** Exponente de la curva de respuesta (1 = lineal; >1 = más precisión cerca del centro). */
  curve: number;
  /** Pulsaciones pendientes máximas por botón (evita ráfagas si llega un contador gigante). */
  maxPendingTaps: number;
}

export const DEFAULT_STICK: StickTuning = { deadZone: 0.15, curve: 1.5, maxPendingTaps: 4 };

const TAP_KEYS = ['action', 'inspect', 'tool', 'pause'] as const;
type TapKey = typeof TAP_KEYS[number];

/**
 * Entrada de un jugador que controla desde una tablet. Una instancia por asiento, estable durante
 * toda la vida de `RemoteHost` (el juego puede guardar la referencia).
 *
 * - Joystick: zona muerta radial + curva de potencia, conservando la dirección.
 * - Toques: los contadores acumulativos del protocolo se convierten en flancos. Si se perdieron
 *   mensajes intermedios y el contador saltó de 3 a 5, se entregan 2 pulsaciones en 2 frames
 *   seguidos (nunca se pierde una ni se duplica).
 * - Desconectado: devuelve intención neutra con `connected: false`.
 */
export class RemoteInputSource implements IInputSource {
  private x = 0;
  private y = 0;
  private held = 0;
  private lastSeq = -1;
  private isConnected = false;
  private readonly seen: TapCounters = { action: 0, inspect: 0, tool: 0, pause: 0 };
  private readonly pending: TapCounters = { action: 0, inspect: 0, tool: 0, pause: 0 };
  private readonly tuning: StickTuning;

  constructor(readonly slot: PlayerSlot, tuning: Partial<StickTuning> = {}) {
    this.tuning = { ...DEFAULT_STICK, ...tuning };
  }

  get connected(): boolean { return this.isConnected; }

  /** Vector crudo recibido (sin zona muerta ni curva), útil para depurar. */
  raw(): { x: number; y: number } { return { x: this.x, y: this.y }; }

  read(): PlayerIntent {
    if (!this.isConnected) {
      return { x: 0, y: 0, run: false, action: false, inspect: false, tool: false, pause: false, connected: false };
    }
    const [x, y] = shapeStick(this.x, this.y, this.tuning.deadZone, this.tuning.curve);
    return {
      x, y,
      run: (this.held & BTN.RUN) !== 0,
      action: this.take('action'),
      inspect: this.take('inspect'),
      tool: this.take('tool'),
      pause: this.take('pause'),
      connected: true,
    };
  }

  /* ---------- Uso interno de RemoteHost ---------- */

  /**
   * Nueva conexión en este asiento. `newPlayer` = asiento recién ocupado (contadores desde 0);
   * si es una reconexión del mismo jugador se conservan los contadores vistos.
   */
  beginConnection(newPlayer: boolean): void {
    this.lastSeq = -1;
    this.isConnected = true;
    this.x = 0; this.y = 0; this.held = 0;
    if (newPlayer) {
      for (const k of TAP_KEYS) { this.seen[k] = 0; this.pending[k] = 0; }
    }
  }

  /** Aplica un estado completo. Ignora estados viejos (seq no creciente dentro de la conexión). */
  applyState(s: InputState): boolean {
    if (!this.isConnected || s.seq <= this.lastSeq) return false;
    this.lastSeq = s.seq;
    this.x = s.x; this.y = s.y; this.held = s.held;
    for (const k of TAP_KEYS) {
      const cur = s.taps[k];
      // Si el contador bajó, la página se reinició: cuenta desde 0.
      const diff = cur >= this.seen[k] ? cur - this.seen[k] : cur;
      this.seen[k] = cur;
      if (diff > 0) this.pending[k] = Math.min(this.tuning.maxPendingTaps, this.pending[k] + diff);
    }
    return true;
  }

  /** Conexión perdida: queda quieto y sin pulsaciones pendientes. */
  disconnect(): void {
    this.isConnected = false;
    this.x = 0; this.y = 0; this.held = 0;
    for (const k of TAP_KEYS) this.pending[k] = 0;
  }

  private take(k: TapKey): boolean {
    if (this.pending[k] <= 0) return false;
    this.pending[k]--;
    return true;
  }
}

/** Zona muerta radial reescalada + curva de potencia. Mantiene la dirección y satura en 1. */
export function shapeStick(x: number, y: number, deadZone: number, curve: number): [number, number] {
  const mag = Math.hypot(x, y);
  if (!(mag > deadZone)) return [0, 0];
  const m = Math.min(1, mag);
  const t = Math.pow((m - deadZone) / (1 - deadZone), curve);
  const k = t / mag;
  const r = (v: number): number => Math.round(v * 1000) / 1000;
  return [r(x * k), r(y * k)];
}
