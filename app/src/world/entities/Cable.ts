/**
 * CableNetwork: todos los cables del mundo. Los de potencia se tienden por el piso con recorrido
 * "en L" (por pasillos) y apoyados en la platea; la línea a la ciudad va aérea por los postes.
 * También dibuja el cable "en la mano" mientras el jugador lo lleva.
 */
import * as THREE from 'three';
import type { ModelFactory } from '../assets';
import type { CableColor } from '../interaction/types';

export const CABLE_HEX: Record<CableColor, number> = { orange: 0xf28c28, blue: 0x2f7be0, violet: 0x8b5cf6 };
export const CABLE_NAME: Record<CableColor, string> = {
  orange: 'cable de los paneles', blue: 'cable de las baterías', violet: 'cable del tablero',
};

export interface CableRun {
  mesh: THREE.Mesh;
  curve: THREE.Curve<THREE.Vector3>;
  setGlow(v: number): void;
}

const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);

export class CableNetwork {
  readonly root = new THREE.Group();
  readonly connected: Partial<Record<CableColor, CableRun>> = {};
  private live: THREE.Mesh | null = null;
  private liveMat: THREE.MeshStandardMaterial | null = null;
  private liveKey = '';

  constructor(private readonly f: ModelFactory, private readonly floorAt: (x: number, z: number) => number) {
    this.root.name = 'cables';
  }

  /** Cable con puntos explícitos. */
  run(points: THREE.Vector3[], color: number, radius = 0.035): CableRun {
    const c = this.f.createCable(points, color, radius);
    this.root.add(c.mesh);
    return c;
  }

  /**
   * Recorrido por el piso: baja de `a`, va hasta el pasillo, recorre el pasillo y sube a `b`.
   * corridor: { z } recorre en X a esa Z; { x } recorre en Z a esa X.
   */
  groundRoute(a: THREE.Vector3, b: THREE.Vector3, corridor: { z: number } | { x: number }): THREE.Vector3[] {
    const plan: [number, number][] = [];
    if ('z' in corridor) {
      plan.push([a.x, corridor.z], [b.x, corridor.z], [b.x, b.z + 0.42]);
    } else {
      plan.push([corridor.x, a.z + 0.25], [corridor.x, b.z + 0.45], [b.x, b.z + 0.45]);
    }
    const pts: THREE.Vector3[] = [a.clone()];
    let prev: [number, number] = [a.x, a.z + 0.3];
    pts.push(V(prev[0], this.floorAt(prev[0], prev[1]) + 0.05, prev[1]));
    for (const p of plan) {
      const len = Math.hypot(p[0] - prev[0], p[1] - prev[1]);
      const n = Math.max(1, Math.ceil(len / 0.6));
      for (let i = 1; i <= n; i++) {
        const x = prev[0] + (p[0] - prev[0]) * (i / n), z = prev[1] + (p[1] - prev[1]) * (i / n);
        pts.push(V(x, this.floorAt(x, z) + 0.05, z));
      }
      prev = p;
    }
    pts.push(b.clone());
    return pts;
  }

  connect(color: CableColor, points: THREE.Vector3[]): CableRun {
    const r = this.run(points, CABLE_HEX[color]);
    this.connected[color] = r;
    return r;
  }

  isConnected(color: CableColor): boolean { return !!this.connected[color]; }

  /** Dibuja el cable que el jugador lleva en la mano (se reconstruye como mucho ~12 veces por segundo). */
  updateLive(from: THREE.Vector3 | null, hand: THREE.Vector3, color: CableColor | null): void {
    if (!from || !color) {
      if (this.live) { this.root.remove(this.live); this.live.geometry.dispose(); this.live = null; this.liveKey = ''; }
      return;
    }
    const key = `${color}|${hand.x.toFixed(1)}|${hand.y.toFixed(1)}|${hand.z.toFixed(1)}`;
    if (key === this.liveKey) return;
    this.liveKey = key;
    const mid = from.clone().lerp(hand, 0.5);
    mid.y = Math.max(0.05, Math.min(from.y, hand.y) - 0.7);
    const curve = new THREE.QuadraticBezierCurve3(from, mid, hand.clone());
    const geo = new THREE.TubeGeometry(curve, 24, 0.04, 6, false);
    if (!this.liveMat) this.liveMat = new THREE.MeshStandardMaterial({ roughness: 0.5 });
    this.liveMat.color.setHex(CABLE_HEX[color]);
    this.liveMat.emissive.setHex(CABLE_HEX[color]);
    this.liveMat.emissiveIntensity = 0.3;
    if (this.live) { this.live.geometry.dispose(); this.live.geometry = geo; }
    else { this.live = new THREE.Mesh(geo, this.liveMat); this.live.castShadow = true; this.root.add(this.live); }
  }
}
