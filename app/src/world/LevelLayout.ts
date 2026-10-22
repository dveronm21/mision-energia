/**
 * LevelLayout: posiciones de todo el mundo de un nivel a partir de LevelDefinition + Purchase.
 * Área compacta (≈ 36 × 22 m) para que la partida sea ágil:
 *   oeste: campo solar (filas en +Z → -Z) con postes de fila y caja de conexión;
 *   centro-norte: sala de equipos (platea + pared + alero) con consola al frente;
 *   sur: pallet de paneles y punto de partida; este: depósito de cajones; noreste: ciudad.
 * La cámara arranca al sur (+Z) mirando hacia -Z.
 */
import * as THREE from 'three';
import type { LevelDefinition, LevelId, Purchase } from '../contracts';
import type { CarryKind } from './interaction/types';

const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);

export interface RowLayout {
  index: number;
  z: number;
  mounts: THREE.Vector3[];
  post: THREE.Vector3;
  /** Extremo de la fila por donde sale el cable hacia la caja de conexión. */
  wireStart: THREE.Vector3;
}

export interface Rect { x: number; z: number; w: number; d: number; }

export interface LevelLayout {
  rows: RowLayout[];
  fieldLabel: THREE.Vector3;
  junction: THREE.Vector3;
  room: {
    slab: Rect;
    floorY: number;
    wallZ: number;
    inverter: THREE.Vector3;
    protection: THREE.Vector3;
    switchboard: THREE.Vector3;
    batteries: THREE.Vector3[];
    console: THREE.Vector3;
    label: THREE.Vector3;
  };
  pump: THREE.Vector3 | null;
  pallet: THREE.Vector3;
  crates: { kind: CarryKind; pos: THREE.Vector3 }[];
  depotLabel: THREE.Vector3;
  city: { name: string; origin: THREE.Vector3; buildings: [number, number, number, number, number][]; poles: THREE.Vector3[]; label: THREE.Vector3 };
  spawn: THREE.Vector3;
  bounds: { minX: number; maxX: number; minZ: number; maxZ: number };
}

export const MOUNT_DX = 2.25;
export const ROW_DZ = 3.3;
const ROW0_Z = -3.4;
const FIELD_RIGHT_X = -4.6;

/** Lo que abastece la planta en cada nivel: edificios [x, z, ancho, alto, fondo] relativos al origen. */
const CITY: Record<LevelId, { name: string; near: boolean; b: [number, number, number, number, number][] }> = {
  casa: { name: 'CASA QUIROGA', near: true, b: [[0, 0, 6, 3.4, 5]] },
  escuela: { name: 'ESCUELA', near: true, b: [[0, 0, 10, 3.6, 5], [7.5, -6, 4.5, 3.4, 4]] },
  finca: { name: 'FINCA', near: true, b: [[0, 0, 6, 3.4, 5], [8, -1, 6, 4.6, 7]] },
  pueblo: { name: 'PUEBLO', near: false, b: [[0, 0, 4, 6, 4], [5, 1, 3.6, 4.5, 3.4], [9.5, -1, 4.2, 7, 4], [2, -6, 4.4, 5, 3.6], [7, -6.5, 3.6, 8, 3.6], [-4, -3, 3.4, 4.5, 3.4]] },
  parque: { name: 'BARRIO', near: false, b: [[0, 0, 4, 9, 4], [5, 1, 3.6, 6, 3.4], [9.5, -1, 4.2, 12, 4], [14, 0.5, 3.4, 6.5, 3.6], [2, -6, 4.4, 7.5, 3.6],
    [7, -6.5, 3.6, 15, 3.6], [12, -6, 4, 7, 4], [-4, -3, 3.4, 5.5, 3.4], [17, -4, 3.4, 9, 3.4], [-3, -9, 3.6, 6, 3.6]] },
};

export function buildLayout(level: LevelDefinition, purchase: Purchase): LevelLayout {
  const ppr = level.panelsPerRow;
  const leftX = FIELD_RIGHT_X - (ppr - 1) * MOUNT_DX;
  const rows: RowLayout[] = [];
  for (let r = 0; r < level.rows; r++) {
    const z = ROW0_Z - r * ROW_DZ;
    const mounts: THREE.Vector3[] = [];
    for (let i = 0; i < ppr; i++) mounts.push(V(leftX + i * MOUNT_DX, 0, z));
    rows.push({ index: r, z, mounts, post: V(leftX - 2.8, 0, z), wireStart: V(FIELD_RIGHT_X + 1.05, 0.85, z + 0.2) });
  }
  const lastZ = rows[rows.length - 1].z;

  const floorY = 0.16;
  const slots = level.batterySlots;
  const batteries: THREE.Vector3[] = [];
  for (let i = 0; i < slots; i++) batteries.push(V(6.5 + i * 1.15, floorY, -6.3));

  const crates: { kind: CarryKind; pos: THREE.Vector3 }[] = [];
  const kinds: CarryKind[] = ['protection'];
  for (let i = 0; i < purchase.batteries; i++) kinds.push('battery');
  if (purchase.kitZonda) kinds.push('kit');
  kinds.forEach((k, i) => crates.push({ kind: k, pos: V(13.2 + i * 1.3, 0, 1.4) }));

  return {
    rows,
    fieldLabel: V((leftX + FIELD_RIGHT_X) / 2, 2.6, ROW0_Z - 1.6),
    junction: V(-2.3, 0, -4.4),
    room: {
      slab: { x: 7, z: -4.2, w: 11, d: 6 },
      floorY,
      wallZ: -6.9,
      inverter: V(5.2, floorY, -6.9),
      protection: V(3.3, floorY, -6.9),
      switchboard: V(11.2, floorY, -6.9),
      batteries,
      console: V(7, floorY, -2.2),
      label: V(7, 3.75, -6.4),
    },
    pump: level.hasPump ? V(15.2, 0, -5.2) : null,
    pallet: V(-4, 0, 3.2),
    crates,
    depotLabel: V(13.2 + (kinds.length - 1) * 0.65, 1.55, 1.4),
    city: cityLayout(level.id),
    spawn: V(0, 0, 2.6),
    bounds: { minX: leftX - 4.6, maxX: 21, minZ: Math.min(-8.6, lastZ - 2.6), maxZ: 7.5 },
  };
}

function cityLayout(id: LevelId): LevelLayout['city'] {
  const c = CITY[id];
  const origin = c.near ? V(19.5, 0, -17) : V(22, 0, -22);
  const top = Math.max(...c.b.map((b) => b[3]));
  return {
    name: c.name, origin, buildings: c.b,
    poles: c.near ? [V(13, 0, -8.5), V(16, 0, -12.8)] : [V(13, 0, -8.5), V(15.5, 0, -13.5), V(18.2, 0, -18.5)],
    label: origin.clone().add(V(c.near ? 0 : 3, top + 1.6, 0)),
  };
}

/** ¿El punto (x,z) está sobre la platea de la sala? (para la altura del piso). */
export function onSlab(l: LevelLayout, x: number, z: number, pad = 0): boolean {
  const s = l.room.slab;
  return Math.abs(x - s.x) <= s.w / 2 + pad && Math.abs(z - s.z) <= s.d / 2 + pad;
}
