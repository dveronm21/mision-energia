/**
 * Marcadores en el mundo: anillo amarillo bajo la acción más cercana y, con el booster "Pista",
 * anillo celeste + flecha flotante sobre el próximo paso de la obra.
 */
import * as THREE from 'three';

export class Highlights {
  readonly root = new THREE.Group();
  private readonly ring: THREE.Mesh;
  private readonly hintRing: THREE.Mesh;
  private readonly arrow: THREE.Mesh;
  private time = 0;
  private hintY = 3;

  constructor() {
    this.root.name = 'highlights';
    const ringGeo = new THREE.RingGeometry(0.62, 0.82, 40).rotateX(-Math.PI / 2);
    this.ring = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color: 0xffb82e, transparent: true, opacity: 0.95, depthWrite: false, toneMapped: false }));
    this.ring.renderOrder = 2;
    this.hintRing = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color: 0x5fe3f5, transparent: true, opacity: 0.85, depthWrite: false, toneMapped: false }));
    this.hintRing.renderOrder = 2;
    const arrowGeo = new THREE.ConeGeometry(0.32, 0.7, 4).rotateX(Math.PI);
    this.arrow = new THREE.Mesh(arrowGeo, new THREE.MeshBasicMaterial({ color: 0x5fe3f5, toneMapped: false }));
    this.ring.visible = this.hintRing.visible = this.arrow.visible = false;
    this.root.add(this.ring, this.hintRing, this.arrow);
  }

  /** Anillo de la acción actual (null = ocultar). y = altura del piso. */
  setAction(pos: THREE.Vector3 | null, y = 0): void {
    this.ring.visible = !!pos;
    if (pos) this.ring.position.set(pos.x, y + 0.04, pos.z);
  }

  /** Pista: anillo celeste + flecha sobre `pos` (null = ocultar). */
  setHint(pos: THREE.Vector3 | null, y = 0): void {
    const on = !!pos;
    this.hintRing.visible = this.arrow.visible = on;
    if (!pos) return;
    this.hintRing.position.set(pos.x, y + 0.03, pos.z);
    this.hintY = y + 3.0;
    this.arrow.position.set(pos.x, this.hintY, pos.z);
  }

  update(dt: number): void {
    this.time += dt;
    const s = 1 + Math.sin(this.time * 5.5) * 0.08;
    this.ring.scale.set(s, 1, s);
    const h = 1 + Math.sin(this.time * 3.2 + 1) * 0.12;
    this.hintRing.scale.set(h, 1, h);
    this.arrow.position.y = this.hintY + Math.sin(this.time * 3.2) * 0.25;
    this.arrow.rotation.y += dt * 2;
  }
}
