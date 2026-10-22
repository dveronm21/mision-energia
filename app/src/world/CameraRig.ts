/**
 * CameraRig: cámara en tercera persona que sigue al jugador. Arrastrar sobre el lienzo la hace girar
 * (yaw) e inclinar (pitch); la rueda o el pellizco acercan. Sigue con suavizado y se sacude con el Zonda.
 */
import * as THREE from 'three';

export class CameraRig {
  yaw = 0.18;
  pitch = 0.6;
  dist = 11.5;
  shake = 0;
  private readonly target = new THREE.Vector3();
  private readonly desired = new THREE.Vector3();
  private readonly pointers = new Map<number, { x: number; y: number }>();
  private pinch = 0;
  private time = 0;
  private snapped = false;

  constructor(private readonly camera: THREE.PerspectiveCamera, private readonly el: HTMLElement) {
    el.addEventListener('pointerdown', this.down);
    el.addEventListener('pointermove', this.move);
    el.addEventListener('pointerup', this.up);
    el.addEventListener('pointercancel', this.up);
    el.addEventListener('wheel', this.wheel, { passive: false });
  }

  dispose(): void {
    const el = this.el;
    el.removeEventListener('pointerdown', this.down);
    el.removeEventListener('pointermove', this.move);
    el.removeEventListener('pointerup', this.up);
    el.removeEventListener('pointercancel', this.up);
    el.removeEventListener('wheel', this.wheel);
  }

  /** Coloca la cámara de golpe (al empezar). */
  snap(): void { this.snapped = false; }

  update(dt: number, follow: THREE.Vector3): void {
    this.time += dt;
    this.target.set(follow.x, follow.y + 1.2, follow.z);
    const cp = Math.cos(this.pitch);
    this.desired.set(Math.sin(this.yaw) * cp, Math.sin(this.pitch), Math.cos(this.yaw) * cp).multiplyScalar(this.dist).add(this.target);
    if (this.shake > 0) {
      this.desired.x += Math.sin(this.time * 27) * 0.09 * this.shake;
      this.desired.y += Math.sin(this.time * 31 + 1) * 0.05 * this.shake;
    }
    const cam = this.camera;
    if (!this.snapped) { cam.position.copy(this.desired); this.snapped = true; }
    else cam.position.lerp(this.desired, Math.min(1, dt * 7));
    cam.lookAt(this.target);
  }

  private down = (e: PointerEvent): void => {
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    try { this.el.setPointerCapture(e.pointerId); } catch { /* nada */ }
    if (this.pointers.size === 2) this.pinch = this.pinchDist();
  };

  private move = (e: PointerEvent): void => {
    const p = this.pointers.get(e.pointerId);
    if (!p) return;
    if (this.pointers.size >= 2) {
      p.x = e.clientX; p.y = e.clientY;
      const d = this.pinchDist();
      if (this.pinch > 0) this.dist = THREE.MathUtils.clamp(this.dist * (this.pinch / d), 6, 20);
      this.pinch = d;
      return;
    }
    this.yaw -= (e.clientX - p.x) * 0.006;
    this.pitch = THREE.MathUtils.clamp(this.pitch + (e.clientY - p.y) * 0.004, 0.22, 1.25);
    p.x = e.clientX; p.y = e.clientY;
  };

  private up = (e: PointerEvent): void => {
    this.pointers.delete(e.pointerId);
    if (this.pointers.size < 2) this.pinch = 0;
  };

  private wheel = (e: WheelEvent): void => {
    this.dist = THREE.MathUtils.clamp(this.dist + e.deltaY * 0.01, 6, 20);
    e.preventDefault();
  };

  private pinchDist(): number {
    const [a, b] = [...this.pointers.values()];
    return Math.max(1, Math.hypot(a.x - b.x, a.y - b.y));
  }
}
