import { el } from '../dom';

export interface JoystickVector { x: number; y: number; }

/**
 * Joystick virtual. Sigue sólo el puntero que lo tocó (pointer capture), así otro dedo puede
 * arrastrar la cámara al mismo tiempo. x: −1 izquierda … 1 derecha; y: −1 arriba (avanzar) … 1 abajo.
 */
export class Joystick {
  readonly root: HTMLDivElement;
  private readonly knob: HTMLDivElement;
  private pointerId: number | null = null;
  private v: JoystickVector = { x: 0, y: 0 };

  constructor(host: HTMLElement, private readonly onChange?: (v: JoystickVector) => void) {
    this.knob = el('div', 'joy-knob');
    this.root = el('div', { cls: 'hud-joy', attrs: { role: 'img', 'aria-label': 'Joystick para caminar' } }, [this.knob]);
    this.root.addEventListener('pointerdown', this.down);
    this.root.addEventListener('pointermove', this.move);
    this.root.addEventListener('pointerup', this.up);
    this.root.addEventListener('pointercancel', this.up);
    this.root.addEventListener('lostpointercapture', this.up);
    host.appendChild(this.root);
  }

  vector(): JoystickVector { return { x: this.v.x, y: this.v.y }; }
  get active(): boolean { return this.pointerId !== null; }

  reset(): void {
    this.pointerId = null;
    this.set(0, 0);
    this.knob.style.transform = '';
    this.root.classList.remove('is-active');
  }

  dispose(): void { this.reset(); this.root.remove(); }

  private down = (e: PointerEvent): void => {
    if (this.pointerId !== null) return;
    this.pointerId = e.pointerId;
    try { this.root.setPointerCapture(e.pointerId); } catch { /* jsdom/viejo */ }
    this.root.classList.add('is-active');
    e.preventDefault();
    e.stopPropagation();
    this.track(e);
  };

  private move = (e: PointerEvent): void => {
    if (e.pointerId !== this.pointerId) return;
    e.stopPropagation();
    this.track(e);
  };

  private up = (e: PointerEvent): void => {
    if (e.pointerId !== this.pointerId) return;
    this.reset();
  };

  private track(e: PointerEvent): void {
    const r = this.root.getBoundingClientRect();
    let dx = e.clientX - (r.left + r.width / 2);
    let dy = e.clientY - (r.top + r.height / 2);
    const max = r.width / 2 - this.knob.offsetWidth / 4;
    const d = Math.hypot(dx, dy);
    if (d > max && d > 0) { dx *= max / d; dy *= max / d; }
    this.knob.style.transform = `translate(${dx.toFixed(1)}px, ${dy.toFixed(1)}px)`;
    // Zona muerta pequeña para que no camine solo con un toque.
    const nx = dx / max, ny = dy / max;
    const mag = Math.hypot(nx, ny);
    if (mag < 0.12) this.set(0, 0); else this.set(nx, ny);
  }

  private set(x: number, y: number): void {
    const cx = Math.max(-1, Math.min(1, x)), cy = Math.max(-1, Math.min(1, y));
    if (cx === this.v.x && cy === this.v.y) return;
    this.v = { x: cx, y: cy };
    this.onChange?.(this.vector());
  }
}
