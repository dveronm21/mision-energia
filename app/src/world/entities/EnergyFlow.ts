/**
 * EnergyFlow: partículas de energía que viajan por las curvas de los cables.
 * Todas las corrientes comparten UNA InstancedMesh (1 draw call), con color por instancia.
 */
import * as THREE from 'three';

export interface FlowHandle {
  /** Encendida (visible y moviéndose). */
  on: boolean;
  /** 1 = del inicio al final de la curva, −1 = al revés. */
  dir: 1 | -1;
  /** Velocidad en vueltas por segundo (relativa al largo). */
  speed: number;
}

interface Flow extends FlowHandle { curve: THREE.Curve<THREE.Vector3>; first: number; count: number; phase: number; }

export class EnergyFlow {
  readonly mesh: THREE.InstancedMesh;
  private readonly flows: Flow[] = [];
  private used = 0;
  private readonly m = new THREE.Matrix4();
  private readonly p = new THREE.Vector3();
  private readonly zero = new THREE.Matrix4().makeScale(0, 0, 0);
  private time = 0;

  constructor(private readonly capacity = 160) {
    const geo = new THREE.SphereGeometry(0.1, 8, 6);
    const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, toneMapped: false, fog: false });
    this.mesh = new THREE.InstancedMesh(geo, mat, capacity);
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    this.mesh.name = 'energy-flow';
    for (let i = 0; i < capacity; i++) this.mesh.setColorAt(i, new THREE.Color(0xffffff));
  }

  /** Registra una corriente sobre una curva. count se ajusta al largo si no se pasa. */
  add(curve: THREE.Curve<THREE.Vector3>, color: number, count?: number): FlowHandle {
    const n = Math.min(count ?? Math.max(3, Math.round(curve.getLength() / 1.4)), this.capacity - this.used);
    const f: Flow = { curve, first: this.used, count: n, phase: 0, on: false, dir: 1, speed: 2.2 / Math.max(1, curve.getLength()) };
    const c = new THREE.Color(color);
    for (let i = 0; i < n; i++) this.mesh.setColorAt(f.first + i, c);
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
    this.used += n;
    this.mesh.count = this.used;
    this.flows.push(f);
    return f;
  }

  update(dt: number): void {
    this.time += dt;
    const pulse = 0.85 + 0.25 * Math.sin(this.time * 9);
    for (const f of this.flows) {
      if (f.on) f.phase = (f.phase + dt * f.speed * f.dir + 1) % 1;
      for (let i = 0; i < f.count; i++) {
        const idx = f.first + i;
        if (!f.on) { this.mesh.setMatrixAt(idx, this.zero); continue; }
        const t = (f.phase + i / f.count) % 1;
        f.curve.getPointAt(t, this.p);
        this.m.makeScale(pulse, pulse, pulse).setPosition(this.p);
        this.mesh.setMatrixAt(idx, this.m);
      }
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}
