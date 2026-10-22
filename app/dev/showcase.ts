/**
 * Escena de muestra de los assets (dev). Parámetros por URL:
 *   q=low|medium|high  hour=10.5  zonda=0..1  clouds=0..1  view=overview|game|closeup|equip|city|lineup
 *   defense=1 (fila 2 en defensa)  dirty=1 (fila 1 sucia)  glow=0..1
 * Expone window.__stats = { calls, triangles, mainCalls, ... } y window.__ready = true al terminar.
 */
import * as THREE from 'three';
import { ModelFactory, Environment, RendererFacade, DEFAULT_SETTINGS } from '../src/world/assets';
import type { QualityLevel, WorkerRig } from '../src/contracts';

const P = new URLSearchParams(location.search);
const quality = (P.get('q') as QualityLevel) || 'high';
const hour = parseFloat(P.get('hour') || '10.5');
const zonda = parseFloat(P.get('zonda') || '0');
const clouds = parseFloat(P.get('clouds') || '0');
const view = P.get('view') || 'overview';
const glow = parseFloat(P.get('glow') || (hour > 20 || hour < 6.5 ? '1' : '0.15'));

const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);
/** typical=1: escena de juego típica (sin extras de muestra: 1 personaje, sin bomba/cajones/árboles sueltos). */
const typical = P.get('typical') === '1';

async function main(): Promise<void> {
  const app = document.getElementById('app') as HTMLElement;
  let canvas: HTMLCanvasElement | undefined, context: WebGLRenderingContext | undefined;
  if (P.get('gl') === '1') { // forzar WebGL1
    canvas = document.createElement('canvas'); app.appendChild(canvas);
    context = canvas.getContext('webgl', { antialias: true, preserveDrawingBuffer: true }) as WebGLRenderingContext;
  }
  const rf = new RendererFacade({ container: app, canvas, context, settings: DEFAULT_SETTINGS[quality], preserveDrawingBuffer: true });
  rf.resize(app.clientWidth, app.clientHeight);
  const factory = new ModelFactory({ quality, skinning: rf.isWebGL2 });
  await factory.textures.loadFonts('../public/fonts/');
  const env = new Environment(factory, { quality });
  const scene = env.scene;
  const add = (o: THREE.Object3D, x: number, y: number, z: number, ry = 0) => { o.position.set(x, y, z); o.rotation.y = ry; scene.add(o); return o; };

  /* ---------------- campo solar: 2 filas × 8 */
  const rowZ = [-3.4, -7.0];
  const panels: ReturnType<ModelFactory['createPanel']>[] = [];
  rowZ.forEach((z, row) => {
    for (let i = 0; i < 8; i++) {
      const m = factory.createMount();
      add(m.root, -19 + i * 2.25, 0, z);
      if (row === 1 && P.get('defense') === '1') m.tilt.rotation.x = 0;
      const filled = !(row === 1 && i >= 6);
      m.ghost.visible = !filled;
      if (filled) {
        const p = factory.createPanel();
        m.tilt.add(p.root);
        if (row === 0 && P.get('dirty') === '1') p.setDirty(true);
        if (row === 0 && i === 2) p.setDirty(true);
        p.setGlow(glow * 0.6);
        panels.push(p);
      }
    }
    const post = factory.createRowPost();
    add(post.root, -21.2, 0, z, Math.PI / 2);
    if (row === 1 && P.get('defense') === '1') post.setDefense(true);
    const lb = factory.createLabel('FILA ' + (row + 1), { scale: 0.55 });
    add(lb, -21.2, 1.75, z);
  });
  add(factory.createLabel('CAMPO SOLAR', { scale: 0.8 }), -11, 2.6, -5.2);

  /* ---------------- sala de equipos */
  add(factory.createSlab(11, 6), 7, 0, -4.2);
  add(factory.createWall(11, 3.1), 7, 0.16, -6.9);
  add(factory.createCanopy(11.4, 2.2, 3.4), 7, 0.16, -6.1);
  const inv = factory.createInverter(); add(inv.root, 5.2, 0.16, -6.9);
  inv.setScreen?.(glow > 0.5 ? '4,8 kW' : 'STANDBY', glow > 0.5 ? '#5fe3f5' : '#8fa7a1');
  const prot = factory.createProtectionBox(); add(prot.root, 3.3, 0.16, -6.9);
  const sw = factory.createSwitchboard(); add(sw.root, 11, 0.16, -6.9);
  const bats = [0, 1, 2, 3].map((i) => { const b = factory.createBattery(); add(b.root, 6.5 + i * 1.15, 0.16, -6.3); b.setCharge([1, 0.7, 0.4, 0.12][i]); return b; });
  const jb = factory.createJunctionBox(); add(jb.root, 0.2, 0, -5.2);
  const con = factory.createConsole(); add(con.root, 7, 0.16, -2.2);
  con.setActive(glow > 0.5);
  add(factory.createLabel('SALA DE EQUIPOS', { scale: 0.7 }), 7, 3.75, -6.4);
  add(factory.createLabel('ACTIVAR PLANTA', { bg: 'rgba(185,120,26,0.94)', scale: 0.6 }), 7, 1.75, -2.2);

  /* ---------------- cables */
  const cab = (pts: THREE.Vector3[], c: number) => { const k = factory.createCable(pts, c); scene.add(k.mesh); k.setGlow(glow); return k; };
  const jT = jb.terminal.clone().add(jb.root.position);
  const iT = inv.terminal.clone().add(inv.root.position);
  cab([jT, V(1, 0.05, -4.8), V(4.6, 0.2, -5.2), iT], 0xf28c28);
  cab([iT.clone().add(V(-0.1, 0, 0)), V(5.6, 0.2, -5.6), bats[0].terminal.clone().add(bats[0].root.position)], 0x2f7be0);
  cab([iT.clone().add(V(0.1, 0, 0)), V(8, 0.2, -5.2), V(10.6, 0.2, -5.6), sw.terminal.clone().add(sw.root.position)], 0x8b5cf6);
  for (const z of rowZ) cab([V(-1.2, 0.85, z + 0.2), V(-0.6, 0.04, z + 0.4), V(-0.1, 0.04, -4.9), jT.clone().add(V(-0.12, 0, 0))], 0xf28c28);

  /* ---------------- depósito y pallet */
  const pal = factory.createPallet(8); add(pal.root, -4, 0, 3.2, 0.1);
  add(factory.createLabel('PANELES', { scale: 0.5 }), -4, 1.25, 3.2);
  if (!typical) (['battery', 'protection', 'kit'] as const).forEach((k, i) => add(factory.createCrate(k), 13.5 + i * 1.3, 0, 1.6, (i - 1) * 0.15));
  if (!typical) add(factory.createCrate('panel'), 14.8, 0, 3.6, 0.2);
  add(factory.createLabel('DEPÓSITO', { scale: 0.6 }), 14.8, 1.6, 1.6);

  /* ---------------- bomba */
  if (!typical) { const pump = factory.createPump(); add(pump.root, -9, 0, 5.5, -0.4); pump.setRunning(glow < 0.5); }

  /* ---------------- árboles sueltos cerca */
  if (!typical) [[-24, 4, 0], [-25, -12, 1], [19, 6, 1], [22, -4, 0], [-14, 9, 2], [10, 7, 2], [-2, 10, 5], [24, 3, 3], [-27, -2, 3]].forEach(([x, z, v]) => add(factory.createTree(v), x, 0, z, x * 0.3));

  /* ---------------- ciudad */
  const city = new THREE.Group(); city.position.set(22, 0, -22); scene.add(city);
  const lights: ((i: number) => void)[] = [];
  [[0, 0, 4, 9, 4], [5, 1, 3.6, 6, 3.4], [9.5, -1, 4.2, 12, 4], [14, 0.5, 3.4, 6.5, 3.6], [2, -6, 4.4, 7.5, 3.6],
    [7, -6.5, 3.6, 15, 3.6], [12, -6, 4, 7, 4], [-4, -3, 3.4, 5.5, 3.4], [17, -4, 3.4, 9, 3.4], [-3, -9, 3.6, 6, 3.6]]
    .forEach(([x, z, w, h, d], i) => { const b = factory.createBuilding(w, h, d, i); b.root.position.set(x, 0, z); city.add(b.root); lights.push(b.setLights); });
  add(factory.createLabel('CIUDAD', { scale: 1.1 }), 28, 16.5, -24);
  // postes y línea
  const poles: THREE.Vector3[] = [];
  [[13, -8.5], [15.5, -13.5], [18.2, -18.5]].forEach(([x, z], i) => { const p = factory.createPowerPole(); add(p, x, 0, z, -0.5 + i * 0.05); poles.push(V(x, 6.84, z)); });
  const swT = sw.root.position.clone().add(V(0.2, 2.2, 0.1));
  cab([swT, ...poles, V(20.5, 6, -21)], 0x2a2a2a).setGlow(0);

  /* ---------------- personajes */
  type W = { rig: WorkerRig; speed: number; pose: 'idle' | 'carry' | 'cable' | 'tool' };
  const workers: W[] = [];
  const mk = (x: number, z: number, ry: number, speed: number, pose: W['pose'], colors?: { helmet?: number; vest?: number }) => {
    const rig = factory.createWorker(colors); add(rig.root, x, 0, z, ry); workers.push({ rig, speed, pose }); return rig;
  };
  const w1 = mk(1.5, 1.6, 0.5, 1, 'idle');
  void w1;
  const w2 = mk(3.6, 0.6, -0.9, 0.6, 'carry', { helmet: 0xffffff, vest: 0xd6f25a });
  w2.carryAnchor.add(factory.createCrate('battery'));
  const w3 = mk(-6.1, -1.9, Math.PI, 0, 'tool', { helmet: 0x2f7be0 });
  const meter = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.15, 0.04), factory.mats.surface({ color: 0xffb82e }));
  meter.position.set(0, 0, 0.03); w3.handAnchor.add(meter);
  mk(5.6, -1.6, 0.3, 0, 'idle', { vest: 0x3fa34d });
  const w5 = mk(-0.9, -1.4, -2.3, 0.4, 'cable');
  void w5;
  if (typical) workers.splice(1).forEach((w) => scene.remove(w.rig.root));

  const anim = (frames: number) => {
    for (let f = 0; f < frames; f++) for (const w of workers) w.rig.animate(1 / 30, w.speed, w.pose);
  };
  anim(37);

  /* ---------------- cámara */
  const cam = rf.camera;
  const views: Record<string, [THREE.Vector3, THREE.Vector3, number?]> = {
    overview: [V(16, 21, 24), V(-1, 0, -6), 45],
    game: [V(2.2, 7.2, 11.5), V(0.5, 0.8, -2.5), 50],
    closeup: [V(3.4, 2.1, 5.4), V(1.2, 1.15, 0.2), 42],
    equip: [V(6.6, 3.0, 2.6), V(7.6, 1.3, -6), 50],
    city: [V(4, 9, 2), V(26, 5, -26), 50],
    lineup: [V(-6, 3.0, 4.5), V(-6, 1.0, -3.4), 48],
    field: [V(-2, 4.2, 6.5), V(-10, 0.5, -5), 50],
  };
  const [pos, look, fov] = views[view] || views.overview;
  cam.position.copy(pos); cam.fov = fov ?? 50; cam.updateProjectionMatrix(); cam.lookAt(look);

  const follow = view === 'city' ? V(14, 0, -14) : V(look.x, 0, look.z);
  let frame = 0;
  const loop = () => {
    env.update(1 / 30, hour, { zonda, clouds, follow });
    const nf = env.nightFactor();
    lights.forEach((l) => l(nf));
    anim(1);
    rf.render(scene);
    frame++;
    if (frame === 3) {
      // estadísticas: todas las pasadas (sombra + principal + post) y sólo la principal
      const r = rf.renderer;
      r.info.reset();
      r.shadowMap.autoUpdate = false;
      r.render(scene, cam);
      const main = { calls: r.info.render.calls, tris: r.info.render.triangles };
      r.shadowMap.autoUpdate = true;
      rf.render(scene);
      (window as unknown as { __stats: unknown }).__stats = {
        quality, view, totalCalls: rf.stats.calls, totalTriangles: rf.stats.triangles,
        mainCalls: main.calls, mainTriangles: main.tris, webgl2: rf.isWebGL2, geometries: r.info.memory.geometries, textures: r.info.memory.textures,
      };
      (window as unknown as { __ready: boolean }).__ready = true;
    }
    if (frame < 4 || P.get('live') === '1') requestAnimationFrame(loop);
  };
  loop();
  window.addEventListener('resize', () => rf.resize(app.clientWidth, app.clientHeight));
}

main().catch((e) => { (window as unknown as { __error: string }).__error = String(e && (e as Error).stack || e); console.error(e); });
