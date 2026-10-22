import { el } from '../ui/dom';

export interface StickOutput { x: number; y: number; run: boolean; active: boolean; }

/**
 * Joystick analógico flotante: aparece donde apoyás el dedo dentro de su zona.
 * Sigue solo a su puntero (multitouch: los botones de la derecha funcionan a la vez).
 * Llevar el dedo más allá del aro (×1.3 del radio) activa "correr".
 */
export class FloatingStick {
  readonly base: HTMLDivElement;
  private readonly knob: HTMLDivElement;
  private pointerId: number | null = null;
  private cx = 0;
  private cy = 0;
  private radius = 100;
  private out: StickOutput = { x: 0, y: 0, run: false, active: false };

  constructor(private readonly zone: HTMLElement, private readonly onChange: (o: StickOutput) => void) {
    this.knob = el('div', 'c-knob');
    this.base = el('div', { cls: 'c-base', attrs: { 'aria-hidden': 'true' } }, [el('div', 'c-ring'), this.knob]);
    zone.appendChild(this.base);
    zone.addEventListener('pointerdown', this.down);
    zone.addEventListener('pointermove', this.move);
    zone.addEventListener('pointerup', this.up);
    zone.addEventListener('pointercancel', this.up);
    zone.addEventListener('lostpointercapture', this.up);
  }

  get active(): boolean { return this.pointerId !== null; }

  reset(): void {
    this.pointerId = null;
    this.zone.classList.remove('is-active', 'is-run');
    this.knob.style.transform = '';
    this.emit({ x: 0, y: 0, run: false, active: false });
  }

  private down = (e: PointerEvent): void => {
    if (this.pointerId !== null) return;
    e.preventDefault();
    this.pointerId = e.pointerId;
    try { this.zone.setPointerCapture(e.pointerId); } catch { /* */ }
    const z = this.zone.getBoundingClientRect();
    this.radius = Math.max(60, Math.min(130, Math.min(window.innerWidth, window.innerHeight) * 0.15));
    const pad = this.radius * 1.15;
    // La base aparece bajo el dedo, pero entera dentro de la zona.
    this.cx = Math.max(z.left + pad, Math.min(z.right - pad, e.clientX));
    this.cy = Math.max(z.top + pad, Math.min(z.bottom - pad, e.clientY));
    this.base.style.setProperty('--r', `${this.radius}px`);
    this.base.style.left = `${this.cx - z.left}px`;
    this.base.style.top = `${this.cy - z.top}px`;
    this.zone.classList.add('is-active');
    this.track(e);
  };

  private move = (e: PointerEvent): void => {
    if (e.pointerId !== this.pointerId) return;
    e.preventDefault();
    this.track(e);
  };

  private up = (e: PointerEvent): void => {
    if (e.pointerId !== this.pointerId) return;
    this.reset();
  };

  private track(e: PointerEvent): void {
    let dx = e.clientX - this.cx, dy = e.clientY - this.cy;
    const d = Math.hypot(dx, dy);
    const run = d > this.radius * 1.3;
    if (d > this.radius) { dx *= this.radius / d; dy *= this.radius / d; }
    this.knob.style.transform = `translate(${dx.toFixed(1)}px, ${dy.toFixed(1)}px)`;
    this.zone.classList.toggle('is-run', run);
    this.emit({ x: dx / this.radius, y: dy / this.radius, run, active: true });
  }

  private emit(o: StickOutput): void {
    const changed = o.x !== this.out.x || o.y !== this.out.y || o.run !== this.out.run || o.active !== this.out.active;
    this.out = o;
    if (changed) this.onChange(o);
  }
}
