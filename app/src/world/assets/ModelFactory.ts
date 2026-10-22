/**
 * ModelFactory: todos los modelos procedurales del juego (IModelFactory).
 *
 * Reglas:
 * - Origen en el piso (y=0), mirando a +Z. Escala en metros.
 * - Piezas estáticas fusionadas en una sola malla con color por vértice (1 draw call por modelo).
 * - Las partes animadas o con estado propio (pantalla, palanca, rotor) son mallas separadas.
 * - El personaje es un SkinnedMesh rígido (1 draw call) con huesos simples.
 */
import * as THREE from 'three';
import type {
  IModelFactory, WorkerRig, PanelModel, EquipmentModel, QualityLevel,
} from '../../contracts';
import { GeoBuilder, bevelBox, lumpy, recolor, rng, segment, xform, type V3 } from './Geo';
import { Textures, SOLID_UV, PANEL_GLASS_RECT, CRATE_WOOD_RECT, CRATE_ICON_RECT, FACADE_TILES } from './Textures';
import { Materials, type SurfaceMaterial } from './Materials';

/** Paleta de la marca y del mundo. */
export const PALETTE = {
  dark: 0x0e2420, sun: 0xffb82e, leaf: 0x3fa34d, panel: 0x1e3a5f, panelLight: 0x9fb8d0,
  orange: 0xf28c28, blue: 0x2f7be0, violet: 0x8b5cf6,
  alu: 0xc6cfd5, steel: 0x8e9ba2, galv: 0xaab6bc, darkSteel: 0x4a5559, concrete: 0xbcb6aa,
  white: 0xf1f4f2, offWhite: 0xe2e7e5, wood: 0xa8774a, woodDark: 0x6b4a33,
} as const;

const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);

function mesh(geo: THREE.BufferGeometry, mat: THREE.Material, cast = true, receive = true): THREE.Mesh {
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = cast; m.receiveShadow = receive;
  return m;
}

/** Lerp exponencial independiente del framerate. */
function damp(a: number, b: number, k: number, dt: number): number { return a + (b - a) * (1 - Math.exp(-k * dt)); }

/** Animaciones "autónomas" vía onBeforeRender (no necesitan un update externo). */
function selfAnimate(obj: THREE.Object3D, fn: (t: number, dt: number) => void): void {
  let last = -1;
  obj.onBeforeRender = () => {
    const t = performance.now() / 1000;
    const dt = last < 0 ? 0 : Math.min(0.1, t - last);
    if (t === last) return;
    last = t;
    fn(t, dt);
  };
}

export interface ModelFactoryOptions {
  quality?: QualityLevel;
  textures?: Textures;
  /**
   * Personaje con SkinnedMesh (1 draw call). Pasar `renderer.capabilities.isWebGL2`:
   * en WebGL1 el skinning de three r160 no compila, y se usa un rig rígido (≈12 draw calls).
   */
  skinning?: boolean;
}

export class ModelFactory implements IModelFactory {
  readonly textures: Textures;
  readonly mats: Materials;
  private geoCache = new Map<string, THREE.BufferGeometry>();
  readonly skinning: boolean;

  constructor(opts: ModelFactoryOptions = {}) {
    this.skinning = opts.skinning ?? true;
    this.textures = opts.textures ?? new Textures();
    this.mats = new Materials(this.textures, opts.quality ?? 'high');
  }

  private cachedGeo(key: string, make: () => THREE.BufferGeometry): THREE.BufferGeometry {
    let g = this.geoCache.get(key);
    if (!g) { g = make(); this.geoCache.set(key, g); }
    return g;
  }

  /** Intensidad 0..1 de luminarias públicas (postes). Llamar con env.nightFactor() cada frame o al cambiar. */
  setNight(f: number): void {
    const c = this.mats.lamp.color;
    const k = THREE.MathUtils.clamp(f, 0, 1);
    c.setRGB(0.33 + k * 2.6, 0.31 + k * 2.0, 0.28 + k * 1.1);
  }

  /* ==================================================================== PERSONAJE */

  createWorker(colors: { helmet?: number; vest?: number } = {}): WorkerRig {
    const C = {
      skin: 0xe2ad84, skinDark: 0xc98f68, hair: 0x3b2a20, shirt: 0x4f7ea8, pants: 0x2d3d55,
      boot: 0x5a3d2b, sole: 0x2b211a, glove: 0xd9a441, belt: 0x3b2a1e, reflect: 0xe8eef0,
      helmet: colors.helmet ?? PALETTE.sun, vest: colors.vest ?? PALETTE.orange,
    };
    // Articulaciones en pose de enlace (coordenadas de modelo).
    const J: Record<string, V3> = {
      root: [0, 0, 0], hips: [0, 0.88, 0], spine: [0, 0.96, 0], head: [0, 1.44, 0],
      shL: [0.268, 1.37, 0], elL: [0.29, 1.11, 0], shR: [-0.268, 1.37, 0], elR: [-0.29, 1.11, 0],
      thL: [0.105, 0.86, 0], knL: [0.105, 0.47, 0], thR: [-0.105, 0.86, 0], knR: [-0.105, 0.47, 0],
    };
    const parent: Record<string, string | null> = {
      root: null, hips: 'root', spine: 'hips', head: 'spine', shL: 'spine', elL: 'shL', shR: 'spine', elR: 'shR',
      thL: 'hips', knL: 'thL', thR: 'hips', knR: 'thR',
    };
    const names = Object.keys(J);
    const bones: THREE.Bone[] = [];
    const B: Record<string, THREE.Bone> = {};
    const idx: Record<string, number> = {};
    names.forEach((n, i) => {
      const b = new THREE.Bone(); b.name = n; B[n] = b; idx[n] = i; bones.push(b);
      const p = parent[n];
      const pp = p ? J[p] : [0, 0, 0];
      b.position.set(J[n][0] - pp[0], J[n][1] - pp[1], J[n][2] - pp[2]);
      if (p) B[p].add(b);
    });

    // Con skinning: un solo GeoBuilder (1 draw call). Sin skinning (WebGL1, donde el skinning de
    // three r160 no compila): un GeoBuilder por hueso, con la geometría en espacio local del hueso.
    const skinned = this.skinning;
    const gb = new GeoBuilder(42);
    const perBone: GeoBuilder[] = names.map((_, i) => new GeoBuilder(42 + i));
    const add = (g: THREE.BufferGeometry, color: number, bone: string, t?: { p?: V3; r?: V3; s?: V3 | number }, tag?: string) => {
      if (skinned) { gb.add(g, color, t, { bone: idx[bone], tag }); return; }
      const m = new THREE.Matrix4().makeTranslation(-J[bone][0], -J[bone][1], -J[bone][2]).multiply(xform(t).clone());
      perBone[idx[bone]].add(g, color, m, { tag });
    };

    // Piernas (proporciones "cozy": piernas cortas y gruesas, cabeza grande)
    for (const side of [1, -1]) {
      const th = side > 0 ? 'thL' : 'thR', kn = side > 0 ? 'knL' : 'knR';
      const x = 0.105 * side;
      add(segment(V(x, 0.87, 0), V(x, 0.47, 0.005), 0.105, 0.086, 12), C.pants, th);
      add(new THREE.SphereGeometry(0.086, 12, 8), C.pants, kn, { p: [x, 0.47, 0.005] });
      add(segment(V(x, 0.47, 0.005), V(x, 0.15, 0), 0.084, 0.072, 12), C.pants, kn);
      add(new THREE.CylinderGeometry(0.085, 0.09, 0.09, 12), C.boot, kn, { p: [x, 0.16, 0] });
      add(bevelBox(0.16, 0.13, 0.29, 0.035), C.boot, kn, { p: [x, 0.08, 0.04] });
      add(new THREE.BoxGeometry(0.17, 0.035, 0.305), C.sole, kn, { p: [x, 0.0175, 0.04] });
    }
    // Cadera, cinturón
    add(bevelBox(0.35, 0.19, 0.23, 0.05), C.pants, 'hips', { p: [0, 0.885, 0] });
    add(new THREE.BoxGeometry(0.36, 0.055, 0.24), C.belt, 'hips', { p: [0, 0.955, 0] });
    add(new THREE.BoxGeometry(0.06, 0.045, 0.012), 0xd8b25a, 'hips', { p: [0, 0.955, 0.122] });
    add(bevelBox(0.08, 0.11, 0.07, 0.015), C.belt, 'hips', { p: [-0.19, 0.9, 0.03] }); // portaherramientas
    // Torso: camisa + chaleco + bandas reflectivas
    add(new THREE.CylinderGeometry(0.212, 0.178, 0.49, 16), C.shirt, 'spine', { p: [0, 1.195, 0], s: [1, 1, 0.68] });
    add(new THREE.CylinderGeometry(0.226, 0.19, 0.39, 16), C.vest, 'spine', { p: [0, 1.19, 0], s: [1, 1, 0.72] }, 'vest');
    add(new THREE.BoxGeometry(0.05, 0.39, 0.02), C.shirt, 'spine', { p: [0, 1.19, 0.152] });
    add(new THREE.BoxGeometry(0.008, 0.35, 0.022), 0x8a8f90, 'spine', { p: [0, 1.19, 0.157] });
    for (const y of [1.1, 1.24]) {
      const r = 0.19 + (0.226 - 0.19) * ((y - 0.995) / 0.39);
      add(new THREE.CylinderGeometry(r + 0.005, r + 0.003, 0.04, 16), C.reflect, 'spine', { p: [0, y, 0], s: [1, 1, 0.725] });
    }
    for (const side of [1, -1]) {
      add(new THREE.BoxGeometry(0.085, 0.045, 0.3), C.vest, 'spine', { p: [0.13 * side, 1.39, 0] }, 'vest');
      add(new THREE.BoxGeometry(0.034, 0.047, 0.302), C.reflect, 'spine', { p: [0.13 * side, 1.392, 0] });
      add(new THREE.SphereGeometry(0.085, 12, 8), C.shirt, 'spine', { p: [0.265 * side, 1.36, 0] });
    }
    add(new THREE.CylinderGeometry(0.085, 0.1, 0.05, 12), C.shirt, 'spine', { p: [0, 1.43, 0], s: [1, 1, 0.85] });
    // radio en el pecho
    add(new THREE.BoxGeometry(0.055, 0.085, 0.03), 0x263532, 'spine', { p: [0.095, 1.3, 0.158] });
    add(new THREE.CylinderGeometry(0.007, 0.007, 0.08, 4), 0x263532, 'spine', { p: [0.112, 1.37, 0.158] });
    // Cabeza
    add(new THREE.CylinderGeometry(0.06, 0.066, 0.1, 10), C.skin, 'head', { p: [0, 1.47, 0] });
    add(new THREE.SphereGeometry(0.17, 18, 14), C.skin, 'head', { p: [0, 1.625, 0.005], s: [1, 1.04, 1] });
    add(new THREE.SphereGeometry(0.177, 14, 6, Math.PI, Math.PI, 0.3 * Math.PI, 0.42 * Math.PI), C.hair, 'head', { p: [0, 1.632, -0.004] });
    for (const side of [1, -1]) {
      add(new THREE.SphereGeometry(0.019, 8, 6), 0x1d1a18, 'head', { p: [0.06 * side, 1.632, 0.158], s: [0.8, 1.15, 0.5] });
      add(new THREE.SphereGeometry(0.006, 6, 4), 0xffffff, 'head', { p: [0.066 * side, 1.642, 0.167] });
      add(new THREE.BoxGeometry(0.055, 0.014, 0.014), C.hair, 'head', { p: [0.062 * side, 1.678, 0.156], r: [0, 0, -0.14 * side] });
      add(new THREE.SphereGeometry(0.036, 8, 6), C.skin, 'head', { p: [0.167 * side, 1.625, 0], s: [0.55, 1, 0.8] });
      add(new THREE.SphereGeometry(0.03, 8, 4), 0xeea08a, 'head', { p: [0.1 * side, 1.592, 0.13], s: [1, 0.6, 0.45] });
    }
    add(new THREE.SphereGeometry(0.026, 8, 6), C.skinDark, 'head', { p: [0, 1.603, 0.172], s: [1, 1.1, 0.9] });
    add(new THREE.BoxGeometry(0.055, 0.011, 0.01), 0x7a3b2e, 'head', { p: [0, 1.56, 0.16] });
    // Casco
    add(new THREE.SphereGeometry(0.196, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), C.helmet, 'head', { p: [0, 1.665, 0], s: [1, 0.9, 1.06] }, 'helmet');
    add(new THREE.CylinderGeometry(0.226, 0.234, 0.024, 22), C.helmet, 'head', { p: [0, 1.665, 0.03], s: [1, 1, 1.13] }, 'helmet');
    add(new THREE.BoxGeometry(0.046, 0.044, 0.36), C.helmet, 'head', { p: [0, 1.83, 0] }, 'helmet');
    add(new THREE.CylinderGeometry(0.198, 0.198, 0.014, 20), 0x2b2b2b, 'head', { p: [0, 1.672, 0], s: [1, 1, 1.06] });
    add(new THREE.BoxGeometry(0.07, 0.045, 0.006), PALETTE.leaf, 'head', { p: [0, 1.77, 0.178], r: [-0.6, 0, 0] });
    // Brazos
    for (const side of [1, -1]) {
      const sh = side > 0 ? 'shL' : 'shR', el = side > 0 ? 'elL' : 'elR';
      const x0 = 0.268 * side, x1 = 0.29 * side, x2 = 0.297 * side;
      add(segment(V(x0, 1.37, 0), V(x1, 1.12, 0), 0.075, 0.066, 12), C.shirt, sh);
      add(new THREE.SphereGeometry(0.066, 10, 8), C.shirt, el, { p: [x1, 1.11, 0] });
      add(segment(V(x1, 1.11, 0), V(x2, 0.93, 0.01), 0.064, 0.056, 12), C.shirt, el);
      add(new THREE.CylinderGeometry(0.064, 0.058, 0.055, 10), C.glove, el, { p: [x2, 0.915, 0.01] });
      add(bevelBox(0.088, 0.12, 0.1, 0.025), C.glove, el, { p: [x2, 0.85, 0.014] });
      add(bevelBox(0.036, 0.066, 0.036, 0.01), C.glove, el, { p: [x2 - 0.036 * side, 0.868, 0.058], r: [0.3, 0, 0] });
    }

    const root = new THREE.Group(); root.name = 'worker';
    const recolorTargets: { geo: THREE.BufferGeometry; tags: Map<string, [number, number][]> }[] = [];
    if (skinned) {
      const geo = gb.build();
      const skinMesh = new THREE.SkinnedMesh(geo, this.mats.vcSmooth);
      skinMesh.castShadow = true; skinMesh.receiveShadow = true;
      skinMesh.frustumCulled = false;
      skinMesh.add(bones[0]);
      skinMesh.updateMatrixWorld(true);
      skinMesh.bind(new THREE.Skeleton(bones));
      root.add(skinMesh);
      recolorTargets.push({ geo, tags: gb.tags });
    } else {
      root.add(bones[0]);
      perBone.forEach((b, i) => {
        if (b.vertexCount === 0) return;
        const geo = b.build();
        const m = mesh(geo, this.mats.vcSmooth);
        bones[i].add(m);
        recolorTargets.push({ geo, tags: b.tags });
      });
    }
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(0.95, 0.95), this.mats.contactShadow);
    shadow.rotation.x = -Math.PI / 2; shadow.position.y = 0.012; shadow.renderOrder = 1;
    root.add(shadow);

    const carryAnchor = new THREE.Group(); carryAnchor.name = 'carryAnchor';
    carryAnchor.position.set(0, 1.97 - J.spine[1], 0.05);
    B.spine.add(carryAnchor);
    const handAnchor = new THREE.Group(); handAnchor.name = 'handAnchor';
    handAnchor.position.set(-0.007, 0.83 - J.elR[1], 0.05);
    B.elR.add(handAnchor);

    // Estado de animación
    type Ang = { x: number; y: number; z: number };
    const cur: Record<string, Ang> = {};
    for (const n of names) cur[n] = { x: 0, y: 0, z: 0 };
    let phase = 0, time = 0, walk = 0;
    const hipY = J.hips[1];

    const animate = (dt: number, speed: number, pose: 'idle' | 'carry' | 'cable' | 'tool') => {
      dt = Math.min(dt, 0.1);
      time += dt;
      speed = THREE.MathUtils.clamp(speed, 0, 1);
      walk = damp(walk, speed > 0.03 ? 1 : 0, 8, dt);
      const amp = walk * (0.45 + 0.55 * speed);
      phase += dt * (5 + 6 * speed) * (speed > 0.03 ? 1 : walk);
      const s = Math.sin(phase), c = Math.cos(phase);
      const breath = Math.sin(time * 1.9);
      const tgt: Record<string, Ang> = {};
      for (const n of names) tgt[n] = { x: 0, y: 0, z: 0 };

      // Piernas
      tgt.thL.x = -s * 0.62 * amp; tgt.thR.x = s * 0.62 * amp;
      tgt.knL.x = amp * (0.12 + 0.95 * Math.max(0, c)); tgt.knR.x = amp * (0.12 + 0.95 * Math.max(0, -c));
      // Torso
      tgt.spine.x = 0.07 * amp + breath * 0.018 * (1 - walk);
      tgt.spine.y = s * 0.13 * amp; tgt.hips.y = -s * 0.07 * amp;
      tgt.head.y = -s * 0.08 * amp + (1 - walk) * Math.sin(time * 0.45) * 0.28;
      tgt.head.x = -0.04 * amp + (1 - walk) * Math.sin(time * 0.31) * 0.05;
      // Brazos (por defecto: balanceo)
      tgt.shL.x = s * 0.55 * amp; tgt.shR.x = -s * 0.55 * amp;
      tgt.shL.z = 0.06 + breath * 0.015 * (1 - walk); tgt.shR.z = -0.06 - breath * 0.015 * (1 - walk);
      tgt.elL.x = -0.18 - 0.35 * amp * (0.5 + 0.5 * s); tgt.elR.x = -0.18 - 0.35 * amp * (0.5 - 0.5 * s);

      if (pose === 'carry') {
        tgt.shL.x = tgt.shR.x = -2.72 + Math.sin(phase * 2) * 0.03 * amp;
        tgt.shL.z = 0.32; tgt.shR.z = -0.32;
        tgt.elL.x = tgt.elR.x = -0.35;
        tgt.elL.z = -0.55; tgt.elR.z = 0.55;
        tgt.spine.x = 0.02; tgt.spine.y *= 0.4;
        tgt.head.y *= 0.3; tgt.head.x = -0.05;
      } else if (pose === 'cable') {
        tgt.shR.x = -0.85 + s * 0.06 * amp; tgt.shR.z = 0.12; tgt.elR.x = -0.55;
      } else if (pose === 'tool') {
        tgt.shR.x = -0.95; tgt.shR.z = 0.32; tgt.elR.x = -1.25; tgt.elR.y = 0.2;
        tgt.shL.x = -0.75; tgt.shL.z = -0.25; tgt.elL.x = -1.05;
        tgt.head.x = 0.32; tgt.head.y = 0.12 * (1 - walk);
        tgt.spine.x = 0.06;
      }
      const k = 12;
      for (const n of names) {
        const a = cur[n], b = tgt[n];
        a.x = damp(a.x, b.x, k, dt); a.y = damp(a.y, b.y, k, dt); a.z = damp(a.z, b.z, k, dt);
        B[n].rotation.set(a.x, a.y, a.z);
      }
      B.hips.position.y = hipY + (Math.abs(c) * 0.045 - 0.03) * amp + breath * 0.003 * (1 - walk);
      shadow.scale.setScalar(1 - 0.08 * amp * Math.abs(c));
    };

    const setCosmetics = (cc: { helmet?: number; vest?: number }) => {
      for (const t of recolorTargets) {
        if (cc.helmet !== undefined) recolor(t.geo, t.tags.get('helmet'), cc.helmet);
        if (cc.vest !== undefined) recolor(t.geo, t.tags.get('vest'), cc.vest);
      }
    };

    animate(0.016, 0, 'idle');
    return { root, carryAnchor, handAnchor, animate, setCosmetics };
  }

  /* ==================================================================== PANEL + MONTAJE */

  /** Geometría compartida del panel (marco + vidrio + backsheet), origen en su cara inferior. */
  panelGeometry(): THREE.BufferGeometry {
    return this.cachedGeo('panel', () => {
      const gb = new GeoBuilder(3);
      const W = 2.0, D = 1.15, T = 0.04, f = 0.035;
      const solid = { uv: SOLID_UV.panel };
      gb.box(W - 0.02, 0.018, D - 0.02, 0xe9ecee, { p: [0, 0.011, 0] }, solid);
      gb.box(W, T, f, PALETTE.alu, { p: [0, T / 2, D / 2 - f / 2] }, solid);
      gb.box(W, T, f, PALETTE.alu, { p: [0, T / 2, -D / 2 + f / 2] }, solid);
      gb.box(f, T, D - 2 * f, PALETTE.alu, { p: [W / 2 - f / 2, T / 2, 0] }, solid);
      gb.box(f, T, D - 2 * f, PALETTE.alu, { p: [-W / 2 + f / 2, T / 2, 0] }, solid);
      const [u0, v0, u1, v1] = PANEL_GLASS_RECT;
      gb.add(new THREE.PlaneGeometry(W - 2 * f + 0.004, D - 2 * f + 0.004), 0xffffff,
        { p: [0, T - 0.006, 0], r: [-Math.PI / 2, 0, 0] }, { uvRect: [u1 - u0, v1 - v0, u0, v0] });
      // caja de conexión trasera
      gb.box(0.16, 0.025, 0.11, 0x1f2426, { p: [0, -0.002, -0.3] }, solid);
      return gb.build();
    });
  }

  createPanel(): PanelModel {
    const mat = this.mats.panel();
    const clean = this.textures.solarPanel(false), dirtyTex = this.textures.solarPanel(true);
    const root = new THREE.Group(); root.name = 'panel';
    const m = mesh(this.panelGeometry(), mat);
    root.add(m);
    mat.emissiveMap = clean;
    return {
      root,
      setDirty: (on: boolean) => { mat.map = on ? dirtyTex : clean; mat.emissiveMap = mat.map; mat.needsUpdate = true; },
      setGlow: (v: number) => { mat.emissiveIntensity = Math.max(0, v) * 1.4; },
    };
  }

  createMount(): { root: THREE.Group; tilt: THREE.Group; ghost: THREE.Object3D } {
    const PIVOT = 1.1;
    const baseGeo = this.cachedGeo('mount-base', () => {
      const gb = new GeoBuilder(5);
      for (const x of [-0.72, 0.72]) {
        gb.cyl(0.19, 0.22, 0.3, PALETTE.concrete, 10, { p: [x, 0.1, 0] }, { jitter: 0.03 });
        gb.box(0.2, 0.012, 0.2, PALETTE.darkSteel, { p: [x, 0.256, 0] });
        gb.box(0.08, PIVOT - 0.11 - 0.25, 0.08, PALETTE.galv, { p: [x, 0.25 + (PIVOT - 0.36) / 2, 0] });
        gb.box(0.12, 0.09, 0.12, PALETTE.darkSteel, { p: [x, PIVOT - 0.12, 0] });
        // riostras en A
        for (const z of [-0.5, 0.5]) {
          gb.add(segment(V(x, 0.03, z), V(x, 0.62, 0), 0.022, 0.022, 5), PALETTE.galv);
          gb.box(0.12, 0.02, 0.12, PALETTE.concrete, { p: [x, 0.01, z] });
        }
      }
      gb.add(new THREE.CylinderGeometry(0.035, 0.035, 2.02, 8), PALETTE.steel, { p: [0, PIVOT - 0.11, 0], r: [0, 0, Math.PI / 2] });
      return gb.build();
    });
    const tiltGeo = this.cachedGeo('mount-tilt', () => {
      const gb = new GeoBuilder(6);
      for (const z of [-0.3, 0.3]) gb.box(2.04, 0.045, 0.05, PALETTE.galv, { p: [0, -0.0225, z] });
      for (const x of [-0.72, 0.72]) gb.box(0.06, 0.05, 0.8, PALETTE.steel, { p: [x, -0.07, 0] });
      // abrazaderas
      for (const x of [-0.95, -0.02, 0.95]) for (const z of [-0.575, 0.575]) gb.box(0.05, 0.03, 0.03, 0x6f7a80, { p: [x, 0.03, z * 0.995] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'mount';
    root.add(mesh(baseGeo, this.mats.vcSatin, this.mats.quality !== 'low'));
    const tilt = new THREE.Group(); tilt.name = 'tilt';
    tilt.position.set(0, PIVOT, 0); tilt.rotation.x = 0.45;
    root.add(tilt);
    tilt.add(mesh(tiltGeo, this.mats.vcSatin, false)); // la sombra la da el panel
    const ghostGeo = this.cachedGeo('ghost', () => new THREE.BoxGeometry(2.0, 0.04, 1.15).translate(0, 0.02, 0));
    const ghost = new THREE.Mesh(ghostGeo, this.mats.ghost);
    ghost.name = 'ghost';
    tilt.add(ghost);
    return { root, tilt, ghost };
  }

  /* ==================================================================== EQUIPOS */

  createInverter(): EquipmentModel {
    const geo = this.cachedGeo('inverter', () => {
      const gb = new GeoBuilder(7);
      const cy = 1.55;
      gb.box(0.9, 0.06, 0.03, PALETTE.darkSteel, { p: [0, 2.2, 0.015] });
      gb.box(0.9, 0.06, 0.03, PALETTE.darkSteel, { p: [0, 0.9, 0.015] });
      gb.add(bevelBox(1.1, 1.4, 0.28, 0.05), PALETTE.white, { p: [0, cy, 0.17] });
      gb.box(1.02, 0.05, 0.27, 0xd5dbd9, { p: [0, cy + 0.69, 0.17] }); // tapa superior
      // disipadores laterales
      for (const side of [-1, 1]) for (let i = 0; i < 5; i++) {
        gb.box(0.012, 1.15, 0.2, 0x98a3a8, { p: [side * (0.565 + i * 0.024), cy, 0.15] });
      }
      // prensacables inferiores (naranja = PV, azul = BAT, violeta = AC)
      [[-0.3, PALETTE.orange], [-0.1, PALETTE.blue], [0.1, PALETTE.violet], [0.3, 0x55605d]].forEach(([x, col]) => {
        gb.cyl(0.035, 0.035, 0.07, 0x2b3331, 8, { p: [x, cy - 0.735, 0.17] });
        gb.cyl(0.04, 0.04, 0.02, col, 8, { p: [x, cy - 0.705, 0.17] });
      });
      // interruptor DC rotativo lateral
      gb.box(0.12, 0.16, 0.09, 0xd8dcdb, { p: [0.42, cy - 0.5, 0.33] });
      gb.box(0.03, 0.12, 0.05, 0xd23b2e, { p: [0.42, cy - 0.5, 0.38], r: [0, 0, 0.6] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'inverter';
    root.add(mesh(geo, this.mats.vcSatin));
    const face = this.textures.inverterFace();
    const faceMat = this.mats.surface({ map: face.map.texture, emissive: 0xffffff, emissiveMap: face.emissive.texture, emissiveIntensity: 1.6, roughness: 0.35, flatShading: false });
    const plate = mesh(new THREE.PlaneGeometry(0.84, 1.05), faceMat, false, true);
    plate.position.set(0, 1.58, 0.311);
    root.add(plate);
    const setScreen = (text: string, color = '#5fe3f5') => {
      const c = new THREE.Color().setStyle(color, THREE.LinearSRGBColorSpace);
      const red = c.r > 0.75 && c.g < 0.45;
      const amber = c.r > 0.75 && c.g >= 0.45 && c.g < 0.85 && c.b < 0.45;
      face.draw(text, color, [!red && text !== 'STANDBY', amber, red]);
    };
    return { root, terminal: V(0, 0.78, 0.17), setScreen };
  }

  createBattery(): EquipmentModel & { setCharge(pct: number): void } {
    const geo = this.cachedGeo('battery', () => {
      const gb = new GeoBuilder(8);
      gb.box(0.96, 0.08, 0.56, 0x2d3b38, { p: [0, 0.04, 0] });
      gb.add(bevelBox(1.0, 1.3, 0.6, 0.04), PALETTE.white, { p: [0, 0.73, 0] });
      gb.box(1.02, 0.06, 0.62, PALETTE.dark, { p: [0, 1.4, 0] });
      // puerta frontal + rejillas
      gb.box(0.86, 1.1, 0.012, 0xe6ebe9, { p: [0, 0.72, 0.302] });
      for (let i = 0; i < 6; i++) gb.box(0.5, 0.018, 0.01, 0x3a4744, { p: [-0.1, 0.24 + i * 0.045, 0.31] });
      // marco de la barra de carga
      gb.box(0.22, 0.52, 0.012, 0x1d2826, { p: [0.25, 0.95, 0.31] });
      // franja de marca
      gb.box(0.04, 1.1, 0.014, PALETTE.leaf, { p: [-0.4, 0.72, 0.305] });
      // rayo
      const bolt = new THREE.Shape();
      bolt.moveTo(0.02, 0.1); bolt.lineTo(-0.05, -0.01); bolt.lineTo(0.0, -0.01); bolt.lineTo(-0.025, -0.1);
      bolt.lineTo(0.05, 0.02); bolt.lineTo(0.0, 0.02); bolt.closePath();
      gb.add(new THREE.ShapeGeometry(bolt), PALETTE.sun, { p: [-0.12, 1.05, 0.31], s: 1.6 });
      // bornes / prensacables
      gb.cyl(0.04, 0.04, 0.06, PALETTE.blue, 8, { p: [0.35, 1.25, 0.3], r: [Math.PI / 2, 0, 0] });
      gb.cyl(0.04, 0.04, 0.06, 0x2b3331, 8, { p: [0.22, 1.25, 0.3], r: [Math.PI / 2, 0, 0] });
      // manija
      gb.box(0.03, 0.18, 0.03, 0x9aa5a8, { p: [0.36, 0.62, 0.33] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'battery';
    root.add(mesh(geo, this.mats.vcSatin));
    // segmentos de carga (malla de brillo con colores por vértice actualizables)
    const SEG = 5;
    const sb = new GeoBuilder(9);
    for (let i = 0; i < SEG; i++) sb.box(0.16, 0.075, 0.01, 0xffffff, { p: [0.25, 0.75 + i * 0.1, 0.318] });
    sb.add(new THREE.CircleGeometry(0.018, 10), 0xffffff, { p: [0.25, 1.25, 0.318] }); // LED
    const segGeo = sb.build();
    const segMesh = mesh(segGeo, this.mats.glow, false, false);
    root.add(segMesh);
    const per = segGeo.attributes.position.count / (SEG + 0) ;
    const colAttr = segGeo.attributes.color as THREE.BufferAttribute;
    const boxVerts = 36;
    let lastKey = '';
    const setCharge = (pct: number) => {
      pct = THREE.MathUtils.clamp(pct, 0, 1);
      const lit = Math.round(pct * SEG + 0.001 * 0);
      const on = pct <= 0 ? 0 : Math.max(1, Math.ceil(pct * SEG - 0.0001));
      const col = pct < 0.25 ? new THREE.Color(0xff4d4d) : pct < 0.55 ? new THREE.Color(0xffb82e) : new THREE.Color(0x46e06a);
      const key = on + ':' + col.getHex();
      if (key === lastKey) return;
      lastKey = key;
      void lit; void per;
      for (let i = 0; i < SEG; i++) {
        const c = i < on ? col : new THREE.Color(0.02, 0.03, 0.03);
        for (let v = i * boxVerts; v < (i + 1) * boxVerts; v++) colAttr.setXYZ(v, c.r, c.g, c.b);
      }
      const led = new THREE.Color(pct > 0 ? 0x46e06a : 0xff4d4d);
      for (let v = SEG * boxVerts; v < colAttr.count; v++) colAttr.setXYZ(v, led.r, led.g, led.b);
      colAttr.needsUpdate = true;
    };
    setCharge(0);
    return { root, terminal: V(0.35, 1.25, 0.34), setCharge };
  }

  createProtectionBox(): EquipmentModel {
    const geo = this.cachedGeo('protection', () => {
      const gb = new GeoBuilder(10);
      const cy = 1.5;
      gb.add(bevelBox(0.6, 0.8, 0.22, 0.03), 0xdfe4e2, { p: [0, cy, 0.11] });
      gb.box(0.5, 0.36, 0.012, 0x2a3a40, { p: [0, cy + 0.06, 0.222] }); // visor ahumado
      for (let i = 0; i < 4; i++) {
        const x = -0.18 + i * 0.12;
        gb.box(0.09, 0.2, 0.02, 0xf4f6f5, { p: [x, cy + 0.06, 0.232] });
        gb.box(0.04, 0.06, 0.03, i < 2 ? PALETTE.orange : PALETTE.blue, { p: [x, cy + 0.09, 0.245] });
      }
      gb.box(0.6, 0.07, 0.016, PALETTE.orange, { p: [0, cy + 0.33, 0.222] });
      // advertencia
      const tri = new THREE.Shape(); tri.moveTo(0, 0.07); tri.lineTo(0.065, -0.045); tri.lineTo(-0.065, -0.045); tri.closePath();
      gb.add(new THREE.ShapeGeometry(tri), PALETTE.sun, { p: [0, cy - 0.24, 0.223] });
      gb.box(0.015, 0.05, 0.004, 0x111111, { p: [0, cy - 0.235, 0.226] });
      for (const x of [-0.15, 0, 0.15]) gb.cyl(0.03, 0.03, 0.06, 0x2b3331, 8, { p: [x, cy - 0.43, 0.11] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'protection';
    root.add(mesh(geo, this.mats.vcSatin));
    return { root, terminal: V(0, 1.06, 0.11) };
  }

  createSwitchboard(): EquipmentModel {
    const geo = this.cachedGeo('switchboard', () => {
      const gb = new GeoBuilder(11);
      const cy = 1.5;
      gb.add(bevelBox(0.9, 1.1, 0.24, 0.03), 0xa9b4b8, { p: [0, cy, 0.12] });
      gb.add(bevelBox(0.82, 1.0, 0.03, 0.01), 0xc3ccd0, { p: [0, cy, 0.25] }); // puerta
      for (const y of [cy + 0.32, cy - 0.32]) gb.box(0.03, 0.1, 0.04, 0x5c666a, { p: [-0.42, y, 0.25] }); // bisagras
      gb.box(0.035, 0.16, 0.04, 0x2b3331, { p: [0.35, cy, 0.28] }); // manija
      // ventanita con térmicas
      gb.box(0.5, 0.16, 0.01, 0x24323a, { p: [0, cy + 0.18, 0.268] });
      for (let i = 0; i < 6; i++) gb.box(0.05, 0.11, 0.01, 0xf2f2f0, { p: [-0.19 + i * 0.076, cy + 0.18, 0.272] });
      // cartel de riesgo eléctrico
      const tri = new THREE.Shape(); tri.moveTo(0, 0.11); tri.lineTo(0.1, -0.07); tri.lineTo(-0.1, -0.07); tri.closePath();
      gb.add(new THREE.ShapeGeometry(tri), PALETTE.sun, { p: [0, cy - 0.2, 0.267] });
      const bolt = new THREE.Shape();
      bolt.moveTo(0.01, 0.06); bolt.lineTo(-0.025, -0.005); bolt.lineTo(0, -0.005); bolt.lineTo(-0.012, -0.055);
      bolt.lineTo(0.027, 0.012); bolt.lineTo(0.002, 0.012); bolt.closePath();
      gb.add(new THREE.ShapeGeometry(bolt), 0x111111, { p: [0, cy - 0.21, 0.269] });
      gb.box(0.82, 0.05, 0.012, PALETTE.violet, { p: [0, cy + 0.44, 0.268] });
      for (const x of [-0.2, 0, 0.2]) gb.cyl(0.03, 0.03, 0.07, 0x2b3331, 8, { p: [x, cy - 0.585, 0.12] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'switchboard';
    root.add(mesh(geo, this.mats.vcSatin));
    // pilotos luminosos
    const lb = new GeoBuilder(12);
    [0x46e06a, 0xffb82e, 0x46e06a].forEach((c, i) => lb.add(new THREE.CircleGeometry(0.022, 10), c, { p: [0.18 + (i - 1) * 0.07, 1.5 + 0.05, 0.268] }));
    root.add(mesh(lb.build(), this.mats.glow, false, false));
    return { root, terminal: V(0, 0.9, 0.12) };
  }

  createJunctionBox(): EquipmentModel {
    const geo = this.cachedGeo('junction', () => {
      const gb = new GeoBuilder(13);
      gb.cyl(0.14, 0.16, 0.2, PALETTE.concrete, 8, { p: [0, 0.07, 0] });
      gb.box(0.09, 0.82, 0.09, PALETTE.galv, { p: [0, 0.57, -0.06] });
      gb.add(bevelBox(0.52, 0.44, 0.2, 0.025), 0xe8ecea, { p: [0, 1.05, 0.06] });
      gb.box(0.48, 0.04, 0.012, PALETTE.orange, { p: [0, 1.2, 0.166] });
      for (const x of [-0.15, 0.15]) for (const y of [0.88, 1.22]) gb.cyl(0.012, 0.012, 0.012, 0x6f7a80, 6, { p: [x * 1.4, y, 0.165], r: [Math.PI / 2, 0, 0] });
      [[-0.12, PALETTE.orange], [0, PALETTE.orange], [0.12, PALETTE.orange]].forEach(([x, c]) => gb.cyl(0.028, 0.028, 0.06, c, 8, { p: [x, 0.8, 0.06] }));
      // ícono fusible
      gb.box(0.12, 0.05, 0.01, 0x2b3331, { p: [0, 1.04, 0.166] });
      gb.box(0.05, 0.03, 0.012, PALETTE.sun, { p: [0, 1.04, 0.168] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'junction';
    root.add(mesh(geo, this.mats.vcSatin));
    return { root, terminal: V(0, 0.78, 0.06) };
  }

  createConsole(): EquipmentModel & { setActive(on: boolean): void } {
    const TILT = 0.38, TOP = 1.02;
    const geo = this.cachedGeo('console', () => {
      const gb = new GeoBuilder(14);
      gb.cyl(0.42, 0.46, 0.08, PALETTE.concrete, 8, { p: [0, 0.04, 0] });
      gb.cyl(0.26, 0.34, 0.9, 0x2b4a44, 8, { p: [0, 0.53, 0] });
      gb.cyl(0.275, 0.29, 0.1, PALETTE.sun, 8, { p: [0, 0.3, 0] });
      gb.cyl(0.262, 0.272, 0.03, PALETTE.dark, 8, { p: [0, 0.37, 0] });
      const top = new THREE.Matrix4().compose(V(0, TOP, 0), new THREE.Quaternion().setFromEuler(new THREE.Euler(TILT, 0, 0)), V(1, 1, 1));
      const at = (x: number, y: number, z: number) => new THREE.Matrix4().multiplyMatrices(top, new THREE.Matrix4().makeTranslation(x, y, z));
      gb.add(bevelBox(0.9, 0.12, 0.66, 0.035), 0x24423c, at(0, 0, 0));
      gb.add(new THREE.CylinderGeometry(0.235, 0.25, 0.06, 20), 0x1a2b28, at(0, 0.075, 0));
      gb.add(new THREE.BoxGeometry(0.78, 0.01, 0.06), PALETTE.sun, at(0, 0.062, 0.29));
      // franjas de peligro alrededor del botón
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        gb.add(new THREE.BoxGeometry(0.06, 0.012, 0.03), i % 2 ? PALETTE.dark : PALETTE.sun,
          new THREE.Matrix4().multiplyMatrices(at(Math.cos(a) * 0.3, 0.062, Math.sin(a) * 0.3), new THREE.Matrix4().makeRotationY(-a)));
      }
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'console';
    root.add(mesh(geo, this.mats.vcSatin));
    const btnMat = this.mats.surface({ color: PALETTE.sun, emissive: PALETTE.sun, emissiveIntensity: 0.25, roughness: 0.35, flatShading: false });
    const btnGeo = new GeoBuilder(15);
    btnGeo.cyl(0.19, 0.2, 0.09, 0xffffff, 24, { p: [0, 0.045, 0] });
    btnGeo.cyl(0.15, 0.19, 0.03, 0xffffff, 24, { p: [0, 0.105, 0] });
    const btn = mesh(btnGeo.build(), btnMat, true, false);
    const pivot = new THREE.Group();
    pivot.position.set(0, TOP, 0); pivot.rotation.x = TILT;
    btn.position.y = 0.1;
    pivot.add(btn); root.add(pivot);
    let active = false;
    selfAnimate(btn, (t) => {
      const pulse = 0.5 + 0.5 * Math.sin(t * 4.2);
      btnMat.emissiveIntensity = active ? 1.6 + pulse * 1.6 : 0.18 + pulse * 0.12;
      btn.position.y = active ? 0.085 : 0.1;
    });
    return { root, terminal: V(0, 0.25, 0.3), setActive: (on: boolean) => { active = on; } };
  }

  createPump(): EquipmentModel & { setRunning(on: boolean): void } {
    const geo = this.cachedGeo('pump', () => {
      const gb = new GeoBuilder(16);
      // losa y pozo
      gb.box(1.4, 0.14, 0.9, PALETTE.concrete, { p: [0, 0.07, 0] });
      gb.cyl(0.32, 0.34, 0.45, 0xa9a397, 10, { p: [-0.95, 0.2, -0.2] }, { jitter: 0.02 });
      gb.cyl(0.26, 0.26, 0.02, 0x1d2a33, 10, { p: [-0.95, 0.43, -0.2] });
      // motor (eje X)
      gb.box(0.08, 0.16, 0.36, PALETTE.darkSteel, { p: [-0.15, 0.22, 0] });
      gb.box(0.08, 0.16, 0.36, PALETTE.darkSteel, { p: [0.25, 0.22, 0] });
      gb.cyl(0.17, 0.17, 0.5, PALETTE.blue, 14, { p: [0.05, 0.42, 0], r: [0, 0, Math.PI / 2] });
      for (let i = 0; i < 7; i++) gb.cyl(0.178, 0.178, 0.018, 0x2565b8, 14, { p: [0.0 + i * 0.05 - 0.1, 0.42, 0], r: [0, 0, Math.PI / 2] });
      gb.cyl(0.15, 0.17, 0.08, 0x2a3338, 14, { p: [0.34, 0.42, 0], r: [0, 0, Math.PI / 2] }); // tapa ventilador
      gb.box(0.16, 0.1, 0.14, 0x2a3338, { p: [0.05, 0.62, 0] }); // bornera
      // voluta de la bomba
      gb.cyl(0.21, 0.21, 0.14, 0x9aa5a8, 14, { p: [-0.36, 0.42, 0], r: [0, 0, Math.PI / 2] });
      gb.cyl(0.08, 0.08, 0.1, 0x9aa5a8, 10, { p: [-0.28, 0.42, 0], r: [0, 0, Math.PI / 2] });
      // succión desde el pozo
      gb.add(segment(V(-0.5, 0.42, 0), V(-0.95, 0.42, -0.2), 0.045, 0.045, 8), 0x3d4a50);
      gb.add(segment(V(-0.95, 0.42, -0.2), V(-0.95, 0.25, -0.2), 0.045, 0.045, 8), 0x3d4a50);
      // salida: sube y va hacia el bebedero (+Z)
      gb.add(segment(V(-0.36, 0.62, 0), V(-0.36, 1.25, 0), 0.045, 0.045, 8), 0x3d4a50);
      gb.add(new THREE.SphereGeometry(0.05, 8, 6), 0x3d4a50, { p: [-0.36, 1.25, 0] });
      gb.add(segment(V(-0.36, 1.25, 0), V(-0.36, 1.25, 1.35), 0.045, 0.045, 8), 0x3d4a50);
      gb.cyl(0.06, 0.06, 0.06, 0xd23b2e, 8, { p: [-0.36, 1.25, 0.4], r: [Math.PI / 2, 0, 0] }); // válvula
      gb.box(0.18, 0.03, 0.03, 0xd23b2e, { p: [-0.36, 1.32, 0.4] });
      // bebedero / tanque
      const tz = 1.55;
      gb.box(1.5, 0.08, 0.7, PALETTE.concrete, { p: [-0.36, 0.04, tz] });
      gb.box(1.4, 0.55, 0.06, 0xb5ae9f, { p: [-0.36, 0.35, tz - 0.3] });
      gb.box(1.4, 0.55, 0.06, 0xb5ae9f, { p: [-0.36, 0.35, tz + 0.3] });
      gb.box(0.06, 0.55, 0.54, 0xb5ae9f, { p: [0.31, 0.35, tz] });
      gb.box(0.06, 0.55, 0.54, 0xb5ae9f, { p: [-1.03, 0.35, tz] });
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'pump';
    root.add(mesh(geo, this.mats.vcSatin));
    // acople giratorio (visible) entre motor y bomba
    const rb = new GeoBuilder(17);
    rb.cyl(0.11, 0.11, 0.05, PALETTE.sun, 10, { r: [0, 0, Math.PI / 2] });
    rb.box(0.055, 0.2, 0.03, PALETTE.dark, {});
    const rotor = mesh(rb.build(), this.mats.vcSatin);
    rotor.position.set(-0.235, 0.42, 0);
    root.add(rotor);
    // agua
    const waterMat = this.mats.surface({ color: 0x3e95c9, roughness: 0.08, metalness: 0.1, transparent: true, opacity: 0.88, flatShading: false });
    const water = mesh(new THREE.PlaneGeometry(1.28, 0.54, 6, 3).rotateX(-Math.PI / 2), waterMat, false, true);
    water.position.set(-0.36, 0.42, 1.55);
    root.add(water);
    const streamMat = new THREE.MeshBasicMaterial({ color: 0xa7dcf5, transparent: true, opacity: 0.7 });
    const stream = mesh(new THREE.CylinderGeometry(0.03, 0.045, 0.82, 8, 1, true), streamMat, false, false);
    stream.position.set(-0.36, 0.84, 1.37);
    stream.visible = false;
    root.add(stream);
    let running = false, spin = 0, level = 0;
    const wpos = water.geometry.attributes.position as THREE.BufferAttribute;
    const base = Float32Array.from(wpos.array as Float32Array);
    selfAnimate(rotor, (t, dt) => {
      spin = damp(spin, running ? 22 : 0, 2, dt);
      rotor.rotation.x += spin * dt;
      level = damp(level, running ? 1 : 0, 0.4, dt);
      water.position.y = 0.36 + level * 0.12;
      stream.visible = running;
      stream.scale.y = 1 + Math.sin(t * 30) * 0.02;
      // ondas
      for (let i = 0; i < wpos.count; i++) {
        const x = base[i * 3], z = base[i * 3 + 2];
        wpos.setY(i, running ? Math.sin(t * 6 + x * 9 + z * 7) * 0.012 * (1 - Math.min(1, Math.hypot(x, z - 0.1 + 0.18) * 0.5)) : 0);
      }
      wpos.needsUpdate = true;
    });
    return { root, terminal: V(0.05, 0.66, 0.08), setRunning: (on: boolean) => { running = on; } };
  }

  /* ==================================================================== DEPÓSITO */

  createCrate(kind: 'battery' | 'protection' | 'kit' | 'panel'): THREE.Group {
    const geo = this.cachedGeo('crate:' + kind, () => {
      const gb = new GeoBuilder(18);
      const [wu0, wv0, wu1, wv1] = CRATE_WOOD_RECT;
      const wood = { uvRect: [wu1 - wu0, wv1 - wv0, wu0, wv0] as [number, number, number, number] };
      const [iu0, iv0, iu1, iv1] = CRATE_ICON_RECT[kind];
      const icon = { uvRect: [iu1 - iu0, iv1 - iv0, iu0, iv0] as [number, number, number, number] };
      const solid = { uv: SOLID_UV.crate };
      const flat = kind === 'panel';
      const W = flat ? 2.1 : 0.9, H = flat ? 0.22 : 0.8, D = flat ? 1.25 : 0.9;
      const tint = kind === 'panel' ? 0xd9c4a0 : 0xffffff;
      gb.box(W, H, D, tint, { p: [0, H / 2, 0] }, wood);
      // listones de borde
      const e = 0.06, k = 0xc59a6a;
      for (const sx of [-1, 1]) for (const sz of [-1, 1]) gb.box(e, H + 0.01, e, k, { p: [sx * (W / 2 - e / 2 + 0.01), H / 2, sz * (D / 2 - e / 2 + 0.01)] }, wood);
      for (const y of [e / 2, H - e / 2]) {
        for (const sz of [-1, 1]) gb.box(W + 0.02, e, e, k, { p: [0, y, sz * (D / 2 - e / 2 + 0.012)] }, wood);
        for (const sx of [-1, 1]) gb.box(e, e, D + 0.02, k, { p: [sx * (W / 2 - e / 2 + 0.012), y, 0] }, wood);
      }
      // zunchos
      const strap = 0x3f4a50;
      const xs = flat ? [-0.6, 0.6] : [-0.22, 0.22];
      for (const x of xs) {
        gb.box(0.045, H + 0.03, D + 0.035, strap, { p: [x, H / 2, 0] }, solid);
        gb.box(0.05, 0.03, 0.06, 0x9aa5a8, { p: [x, H + 0.012, D * 0.25] }, solid);
      }
      // placas con ícono
      const s = flat ? 0.18 : 0.32;
      if (!flat) {
        gb.add(new THREE.PlaneGeometry(s, s), 0xffffff, { p: [0, H * 0.48, D / 2 + 0.008] }, icon);
        gb.add(new THREE.PlaneGeometry(s, s), 0xffffff, { p: [W / 2 + 0.008, H * 0.48, 0], r: [0, Math.PI / 2, 0] }, icon);
      } else {
        gb.add(new THREE.PlaneGeometry(s, s), 0xffffff, { p: [0, H / 2, D / 2 + 0.03] }, icon);
      }
      gb.add(new THREE.PlaneGeometry(s * 1.2, s * 1.2), 0xffffff, { p: [0, H + 0.011, 0], r: [-Math.PI / 2, 0, 0] }, icon);
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'crate-' + kind;
    root.add(mesh(geo, this.mats.crate));
    return root;
  }

  createPallet(count: number): { root: THREE.Group; setCount(n: number): void } {
    const geo = this.cachedGeo('pallet', () => {
      const gb = new GeoBuilder(19);
      const [wu0, wv0, wu1, wv1] = CRATE_WOOD_RECT;
      const wood = { uvRect: [(wu1 - wu0) * 0.3, (wv1 - wv0) * 0.2, wu0, wv0] as [number, number, number, number] };
      for (const z of [-0.55, 0, 0.55]) for (const x of [-0.95, 0, 0.95]) gb.box(0.16, 0.08, 0.16, 0xb08350, { p: [x, 0.04, z] }, wood);
      for (const x of [-0.95, 0, 0.95]) gb.box(0.18, 0.03, 1.3, 0xc49a63, { p: [x, 0.095, 0] }, wood);
      for (let i = 0; i < 7; i++) gb.box(2.2, 0.025, 0.13, i % 2 ? 0xd2a86f : 0xc89d64, { p: [0, 0.122, -0.57 + i * 0.19] }, wood);
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'pallet';
    root.add(mesh(geo, this.mats.crate));
    let cap = Math.max(12, count);
    let inst: THREE.InstancedMesh | null = null;
    const build = () => {
      if (inst) { root.remove(inst); inst.dispose(); }
      inst = new THREE.InstancedMesh(this.panelGeometry(), this.mats.panelShared, cap);
      inst.castShadow = true; inst.receiveShadow = true;
      const m = new THREE.Matrix4();
      const r = rng(4);
      for (let i = 0; i < cap; i++) {
        m.makeRotationY((r() - 0.5) * 0.03);
        m.setPosition((r() - 0.5) * 0.02, 0.137 + i * 0.046, (r() - 0.5) * 0.02);
        inst.setMatrixAt(i, m);
      }
      root.add(inst);
    };
    build();
    const setCount = (n: number) => {
      n = Math.max(0, Math.floor(n));
      if (n > cap) { cap = n; build(); }
      if (!inst) return;
      inst.count = n;
      inst.visible = n > 0;
      inst.computeBoundingSphere();
    };
    setCount(count);
    return { root, setCount };
  }

  createRowPost(): { root: THREE.Group; setDefense(on: boolean): void } {
    const geo = this.cachedGeo('rowpost', () => {
      const gb = new GeoBuilder(20);
      gb.cyl(0.15, 0.17, 0.18, PALETTE.concrete, 8, { p: [0, 0.07, 0] });
      gb.box(0.11, 1.0, 0.11, PALETTE.galv, { p: [0, 0.65, 0] });
      gb.add(bevelBox(0.38, 0.3, 0.22, 0.03), PALETTE.sun, { p: [0, 1.25, 0] });
      gb.box(0.3, 0.12, 0.012, PALETTE.dark, { p: [0, 1.29, 0.112] });
      // ícono viento (tres líneas)
      for (let i = 0; i < 3; i++) gb.box(0.16 - i * 0.03, 0.014, 0.004, 0xffffff, { p: [-0.02 + i * 0.01, 1.32 - i * 0.03, 0.119] });
      gb.box(0.07, 0.1, 0.04, 0x2b3331, { p: [0.12, 1.16, 0.12] }); // base palanca
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'rowpost';
    root.add(mesh(geo, this.mats.vcSatin));
    const lb = new GeoBuilder(21);
    lb.cyl(0.018, 0.018, 0.3, 0x9aa5a8, 6, { p: [0, 0.15, 0] });
    lb.add(new THREE.SphereGeometry(0.045, 10, 8), PALETTE.blue, { p: [0, 0.31, 0] });
    const lever = mesh(lb.build(), this.mats.vcSatin);
    const pivot = new THREE.Group(); pivot.position.set(0.12, 1.16, 0.15);
    pivot.add(lever); root.add(pivot);
    let defense = false, ang = -0.35;
    selfAnimate(lever, (_t, dt) => {
      ang = damp(ang, defense ? 2.35 : -0.35, 6, dt);
      pivot.rotation.x = ang;
    });
    return { root, setDefense: (on: boolean) => { defense = on; } };
  }

  /* ==================================================================== VEGETACIÓN */

  /**
   * Geometría de árbol (cacheada por variante). variante % 3: 0 = álamo, 1 = algarrobo, 2 = jarilla.
   * El resto (variante / 3) cambia la forma y el tono. lod=1: copas más simples (instancias lejanas).
   */
  treeGeometry(variant: number, lod = 0): THREE.BufferGeometry {
    variant = Math.max(0, Math.floor(variant));
    const det = lod > 0 ? 0 : 1;
    return this.cachedGeo('tree:' + variant + ':' + lod, () => {
      const kind = variant % 3;
      const r = rng(1000 + variant * 7919);
      const gb = new GeoBuilder(77 + variant);
      if (kind === 0) {
        // Álamo: columnar, tronco claro
        const H = 7.5 + r() * 2.5;
        gb.add(segment(V(0, 0, 0), V(0, H * 0.45, 0), 0.2, 0.12, 7), 0xb8b09e, undefined, { jitter: 0.05 });
        const greens = [0x6f9a35, 0x7ea83c, 0x86b043, 0x5f8b31];
        const base = greens[Math.floor(r() * greens.length)];
        const n = 5;
        for (let i = 0; i < n; i++) {
          const t = i / (n - 1);
          const y = H * (0.3 + t * 0.62);
          const rad = 0.95 * (1 - t * 0.55) + 0.25;
          gb.add(lumpy(1, det, 0.18, variant * 13 + i), base, { p: [(r() - 0.5) * 0.25, y, (r() - 0.5) * 0.25], s: [rad, rad * 1.7, rad] }, { jitter: 0.09 });
        }
      } else if (kind === 1) {
        // Algarrobo: tronco torcido, copa ancha y achatada
        const H = 3.2 + r() * 1.2;
        const top = V((r() - 0.5) * 0.4, H * 0.55, (r() - 0.5) * 0.4);
        gb.add(segment(V(0, 0, 0), top, 0.26, 0.18, 7), 0x5e4330, undefined, { jitter: 0.06 });
        const greens = [0x6b8a3a, 0x748f40, 0x62803a];
        const base = greens[Math.floor(r() * greens.length)];
        const nb = 3 + Math.floor(r() * 2);
        for (let i = 0; i < nb; i++) {
          const a = (i / nb) * Math.PI * 2 + r();
          const end = V(top.x + Math.cos(a) * (1.2 + r() * 0.6), H * (0.78 + r() * 0.12), top.z + Math.sin(a) * (1.2 + r() * 0.6));
          gb.add(segment(top, end, 0.12, 0.06, 5), 0x5e4330);
          gb.add(lumpy(1, det, 0.2, variant * 31 + i), base, { p: [end.x, end.y + 0.25, end.z], s: [1.25 + r() * 0.4, 0.62, 1.25 + r() * 0.4] }, { jitter: 0.1 });
        }
        gb.add(lumpy(1, det, 0.2, variant * 17), base, { p: [top.x, H * 0.95, top.z], s: [1.6, 0.7, 1.6] }, { jitter: 0.1 });
      } else {
        // Jarilla: arbusto de muchas varas con follaje amarillo verdoso y flores amarillas
        const n = 5 + Math.floor(r() * 3);
        const greens = [0x9aac4c, 0x8fa346, 0xa5b553];
        const base = greens[Math.floor(r() * greens.length)];
        for (let i = 0; i < n; i++) {
          const a = r() * Math.PI * 2, d = r() * 0.35;
          const h = 0.7 + r() * 0.6;
          const p = V(Math.cos(a) * d, h, Math.sin(a) * d);
          gb.add(segment(V(p.x * 0.3, 0, p.z * 0.3), p, 0.025, 0.015, 4), 0x6b5236);
          gb.add(lumpy(1, 0, 0.25, variant * 7 + i), base, { p: [p.x, p.y, p.z], s: [0.32 + r() * 0.12, 0.42 + r() * 0.15, 0.32 + r() * 0.12] }, { jitter: 0.12 });
          if (r() < 0.6) gb.box(0.06, 0.06, 0.06, 0xf2c230, { p: [p.x + (r() - 0.5) * 0.3, p.y + 0.25, p.z + (r() - 0.5) * 0.3], r: [r(), r(), r()] });
        }
      }
      return gb.build();
    });
  }

  createTree(variant: number): THREE.Group {
    const root = new THREE.Group(); root.name = 'tree';
    root.add(mesh(this.treeGeometry(variant), this.mats.vc));
    return root;
  }

  /* ==================================================================== CIUDAD */

  createBuilding(w: number, h: number, d: number, variant: number): { root: THREE.Group; setLights(intensity: number): void } {
    const r = rng(500 + variant * 131);
    const walls = [0xeadcc0, 0xdca883, 0xc8d8cf, 0xe8cfa9, 0xc5d5e3, 0xf0e6d6];
    const wallC = walls[Math.abs(variant) % walls.length];
    const trim = new THREE.Color(wallC).multiplyScalar(0.8).getHex();
    const gb = new GeoBuilder(600 + variant);
    const tiles = FACADE_TILES;
    const span = tiles * 3; // metros cubiertos por el atlas
    const offU = (Math.abs(variant) % tiles) / tiles, offV = (Math.floor(Math.abs(variant) / 3) % 3) / tiles;
    const solid = { uv: SOLID_UV.facade };
    const facade = (len: number, x0: number) => ({ project: { axis: 'xy' as const, scale: span }, uvRect: [1, 1, offU + x0 / span + 1.5 / span, offV] as [number, number, number, number] });
    // paredes (4 planos con ventanas proyectadas en metros)
    gb.add(new THREE.PlaneGeometry(w, h).translate(0, h / 2, 0), wallC, { p: [0, 0, d / 2] }, facade(w, 0));
    gb.add(new THREE.PlaneGeometry(w, h).translate(0, h / 2, 0), wallC, { p: [0, 0, -d / 2], r: [0, Math.PI, 0] }, facade(w, 7));
    // los laterales se proyectan antes de rotar: armamos el plano en XY y lo rotamos con una matriz explícita
    for (const side of [1, -1]) {
      const g = new THREE.PlaneGeometry(d, h).translate(0, h / 2, 0);
      const uv = g.attributes.uv as THREE.BufferAttribute, pos = g.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, (pos.getX(i) + 1.5) / span + offU + 0.37, pos.getY(i) / span + offV);
      gb.add(g, new THREE.Color(wallC).multiplyScalar(0.94).getHex(), { p: [side * w / 2, 0, 0], r: [0, side * Math.PI / 2, 0] });
    }
    // zócalo, cornisas y techo
    gb.box(w + 0.06, 0.45, d + 0.06, trim, { p: [0, 0.225, 0] }, solid);
    for (let y = 3; y < h - 0.5; y += 3) gb.box(w + 0.1, 0.1, d + 0.1, trim, { p: [0, y, 0] }, solid);
    gb.box(w + 0.16, 0.14, d + 0.16, trim, { p: [0, h + 0.07, 0] }, solid);
    gb.box(w - 0.2, 0.05, d - 0.2, 0x8c8478, { p: [0, h + 0.14, 0] }, solid);
    const ph = 0.45;
    for (const sz of [-1, 1]) gb.box(w + 0.16, ph, 0.14, trim, { p: [0, h + ph / 2, sz * (d / 2 + 0.01)] }, solid);
    for (const sx of [-1, 1]) gb.box(0.14, ph, d + 0.16, trim, { p: [sx * (w / 2 + 0.01), h + ph / 2, 0] }, solid);
    // puerta con alero
    const doorX = (r() - 0.5) * Math.max(0, w - 2.2);
    gb.box(1.05, 2.1, 0.06, 0x6b4a33, { p: [doorX, 1.05, d / 2 + 0.02] }, solid);
    gb.box(1.2, 0.08, 0.6, 0x4d5b58, { p: [doorX, 2.35, d / 2 + 0.3] }, solid);
    gb.box(0.05, 0.05, 0.05, 0xd8b25a, { p: [doorX + 0.38, 1.05, d / 2 + 0.06] }, solid);
    // equipamiento en la azotea
    if (variant % 2 === 0) {
      // termotanque solar (tubos + tanque)
      const sx = (r() - 0.5) * (w - 2.4), sz = (r() - 0.5) * (d - 2.2);
      const base = new THREE.Matrix4().compose(V(sx, h + 0.75, sz), new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.7, 0, 0)), V(1, 1, 1));
      gb.add(new THREE.BoxGeometry(1.4, 0.05, 1.3), 0x23344d, base, solid);
      gb.cyl(0.24, 0.24, 1.5, 0xe6e9e8, 10, { p: [sx, h + 1.35, sz - 0.5], r: [0, 0, Math.PI / 2] }, solid);
      gb.box(0.05, 0.9, 0.05, 0x9aa5a8, { p: [sx - 0.6, h + 0.6, sz + 0.4] }, solid);
      gb.box(0.05, 0.9, 0.05, 0x9aa5a8, { p: [sx + 0.6, h + 0.6, sz + 0.4] }, solid);
    } else {
      // tanque de agua negro
      const tx = (r() - 0.5) * (w - 1.6), tz = (r() - 0.5) * (d - 1.6);
      gb.cyl(0.55, 0.6, 1.0, 0x2a2d2f, 12, { p: [tx, h + 0.75, tz] }, solid);
      gb.cyl(0.25, 0.3, 0.12, 0x2a2d2f, 12, { p: [tx, h + 1.3, tz] }, solid);
      gb.box(1.3, 0.25, 1.3, 0x8c8478, { p: [tx, h + 0.2, tz] }, solid);
    }
    if (r() < 0.6) gb.box(0.8, 0.5, 0.6, 0xd7dbd9, { p: [(r() - 0.5) * (w - 1.2), h + 0.4, (r() - 0.5) * (d - 1)] }, solid);
    if (r() < 0.5) gb.add(segment(V(w * 0.3, h, -d * 0.3), V(w * 0.3, h + 2.2, -d * 0.3), 0.02, 0.015, 4), 0x555555, undefined, solid);
    const mat = this.mats.building();
    const root = new THREE.Group(); root.name = 'building';
    root.add(mesh(gb.build(), mat));
    return { root, setLights: (i: number) => { mat.emissiveIntensity = Math.max(0, i) * 1.6; } };
  }

  createPowerPole(): THREE.Group {
    const geo = this.cachedGeo('pole', () => {
      const gb = new GeoBuilder(30);
      gb.add(segment(V(0, -0.1, 0), V(0, 7.1, 0), 0.14, 0.1, 7), 0x7a5b3e, undefined, { jitter: 0.04 });
      gb.box(1.7, 0.11, 0.11, 0x6b4f35, { p: [0, 6.65, 0] });
      for (const x of [-0.72, 0, 0.72]) {
        const y = x === 0 ? 7.1 : 6.7;
        gb.cyl(0.05, 0.06, 0.12, 0x8fbfa8, 8, { p: [x, y + 0.06, 0] });
        gb.cyl(0.07, 0.07, 0.02, 0x8fbfa8, 8, { p: [x, y + 0.05, 0] });
      }
      for (const s of [-1, 1]) gb.add(segment(V(0, 6.2, 0), V(s * 0.55, 6.62, 0), 0.025, 0.025, 4), 0x555b5e);
      // brazo de luminaria
      gb.add(segment(V(0, 5.4, 0.08), V(0, 5.75, 1.2), 0.035, 0.03, 6), 0x555b5e);
      gb.add(bevelBox(0.28, 0.1, 0.5, 0.03), 0x4a5356, { p: [0, 5.78, 1.38] });
      gb.box(0.06, 0.3, 0.06, 0x30383b, { p: [0, 2.6, 0.15] }); // caja de medidor
      return gb.build();
    });
    const root = new THREE.Group(); root.name = 'pole';
    root.add(mesh(geo, this.mats.vc));
    const lamp = mesh(new THREE.BoxGeometry(0.22, 0.03, 0.4), this.mats.lamp, false, false);
    lamp.position.set(0, 5.72, 1.38);
    root.add(lamp);
    root.userData.wireAnchors = [V(-0.72, 6.84, 0), V(0, 7.24, 0), V(0.72, 6.84, 0)];
    return root;
  }

  /* ==================================================================== CABLES Y ETIQUETAS */

  createCable(points: THREE.Vector3[], color: number, radius = 0.035): { mesh: THREE.Mesh; curve: THREE.Curve<THREE.Vector3>; setGlow(v: number): void } {
    const pts: THREE.Vector3[] = [];
    const src = points.length >= 2 ? points : [points[0] ?? V(0, 0, 0), (points[0] ?? V(0, 0, 0)).clone().add(V(0, 0.01, 0))];
    for (let i = 0; i < src.length - 1; i++) {
      const a = src[i], b = src[i + 1];
      const len = a.distanceTo(b);
      const n = Math.max(2, Math.ceil(len / 0.3));
      const sag = Math.min(0.9, 0.04 + len * 0.07);
      for (let k = i === 0 ? 0 : 1; k <= n; k++) {
        const t = k / n;
        const p = a.clone().lerp(b, t);
        p.y -= sag * 4 * t * (1 - t);
        p.y = Math.max(p.y, radius + 0.01);
        pts.push(p);
      }
    }
    const curve = new THREE.CatmullRomCurve3(pts, false, 'centripetal', 0.5);
    const segs = THREE.MathUtils.clamp(pts.length * 3, 12, 220);
    const mat = this.mats.surface({ color, emissive: color, emissiveIntensity: 0.06, roughness: 0.45, flatShading: false });
    const m = mesh(new THREE.TubeGeometry(curve, segs, radius, 6, false), mat, true, false);
    m.name = 'cable';
    return { mesh: m, curve, setGlow: (v: number) => { mat.emissiveIntensity = 0.06 + Math.max(0, v) * 2.4; } };
  }

  /**
   * Etiqueta tipo sprite. `scale` = alto en metros (por defecto 0.6). El ancla está en el borde inferior
   * (center = 0.5, 0): posicionala justo arriba del objeto. Siempre visible (depthTest=false, renderOrder alto).
   */
  createLabel(text: string, opts: { bg?: string; scale?: number } = {}): THREE.Sprite {
    const { texture, aspect } = this.textures.label(text, opts.bg);
    const mat = new THREE.SpriteMaterial({ map: texture, transparent: true, depthWrite: false, depthTest: false, fog: false, toneMapped: false });
    const s = new THREE.Sprite(mat);
    const h = opts.scale ?? 0.6;
    s.scale.set(h * aspect, h, 1);
    s.center.set(0.5, 0);
    s.renderOrder = 50;
    s.name = 'label:' + text;
    return s;
  }

  /* ==================================================================== EXTRAS (sala de equipos) */

  /** Platea de hormigón w × d (alto 0.16), origen en el piso. */
  createSlab(w: number, d: number): THREE.Mesh {
    const gb = new GeoBuilder(40);
    gb.box(w, 0.16, d, 0xd8d4cc, { p: [0, 0.08, 0] }, { project: { axis: 'xz', scale: 3 } });
    const m = mesh(gb.build(), this.mats.concrete, false, true);
    m.name = 'slab';
    return m;
  }

  /** Pared revocada con zócalo verde oscuro y coronamiento. Frente hacia +Z, apoyada en z ∈ [-t, 0]. */
  createWall(w: number, h: number, t = 0.25): THREE.Mesh {
    const gb = new GeoBuilder(41);
    gb.box(w, h, t, 0xece5d6, { p: [0, h / 2, -t / 2] });
    gb.box(w + 0.02, 0.5, t + 0.04, PALETTE.dark, { p: [0, 0.25, -t / 2] });
    gb.box(w + 0.1, 0.08, t + 0.1, 0xcfc6b4, { p: [0, h + 0.04, -t / 2] });
    gb.box(w + 0.02, 0.1, t + 0.02, PALETTE.leaf, { p: [0, 0.55, -t / 2] });
    const m = mesh(gb.build(), this.mats.vc);
    m.name = 'wall';
    return m;
  }

  /** Alero de chapa sobre postes, w × d, a altura h. */
  createCanopy(w: number, d: number, h = 3.0): THREE.Group {
    const gb = new GeoBuilder(42);
    const slope = 0.08;
    const roof = new THREE.Matrix4().compose(V(0, h, 0), new THREE.Quaternion().setFromEuler(new THREE.Euler(slope, 0, 0)), V(1, 1, 1));
    gb.add(new THREE.BoxGeometry(w, 0.05, d), 0xdfe3e4, roof, { project: { axis: 'xz', scale: 1.2 } });
    for (const x of [-w / 2 + 0.15, w / 2 - 0.15]) {
      gb.box(0.1, h, 0.1, 0x3d5a52, { p: [x, h / 2, d / 2 - 0.15] }, { uv: [0.031, 0.5] });
      gb.box(0.1, 0.1, d, 0x3d5a52, { p: [x, h - 0.08, 0] }, { uv: [0.031, 0.5] });
    }
    gb.box(w, 0.12, 0.08, PALETTE.sun, { p: [0, h - 0.11 - slope * d / 2, d / 2 - 0.02] }, { uv: [0.031, 0.5] });
    const g = new THREE.Group(); g.name = 'canopy';
    g.add(mesh(gb.build(), this.mats.sheet));
    return g;
  }

  dispose(): void {
    this.geoCache.forEach((g) => g.dispose());
    this.geoCache.clear();
    this.mats.dispose();
    this.textures.dispose();
  }
}

export type { SurfaceMaterial };
