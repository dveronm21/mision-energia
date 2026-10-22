import { KEEPALIVE_MS, type InputState, type TapCounters } from '../remote/protocol';

export type TapKey = keyof TapCounters;

/**
 * Estado de entrada de la tablet. Se manda completo al cambiar y como keepalive cada KEEPALIVE_MS.
 * Los contadores de toques son acumulativos durante toda la vida de la página (sobreviven a
 * reconexiones); `seq` vuelve a empezar en cada conexión nueva.
 */
export class InputModel {
  private x = 0;
  private y = 0;
  private held = 0;
  private seq = 0;
  private dirty = true;
  private lastSentAt = -Infinity;
  readonly taps: TapCounters = { action: 0, inspect: 0, tool: 0, pause: 0 };

  constructor(private readonly keepaliveMs = KEEPALIVE_MS) {}

  /** Joystick −1..1, cuantizado a centésimas para no mandar ruido del dedo. */
  setStick(x: number, y: number): void {
    const q = (v: number): number => Math.round(Math.max(-1, Math.min(1, v)) * 100) / 100;
    const nx = q(x), ny = q(y);
    if (nx === this.x && ny === this.y) return;
    this.x = nx; this.y = ny;
    this.dirty = true;
  }

  setHeld(mask: number): void {
    if (mask === this.held) return;
    this.held = mask;
    this.dirty = true;
  }

  tap(k: TapKey): void {
    this.taps[k] = (this.taps[k] + 1) % 0x7fffffff;
    this.dirty = true;
  }

  /** Nueva conexión: seq desde 0 y mandar enseguida. */
  newConnection(): void {
    this.seq = 0;
    this.dirty = true;
    this.lastSentAt = -Infinity;
  }

  shouldSend(now: number): boolean { return this.dirty || now - this.lastSentAt >= this.keepaliveMs; }

  take(now: number): InputState {
    this.dirty = false;
    this.lastSentAt = now;
    return { seq: ++this.seq, x: this.x, y: this.y, held: this.held, taps: { ...this.taps } };
  }

  stick(): { x: number; y: number } { return { x: this.x, y: this.y }; }
}
