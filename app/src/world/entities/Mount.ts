/**
 * Mount: estructura de montaje de un panel. Puede tener panel (con o sin conector flojo),
 * polvo del Zonda y posición de defensa (horizontal).
 */
import * as THREE from 'three';
import type { PanelModel } from '../../contracts';
import type { ModelFactory } from '../assets';

export const TILT_NORMAL = 0.45;
export const TILT_DEFENSE = 0.02;

export class Mount {
  readonly root: THREE.Group;
  private readonly tilt: THREE.Group;
  private readonly ghost: THREE.Object3D;
  private panel: PanelModel | null = null;
  faulty = false;
  /** Se midió este panel con el multímetro y se encontró el conector abierto. */
  faultFound = false;
  private dirty = false;
  private tiltTarget = TILT_NORMAL;
  /** Punto de acceso frente a la estructura. */
  readonly approach: THREE.Vector3;

  constructor(private readonly factory: ModelFactory, readonly row: number, readonly index: number, pos: THREE.Vector3) {
    const m = factory.createMount();
    this.root = m.root; this.tilt = m.tilt; this.ghost = m.ghost;
    this.root.position.copy(pos);
    this.ghost.visible = true;
    this.approach = new THREE.Vector3(pos.x, 0, pos.z + 1.3);
  }

  get filled(): boolean { return this.panel !== null; }
  get position(): THREE.Vector3 { return this.root.position; }
  get isDirty(): boolean { return this.dirty && this.filled; }

  install(faulty: boolean): void {
    if (this.panel) return;
    this.panel = this.factory.createPanel();
    this.tilt.add(this.panel.root);
    this.panel.setDirty(this.dirty);
    this.ghost.visible = false;
    this.faulty = faulty;
    this.faultFound = false;
  }

  /** Saca el panel (lo arrancó el viento). Devuelve si tenía el conector flojo. */
  remove(): boolean {
    if (!this.panel) return false;
    this.tilt.remove(this.panel.root);
    this.panel.root.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) (m.material as THREE.Material).dispose(); });
    this.panel = null;
    this.ghost.visible = true;
    const f = this.faulty;
    this.faulty = false; this.faultFound = false;
    return f;
  }

  repair(): void { this.faulty = false; this.faultFound = false; }

  setDirty(on: boolean): void {
    this.dirty = on;
    this.panel?.setDirty(on);
  }

  setDefense(on: boolean): void { this.tiltTarget = on ? TILT_DEFENSE : TILT_NORMAL; }

  setGlow(v: number): void { this.panel?.setGlow(v); }

  setGhostVisible(on: boolean): void { this.ghost.visible = on && !this.panel; }

  update(dt: number): void {
    const t = this.tilt;
    t.rotation.x += (this.tiltTarget - t.rotation.x) * Math.min(1, dt * 4);
  }
}
