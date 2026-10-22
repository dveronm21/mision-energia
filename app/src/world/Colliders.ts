import type * as THREE from 'three';

/** Caja de colisión alineada a los ejes en el plano XZ (centro + medio ancho/fondo). */
export interface Aabb { x: number; z: number; hw: number; hd: number; }

/** Colisiones simples del jugador (círculo) contra cajas AABB y los límites del mapa. */
export class Colliders {
  private readonly boxes: Aabb[] = [];

  constructor(private readonly bounds: { minX: number; maxX: number; minZ: number; maxZ: number }) {}

  add(x: number, z: number, hw: number, hd: number): Aabb {
    const b = { x, z, hw, hd };
    this.boxes.push(b);
    return b;
  }

  remove(b: Aabb): void {
    const i = this.boxes.indexOf(b);
    if (i >= 0) this.boxes.splice(i, 1);
  }

  /** Empuja el punto p (radio r) fuera de las cajas y lo deja dentro de los límites. */
  resolve(p: THREE.Vector3, r: number): void {
    for (let pass = 0; pass < 2; pass++) {
      for (const c of this.boxes) {
        const cx = Math.max(c.x - c.hw, Math.min(p.x, c.x + c.hw));
        const cz = Math.max(c.z - c.hd, Math.min(p.z, c.z + c.hd));
        const dx = p.x - cx, dz = p.z - cz;
        const d = Math.hypot(dx, dz);
        if (d >= r) continue;
        if (d > 1e-4) { p.x = cx + (dx / d) * r; p.z = cz + (dz / d) * r; }
        else {
          // centro adentro de la caja: salir por el lado más cercano
          const ox = c.hw - Math.abs(p.x - c.x), oz = c.hd - Math.abs(p.z - c.z);
          if (ox < oz) p.x = c.x + Math.sign(p.x - c.x || 1) * (c.hw + r);
          else p.z = c.z + Math.sign(p.z - c.z || 1) * (c.hd + r);
        }
      }
    }
    const b = this.bounds;
    p.x = Math.max(b.minX, Math.min(b.maxX, p.x));
    p.z = Math.max(b.minZ, Math.min(b.maxZ, p.z));
  }
}
