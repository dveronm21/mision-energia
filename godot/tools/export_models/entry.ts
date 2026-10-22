/**
 * Exportador de modelos (corre en el navegador headless, ver export.mjs).
 *
 * Construye cada pieza con el ModelFactory de la versión web (app/src/world/assets) y la baja a .glb
 * binario con texturas embebidas. Ajustes para Godot:
 *  - Normales planas (el `flatShading` de three es un flag de material que glTF no tiene).
 *  - Colores por vértice en espacio lineal (COLOR_0, como pide glTF).
 *  - Partes con estado propio en nodos con nombre (tilt, ghost, button, rotor, lever_pivot...).
 *  - Personaje como jerarquía rígida (hips, torso, head, arm_l/forearm_l, leg_l/shin_l, hand_r,
 *    carry_anchor) con casco y chaleco en mallas/materiales aparte.
 *  - Edificios con la fachada (ventanas emisivas) en un material aparte.
 *  - Ambiente: terreno, montañas y mallas de vegetación + un JSON con las instancias.
 */
import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { ModelFactory, PALETTE } from '../../../app/src/world/assets/ModelFactory';
import { Environment } from '../../../app/src/world/assets/Environment';

type Out = Record<string, string>; // nombre de archivo → base64 (o texto para .json)

const exporter = new GLTFExporter();

function b64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** Normales planas por triángulo (geometría no indexada). */
function flatNormals(geo: THREE.BufferGeometry): THREE.BufferGeometry {
  const g = geo.index ? geo.toNonIndexed() : geo.clone();
  const p = g.attributes.position as THREE.BufferAttribute;
  const n = new Float32Array(p.count * 3);
  const a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3();
  for (let i = 0; i + 2 < p.count; i += 3) {
    a.fromBufferAttribute(p, i); b.fromBufferAttribute(p, i + 1); c.fromBufferAttribute(p, i + 2);
    const nn = new THREE.Vector3().subVectors(c, b).cross(new THREE.Vector3().subVectors(a, b));
    if (nn.lengthSq() < 1e-20) nn.set(0, 1, 0); else nn.normalize();
    for (let k = 0; k < 3; k++) { n[(i + k) * 3] = nn.x; n[(i + k) * 3 + 1] = nn.y; n[(i + k) * 3 + 2] = nn.z; }
  }
  g.setAttribute('normal', new THREE.BufferAttribute(n, 3));
  return g;
}

/**
 * El renderer GL Compatibility de Godot interpreta COLOR como sRGB (igual que albedo_color), y además los
 * guarda en 8 bits: pasamos COLOR_0 a sRGB (el import script marca vertex_color_is_srgb, que deja
 * Forward+ consistente). Así no hay bandas en los oscuros.
 */
function toSrgbColors(g: THREE.BufferGeometry): void {
  const c = g.attributes.color as THREE.BufferAttribute | undefined;
  if (!c) return;
  const tmp = new THREE.Color();
  for (let i = 0; i < c.count; i++) {
    tmp.setRGB(c.getX(i), c.getY(i), c.getZ(i)).convertLinearToSRGB();
    c.setXYZ(i, Math.min(1, tmp.r), Math.min(1, tmp.g), Math.min(1, tmp.b));
  }
  c.needsUpdate = true;
}

/** Prepara un árbol de objetos para exportar: normales planas, nombres de materiales, sin sombras de contacto. */
function prepare(root: THREE.Object3D, matNames: Map<THREE.Material, string>): THREE.Object3D {
  const kill: THREE.Object3D[] = [];
  root.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh) return;
    const mat = m.material as THREE.MeshStandardMaterial;
    if ((mat as THREE.MeshBasicMaterial).alphaMap && (mat as THREE.MeshBasicMaterial).color.getHex() === 0) { kill.push(o); return; }
    m.geometry = mat.flatShading ? flatNormals(m.geometry) : m.geometry.clone();
    toSrgbColors(m.geometry);
    const nm = matNames.get(mat);
    if (nm && !mat.name) mat.name = nm;
  });
  kill.forEach((o) => o.parent?.remove(o));
  return root;
}

async function glb(obj: THREE.Object3D): Promise<string> {
  obj.updateMatrixWorld(true);
  const res = await exporter.parseAsync(obj, { binary: true, onlyVisible: false, maxTextureSize: 1024 });
  return b64(res as ArrayBuffer);
}

function canvasPng(tex: THREE.Texture): string {
  const img = tex.image as HTMLCanvasElement;
  return img.toDataURL('image/png').split(',')[1];
}

function group(name: string, ...children: THREE.Object3D[]): THREE.Group {
  const g = new THREE.Group(); g.name = name; children.forEach((c) => g.add(c)); return g;
}

function nameFirstMesh(root: THREE.Object3D, name: string): void {
  const m = root.children.find((c) => (c as THREE.Mesh).isMesh);
  if (m) m.name = name;
}

/** Separa de una malla los triángulos cuyo color de vértice coincide con `key` (lineal). */
function splitByColor(mesh: THREE.Mesh, key: THREE.Color): THREE.BufferGeometry | null {
  const g = mesh.geometry;
  const col = g.attributes.color as THREE.BufferAttribute;
  const keepIdx: number[] = [], takeIdx: number[] = [];
  for (let i = 0; i + 2 < col.count; i += 3) {
    const hit = Math.abs(col.getX(i) - key.r) < 0.01 && Math.abs(col.getY(i) - key.g) < 0.01 && Math.abs(col.getZ(i) - key.b) < 0.01;
    (hit ? takeIdx : keepIdx).push(i);
  }
  if (takeIdx.length === 0) return null;
  const pick = (tris: number[], withColor: boolean) => {
    const out = new THREE.BufferGeometry();
    for (const name of ['position', 'normal', 'uv', 'color']) {
      if (name === 'color' && !withColor) continue;
      const a = g.attributes[name] as THREE.BufferAttribute;
      if (!a) continue;
      const arr = new Float32Array(tris.length * 3 * a.itemSize);
      tris.forEach((t, j) => { for (let k = 0; k < 3 * a.itemSize; k++) arr[j * 3 * a.itemSize + k] = (a.array as Float32Array)[t * a.itemSize + k]; });
      out.setAttribute(name, new THREE.BufferAttribute(arr, a.itemSize));
    }
    return out;
  };
  mesh.geometry = pick(keepIdx, true);
  return pick(takeIdx, false);
}

/* ======================================================================= personaje */

const BONE_NAMES: Record<string, string> = {
  root: 'root', hips: 'hips', spine: 'torso', head: 'head',
  shL: 'arm_l', elL: 'forearm_l', shR: 'arm_r', elR: 'forearm_r',
  thL: 'leg_l', knL: 'shin_l', thR: 'leg_r', knR: 'shin_r',
};

function buildWorker(f: ModelFactory): THREE.Object3D {
  const KEY_HELMET = 0xff00ff, KEY_VEST = 0x00ffff;
  const rig = f.createWorker({ helmet: KEY_HELMET, vest: KEY_VEST });
  // pose de enlace limpia
  rig.root.traverse((o) => { if ((o as THREE.Bone).isBone) o.rotation.set(0, 0, 0); });
  const hips = rig.root.getObjectByName('hips');
  if (hips) hips.position.y = 0.88;
  const body = f.mats.surface({ vertexColors: true, roughness: 0.7, flatShading: false }); body.name = 'worker_body';
  const helmet = f.mats.surface({ color: PALETTE.sun, roughness: 0.4, flatShading: false }); helmet.name = 'helmet';
  const vest = f.mats.surface({ color: PALETTE.orange, roughness: 0.75, flatShading: false }); vest.name = 'vest';
  const kh = new THREE.Color(KEY_HELMET), kv = new THREE.Color(KEY_VEST);
  const meshes: THREE.Mesh[] = [];
  rig.root.traverse((o) => { if ((o as THREE.Mesh).isMesh && (o as THREE.Mesh).material !== f.mats.contactShadow) meshes.push(o as THREE.Mesh); });
  for (const m of meshes) {
    const bone = m.parent as THREE.Object3D;
    const bn = BONE_NAMES[bone.name] ?? bone.name;
    m.material = body;
    m.name = bn + '_mesh';
    m.castShadow = true;
    const h = splitByColor(m, kh);
    if (h) { const hm = new THREE.Mesh(h, helmet); hm.name = 'helmet'; bone.add(hm); }
    const v = splitByColor(m, kv);
    if (v) { const vm = new THREE.Mesh(v, vest); vm.name = 'vest'; bone.add(vm); }
  }
  rig.root.traverse((o) => { if ((o as THREE.Bone).isBone && BONE_NAMES[o.name]) o.name = BONE_NAMES[o.name]; });
  rig.handAnchor.name = 'hand_r';
  rig.carryAnchor.name = 'carry_anchor';
  // sacar la sombra de contacto (Godot usa su propio quad)
  const kill: THREE.Object3D[] = [];
  rig.root.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh && m.material === f.mats.contactShadow) kill.push(o); });
  kill.forEach((o) => o.parent?.remove(o));
  // Los Bone de three se exportan como nodos comunes: los reemplazamos por Group para evitar "joints" huérfanos.
  const convert = (o: THREE.Object3D): THREE.Object3D => {
    const kids = [...o.children];
    kids.forEach((k) => o.remove(k));
    let n: THREE.Object3D = o;
    if ((o as THREE.Bone).isBone) {
      n = new THREE.Group(); n.name = o.name; n.position.copy(o.position); n.quaternion.copy(o.quaternion); n.scale.copy(o.scale);
    }
    for (const k of kids) n.add(convert(k));
    return n;
  };
  const out = convert(rig.root);
  out.name = 'worker';
  return out;
}

/* ======================================================================= edificios */

function buildBuilding(f: ModelFactory, w: number, h: number, d: number, variant: number): THREE.Object3D {
  const b = f.createBuilding(w, h, d, variant);
  const mesh = b.root.children[0] as THREE.Mesh;
  const src = mesh.material as THREE.MeshStandardMaterial;
  // Las 4 paredes son los primeros 4 planos (6 vértices c/u): ahí están las ventanas.
  const g = mesh.geometry;
  const facade = new THREE.BufferGeometry(), rest = new THREE.BufferGeometry();
  const N = 24;
  for (const name of ['position', 'normal', 'uv', 'color']) {
    const a = g.attributes[name] as THREE.BufferAttribute;
    const arr = a.array as Float32Array;
    facade.setAttribute(name, new THREE.BufferAttribute(arr.slice(0, N * a.itemSize), a.itemSize));
    rest.setAttribute(name, new THREE.BufferAttribute(arr.slice(N * a.itemSize), a.itemSize));
  }
  const winMat = src.clone(); winMat.name = 'windows';
  winMat.emissive.set(0xffd9a0); winMat.emissiveIntensity = 1; // el mapa emisivo sólo tiene las ventanas
  const bodyMat = f.mats.surface({ vertexColors: true, map: src.map, roughness: 0.9 }); bodyMat.name = 'building_body';
  const fm = new THREE.Mesh(facade, winMat); fm.name = 'facade';
  const bm = new THREE.Mesh(rest, bodyMat); bm.name = 'body';
  return group('building', bm, fm);
}

/* ======================================================================= ambiente */

function buildEnvironment(f: ModelFactory, out: Out, pending: Promise<void>[]): void {
  const env = new Environment(f, { quality: 'high' });
  const inst: Record<string, { count: number; xf: number[]; col: number[] }> = {};
  for (const o of [...env.scene.children]) {
    const im = o as THREE.InstancedMesh;
    if (im.isInstancedMesh) {
      const m = new THREE.Matrix4(), c = new THREE.Color();
      const xf: number[] = [], col: number[] = [];
      for (let i = 0; i < im.count; i++) {
        im.getMatrixAt(i, m);
        const e = m.elements; // column-major: basis X (0,1,2), Y (4,5,6), Z (8,9,10), origin (12,13,14)
        xf.push(+e[0].toFixed(5), +e[1].toFixed(5), +e[2].toFixed(5), +e[4].toFixed(5), +e[5].toFixed(5), +e[6].toFixed(5),
          +e[8].toFixed(5), +e[9].toFixed(5), +e[10].toFixed(5), +e[12].toFixed(3), +e[13].toFixed(3), +e[14].toFixed(3));
        if (im.instanceColor) { im.getColorAt(i, c); c.convertLinearToSRGB(); col.push(+c.r.toFixed(4), +c.g.toFixed(4), +c.b.toFixed(4)); }
      }
      inst[im.name] = { count: im.count, xf, col };
      const single = new THREE.Mesh(im.geometry, im.material); single.name = im.name;
      pending.push(glb(prepare(group('env_' + im.name, single), new Map([[f.mats.vc, 'vc']]))).then((s) => { out['env_' + im.name + '.glb'] = s; }));
    }
  }
  out['env_instances.json'] = JSON.stringify(inst);
  env.terrain.name = 'terrain';
  (env.terrain.material as THREE.Material).name = 'terrain';
  pending.push(glb(prepare(group('env_terrain', env.terrain), new Map())).then((s) => { out['env_terrain.glb'] = s; }));
  env.mountains.name = 'mountains';
  pending.push(glb(prepare(group('env_mountains', env.mountains.clone()), new Map())).then((s) => { out['env_mountains.glb'] = s; }));
}

/* ======================================================================= principal */

export async function exportAll(fontBase: string): Promise<Out> {
  const f = new ModelFactory({ quality: 'high', skinning: false });
  await f.textures.loadFonts(fontBase);
  const names = new Map<THREE.Material, string>([
    [f.mats.vc, 'vc'], [f.mats.vcSatin, 'vc_satin'], [f.mats.vcSmooth, 'vc_smooth'], [f.mats.glow, 'glow'],
    [f.mats.ghost, 'ghost'], [f.mats.crate, 'crate'], [f.mats.concrete, 'concrete'], [f.mats.sheet, 'sheet'], [f.mats.lamp, 'lamp'],
  ]);
  const out: Out = {};
  const jobs: [string, () => THREE.Object3D][] = [];
  const add = (file: string, make: () => THREE.Object3D) => jobs.push([file, make]);

  add('panel', () => {
    const p = f.createPanel(); nameFirstMesh(p.root, 'panel_mesh');
    const mat = (p.root.children[0] as THREE.Mesh).material as THREE.MeshStandardMaterial;
    mat.name = 'panel'; mat.emissiveMap = null; mat.emissive.set(0x000000);
    return p.root;
  });
  add('mount', () => {
    const m = f.createMount();
    m.root.children[0].name = 'base';
    m.tilt.children[0].name = 'frame';
    return m.root;
  });
  add('inverter', () => {
    const inv = f.createInverter();
    nameFirstMesh(inv.root, 'body');
    inv.setScreen?.('', '#000000');
    const plate = inv.root.children[1] as THREE.Mesh; plate.name = 'face';
    const fm = plate.material as THREE.MeshStandardMaterial; fm.name = 'inverter_face'; fm.emissiveMap = null; fm.emissive.set(0);
    inv.root.add(Object.assign(new THREE.Object3D(), { name: 'terminal' }).translateX(inv.terminal.x).translateY(inv.terminal.y).translateZ(inv.terminal.z));
    return inv.root;
  });
  add('battery', () => {
    const b = f.createBattery();
    nameFirstMesh(b.root, 'body');
    b.root.remove(b.root.children[1]); // segmentos de carga: los arma Godot (BatteryVisual)
    return b.root;
  });
  add('protection', () => { const p = f.createProtectionBox(); nameFirstMesh(p.root, 'body'); return p.root; });
  add('switchboard', () => {
    const s = f.createSwitchboard(); nameFirstMesh(s.root, 'body');
    s.root.children[1].name = 'pilots';
    return s.root;
  });
  add('junction_box', () => { const j = f.createJunctionBox(); nameFirstMesh(j.root, 'body'); return j.root; });
  add('console', () => {
    const c = f.createConsole(); nameFirstMesh(c.root, 'body');
    const pivot = c.root.children[1]; pivot.name = 'button_pivot';
    const btn = pivot.children[0] as THREE.Mesh; btn.name = 'button';
    (btn.material as THREE.Material).name = 'console_button';
    btn.onBeforeRender = () => { /* sin animación */ };
    return c.root;
  });
  add('pump', () => {
    const p = f.createPump(); nameFirstMesh(p.root, 'body');
    const [, rotor, water, stream] = p.root.children as THREE.Mesh[];
    rotor.name = 'rotor'; water.name = 'water'; stream.name = 'stream';
    (water.material as THREE.Material).name = 'water'; (stream.material as THREE.Material).name = 'water_stream';
    rotor.onBeforeRender = () => { /* */ };
    water.position.y = 0.42;
    return p.root;
  });
  for (const k of ['battery', 'protection', 'kit', 'panel'] as const) add('crate_' + k, () => { const c = f.createCrate(k); nameFirstMesh(c, 'body'); return c; });
  add('pallet', () => {
    const p = f.createPallet(0); nameFirstMesh(p.root, 'body');
    p.root.children.filter((c) => (c as THREE.InstancedMesh).isInstancedMesh).forEach((c) => p.root.remove(c));
    return p.root;
  });
  add('row_post', () => {
    const r = f.createRowPost(); nameFirstMesh(r.root, 'body');
    const pivot = r.root.children[1]; pivot.name = 'lever_pivot'; pivot.rotation.x = 0;
    pivot.children[0].name = 'lever';
    pivot.children[0].onBeforeRender = () => { /* */ };
    return r.root;
  });
  const treeNames = ['tree_alamo', 'tree_algarrobo', 'tree_jarilla'];
  treeNames.forEach((n, v) => add(n, () => { const t = f.createTree(v); nameFirstMesh(t, 'body'); return t; }));
  const BUILDINGS: [number, number, number, number][] = [[4, 9, 4, 0], [3.6, 6, 3.4, 1], [4.2, 12, 4, 2], [3.4, 6.5, 3.6, 3]];
  BUILDINGS.forEach(([w, h, d, v], i) => add('building_' + i, () => buildBuilding(f, w, h, d, v)));
  add('power_pole', () => {
    const p = f.createPowerPole(); nameFirstMesh(p, 'body');
    p.children[1].name = 'lamp';
    return p;
  });
  add('slab', () => group('slab', f.createSlab(11, 6)));
  add('wall', () => group('wall', f.createWall(11, 3.1)));
  add('canopy', () => { const c = f.createCanopy(11.4, 2.2, 3.4); nameFirstMesh(c, 'body'); return c; });
  add('worker', () => buildWorker(f));

  for (const [file, make] of jobs) {
    const obj = prepare(make(), names);
    obj.name = file;
    out[file + '.glb'] = await glb(obj);
  }

  // Texturas sueltas para cambiar en tiempo de ejecución.
  out['tex:panel_clean.png'] = canvasPng(f.textures.solarPanel(false));
  out['tex:panel_dirty.png'] = canvasPng(f.textures.solarPanel(true));
  out['tex:dust.png'] = canvasPng(f.textures.dustSprite());
  out['tex:facade_emissive.png'] = canvasPng(f.textures.facade('emissive'));

  const pending: Promise<void>[] = [];
  buildEnvironment(f, out, pending);
  await Promise.all(pending);
  return out;
}

(window as unknown as { __exportAll: typeof exportAll }).__exportAll = exportAll;
