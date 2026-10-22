/**
 * Geo: utilidades de geometría procedural para modelos low-poly.
 *
 * GeoBuilder junta piezas (cajas, cilindros, etc.) con un color por vértice y una transformación,
 * y las fusiona en UNA sola BufferGeometry no indexada (position/normal/uv/color[/skinIndex/skinWeight]).
 * Así cada modelo estático cuesta un solo draw call usando un material con `vertexColors`.
 */
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

/** PRNG determinista (mulberry32). */
export function rng(seed: number): () => number {
  let a = (seed >>> 0) || 0x9e3779b9;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Ruido de valor 2D suave (determinista) para terreno y montañas. */
export function noise2(x: number, y: number, seed = 0): number {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const h = (i: number, j: number) => {
    let n = (i * 374761393 + j * 668265263 + seed * 2246822519) | 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
  };
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = h(xi, yi), b = h(xi + 1, yi), c = h(xi, yi + 1), d = h(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

export function fbm2(x: number, y: number, oct = 4, seed = 0): number {
  let s = 0, amp = 0.5, f = 1, norm = 0;
  for (let i = 0; i < oct; i++) { s += amp * noise2(x * f, y * f, seed + i * 17); norm += amp; amp *= 0.5; f *= 2.03; }
  return s / norm;
}

export type V3 = [number, number, number];

export interface XForm { p?: V3; r?: V3; s?: V3 | number; }

const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _e = new THREE.Euler();
const _p = new THREE.Vector3();
const _s = new THREE.Vector3();

export function xform(t: XForm | THREE.Matrix4 | undefined): THREE.Matrix4 {
  if (!t) return _m.identity();
  if (t instanceof THREE.Matrix4) return t;
  _p.set(0, 0, 0); _s.set(1, 1, 1); _e.set(0, 0, 0);
  if (t.p) _p.set(t.p[0], t.p[1], t.p[2]);
  if (t.r) _e.set(t.r[0], t.r[1], t.r[2]);
  if (t.s !== undefined) { if (typeof t.s === 'number') _s.setScalar(t.s); else _s.set(t.s[0], t.s[1], t.s[2]); }
  _q.setFromEuler(_e);
  return _m.compose(_p, _q, _s);
}

export interface AddOpts {
  /** UV constante para toda la pieza (apunta a una zona "lisa" de la textura del material). */
  uv?: [number, number];
  /** Transformación afín de UV: u' = u*su + ou, v' = v*sv + ov. */
  uvRect?: [number, number, number, number];
  /** Etiqueta para recolorear después (cosméticos). */
  tag?: string;
  /** Variación de color por cara (0..1) para el look facetado. */
  jitter?: number;
  /** Índice de hueso para skinning rígido. */
  bone?: number;
  /** Conservar el atributo `color` de la geometría fuente (se ignora `color`). */
  keepColors?: boolean;
  /** Proyección planar de UV en espacio mundo (escala en metros por repetición): 'xz' | 'xy' | 'zy'. */
  project?: { axis: 'xz' | 'xy' | 'zy'; scale: number };
}

const _c = new THREE.Color();

export class GeoBuilder {
  private parts: THREE.BufferGeometry[] = [];
  private count = 0;
  private skinned = false;
  readonly tags = new Map<string, [number, number][]>();
  private rand: () => number;

  constructor(seed = 1) { this.rand = rng(seed); }

  get vertexCount(): number { return this.count; }

  add(src: THREE.BufferGeometry, color: number | THREE.Color, t?: XForm | THREE.Matrix4, o: AddOpts = {}): this {
    let g = src.index ? src.toNonIndexed() : src.clone();
    for (const name of Object.keys(g.attributes)) {
      if (name !== 'position' && name !== 'normal' && name !== 'uv' && !(o.keepColors && name === 'color')) g.deleteAttribute(name);
    }
    g.morphAttributes = {};
    g.clearGroups();
    g.applyMatrix4(xform(t));
    // Si la transformación espeja (escala negativa) hay que invertir el orden de los triángulos.
    const det = xform(t).determinant();
    const n = g.attributes.position.count;
    if (det < 0) flipWinding(g);
    if (!g.attributes.normal) g.computeVertexNormals();
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(n * 2), 2));
    const uv = g.attributes.uv as THREE.BufferAttribute;
    if (o.project) {
      const pos = g.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < n; i++) {
        const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
        const a = o.project.axis === 'xz' ? [x, z] : o.project.axis === 'xy' ? [x, y] : [z, y];
        uv.setXY(i, a[0] / o.project.scale, a[1] / o.project.scale);
      }
    }
    if (o.uvRect) {
      const [su, sv, ou, ov] = o.uvRect;
      for (let i = 0; i < n; i++) uv.setXY(i, uv.getX(i) * su + ou, uv.getY(i) * sv + ov);
    }
    if (o.uv) for (let i = 0; i < n; i++) uv.setXY(i, o.uv[0], o.uv[1]);
    const col = new Float32Array(n * 3);
    if (o.keepColors && g.attributes.color) col.set(g.attributes.color.array as Float32Array);
    _c.set(color as THREE.ColorRepresentation);
    const base = _c.clone();
    for (let i = 0; i < n && !(o.keepColors && g.attributes.color); i += 3) {
      let k = 1;
      if (o.jitter) k = 1 + (this.rand() - 0.5) * 2 * o.jitter;
      for (let j = 0; j < 3 && i + j < n; j++) {
        col[(i + j) * 3] = base.r * k; col[(i + j) * 3 + 1] = base.g * k; col[(i + j) * 3 + 2] = base.b * k;
      }
    }
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    if (o.bone !== undefined) {
      this.skinned = true;
      const si = new Uint16Array(n * 4), sw = new Float32Array(n * 4);
      for (let i = 0; i < n; i++) { si[i * 4] = o.bone; sw[i * 4] = 1; }
      g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4));
      g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
    }
    if (o.tag) {
      const list = this.tags.get(o.tag) || [];
      list.push([this.count, n]);
      this.tags.set(o.tag, list);
    }
    this.parts.push(g);
    this.count += n;
    return this;
  }

  box(w: number, h: number, d: number, color: number, t?: XForm, o?: AddOpts): this {
    return this.add(new THREE.BoxGeometry(w, h, d), color, t, o);
  }
  cyl(rt: number, rb: number, h: number, color: number, seg: number, t?: XForm, o?: AddOpts): this {
    return this.add(new THREE.CylinderGeometry(rt, rb, h, seg, 1), color, t, o);
  }

  build(): THREE.BufferGeometry {
    if (this.skinned) {
      // Todas las piezas necesitan skinIndex/skinWeight para poder fusionarse.
      for (const g of this.parts) {
        if (!g.attributes.skinIndex) {
          const n = g.attributes.position.count;
          const sw = new Float32Array(n * 4); for (let i = 0; i < n; i++) sw[i * 4] = 1;
          g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(new Uint16Array(n * 4), 4));
          g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
        }
      }
    }
    const merged = this.parts.length === 1 ? this.parts[0] : mergeGeometries(this.parts, false);
    if (!merged) throw new Error('GeoBuilder: no se pudo fusionar la geometría');
    for (const g of this.parts) if (g !== merged) g.dispose();
    this.parts = [];
    merged.computeBoundingSphere();
    merged.computeBoundingBox();
    return merged;
  }
}

function flipWinding(g: THREE.BufferGeometry): void {
  for (const name of Object.keys(g.attributes)) {
    const a = g.attributes[name] as THREE.BufferAttribute;
    const s = a.itemSize, arr = a.array as Float32Array;
    for (let i = 0; i + 2 < a.count; i += 3) {
      for (let k = 0; k < s; k++) {
        const t = arr[(i + 1) * s + k]; arr[(i + 1) * s + k] = arr[(i + 2) * s + k]; arr[(i + 2) * s + k] = t;
      }
    }
  }
}

/** Recolorea los vértices marcados con `tag` (cosméticos). */
export function recolor(geo: THREE.BufferGeometry, ranges: [number, number][] | undefined, color: number): void {
  if (!ranges) return;
  const c = geo.attributes.color as THREE.BufferAttribute;
  _c.set(color);
  for (const [start, n] of ranges) for (let i = start; i < start + n; i++) c.setXYZ(i, _c.r, _c.g, _c.b);
  c.needsUpdate = true;
}

/** Icosaedro con vértices desplazados (rocas, copas de árboles). */
export function lumpy(radius: number, detail: number, amount: number, seed: number): THREE.BufferGeometry {
  const g = new THREE.IcosahedronGeometry(radius, detail);
  const pos = g.attributes.position as THREE.BufferAttribute;
  // Desplazamiento coherente por posición para que los vértices compartidos sigan unidos.
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const k = 1 + (noise2(x * 3.1 + z * 1.7, y * 2.3 - z * 0.9, seed) - 0.5) * 2 * amount;
    pos.setXYZ(i, x * k, y * k, z * k);
  }
  g.computeVertexNormals();
  return g;
}

/** Tubo entre dos puntos (perfil cilíndrico) — útil para caños, palancas, ramas. */
export function segment(a: THREE.Vector3, b: THREE.Vector3, r0: number, r1: number, seg = 6): THREE.BufferGeometry {
  const len = a.distanceTo(b);
  const g = new THREE.CylinderGeometry(r1, r0, len, seg, 1);
  g.translate(0, len / 2, 0);
  const dir = new THREE.Vector3().subVectors(b, a).normalize();
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
  g.applyQuaternion(q);
  g.translate(a.x, a.y, a.z);
  return g;
}

/** Caja con bordes biselados (chaflán) para un look más prolijo que el cubo puro. */
export function bevelBox(w: number, h: number, d: number, b: number): THREE.BufferGeometry {
  const shape = new THREE.Shape();
  const x = w / 2 - b, y = h / 2 - b;
  shape.moveTo(-x, -h / 2); shape.lineTo(x, -h / 2); shape.lineTo(w / 2, -y); shape.lineTo(w / 2, y);
  shape.lineTo(x, h / 2); shape.lineTo(-x, h / 2); shape.lineTo(-w / 2, y); shape.lineTo(-w / 2, -y); shape.closePath();
  const g = new THREE.ExtrudeGeometry(shape, { depth: d - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: 0.0001, bevelSegments: 1, steps: 1, curveSegments: 1 });
  g.translate(0, 0, -(d - 2 * b) / 2);
  // UVs de Extrude están en unidades de mundo; normalizamos a 0..1 aprox.
  const uv = g.attributes.uv as THREE.BufferAttribute;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) / w + 0.5, uv.getY(i) / h + 0.5);
  return g;
}
