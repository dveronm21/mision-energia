/**
 * Environment (IEnvironment): cielo con shader de gradiente (día/atardecer/noche, sol, luna, nubes),
 * luz direccional que sigue la hora (con sombras centradas en `follow`), hemisférica, terreno low-poly
 * de precordillera sanjuanina con caminos, vegetación y piedras instanciadas, montañas de fondo,
 * estrellas y viento Zonda (niebla ocre + partículas de polvo).
 *
 * Orientación: norte = +Z (los paneles miran a +Z), el sol sale por el este (-X) y se pone por el oeste (+X).
 */
import * as THREE from 'three';
import type { IEnvironment, QualityLevel } from '../../contracts';
import { GeoBuilder, fbm2, lumpy, noise2, rng, segment } from './Geo';
import type { ModelFactory } from './ModelFactory';

export interface EnvironmentOptions {
  seed?: number;
  /** Centro de la zona de juego (plana). */
  center?: [number, number];
  /** Radio plano alrededor del centro (sin relieve). */
  flatRadius?: number;
  /** Caminos de tierra como polilíneas [x, z]. */
  paths?: { points: [number, number][]; width?: number }[];
  /** Zonas sin vegetación decorativa (además de los caminos). */
  clearings?: { x: number; z: number; r: number }[];
  quality?: QualityLevel;
}

const DEFAULT_PATHS: { points: [number, number][]; width?: number }[] = [
  { points: [[-24, -0.5], [-8, -0.8], [4, -0.3], [14, -0.6], [20, -1.5]], width: 3.4 },
  { points: [[14, -0.6], [16, -8], [19, -15], [23, -20], [27, -22]], width: 3.0 },
  { points: [[1.5, 12], [1, 5], [1, -0.5]], width: 2.6 },
];

const SKY = {
  dayTop: new THREE.Color(0x3d8fe0), dayHorizon: new THREE.Color(0xcfe8f2),
  duskTop: new THREE.Color(0x3a4f8c), duskHorizon: new THREE.Color(0xffbe7d),
  nightTop: new THREE.Color(0x040a1c), nightHorizon: new THREE.Color(0x1a2a4c),
  zonda: new THREE.Color(0xc79a62), zondaDark: new THREE.Color(0x6a4a30),
};

const skyVert = /* glsl */`
varying vec3 vDir;
void main(){
  vDir = position;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const skyFrag = /* glsl */`
uniform vec3 uTop; uniform vec3 uHorizon; uniform vec3 uGround;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform vec3 uMoonDir;
uniform float uNight; uniform float uClouds; uniform float uZonda; uniform float uTime; uniform float uSunVis;
uniform vec3 uHaze; uniform vec3 uCloudLit; uniform vec3 uCloudShade;
varying vec3 vDir;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){ float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++){ s += a * vnoise(p); p *= 2.03; a *= 0.5; } return s; }
void main(){
  vec3 d = normalize(vDir);
  float h = d.y;
  float t = pow(clamp(h, 0.0, 1.0), 0.5);
  vec3 col = mix(uHorizon, uTop, t);
  col = mix(col, uGround, smoothstep(0.0, -0.1, h));
  float sd = max(dot(d, uSunDir), 0.0);
  col += uSunColor * (pow(sd, 5.0) * 0.18 + pow(sd, 40.0) * 0.3) * (1.0 - uZonda * 0.4);
  col += uSunColor * smoothstep(0.99935, 0.99965, sd) * 5.0 * uSunVis * (1.0 - uClouds * 0.75) * (1.0 - uZonda * 0.85);
  float md = dot(d, uMoonDir);
  col += vec3(0.9, 0.92, 1.0) * smoothstep(0.99945, 0.9997, md) * 2.4 * uNight * (1.0 - uClouds * 0.8) * (1.0 - uZonda);
  col += vec3(0.25, 0.3, 0.45) * pow(max(md, 0.0), 30.0) * 0.35 * uNight;
  if (h > 0.0 && uClouds > 0.01) {
    vec2 uv = d.xz / (h + 0.18) * 1.1 + vec2(uTime * 0.008, uTime * 0.003);
    float n = fbm(uv);
    float th = 0.72 - 0.34 * uClouds;
    float cover = smoothstep(th, th + 0.18, n) * smoothstep(0.0, 0.1, h) * smoothstep(0.0, 0.15, uClouds);
    vec3 cc = mix(uCloudShade, uCloudLit, clamp((n - th) * 3.0, 0.0, 1.0) * 0.5 + sd * 0.5);
    col = mix(col, cc, cover * 0.92);
  }
  col = mix(col, uHaze, uZonda * (0.6 + 0.35 * (1.0 - t)));
  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

const dustVert = /* glsl */`
attribute float aSeed;
uniform float uTime; uniform vec3 uCenter; uniform vec3 uWind; uniform float uSize; uniform float uBox;
varying float vA;
void main(){
  vec3 p = position + uWind * uTime * (0.7 + aSeed * 0.6);
  p.xz = mod(p.xz - uCenter.xz + uBox * 0.5, uBox) + uCenter.xz - uBox * 0.5;
  p.y = mod(p.y + sin(uTime * 0.9 + aSeed * 31.0) * 0.6, 9.0) + 0.05;
  p.z += sin(uTime * 1.7 + aSeed * 17.0) * 0.35;
  vec4 mv = modelViewMatrix * vec4(p, 1.0);
  gl_Position = projectionMatrix * mv;
  gl_PointSize = min(18.0, uSize * (0.4 + aSeed) * (220.0 / max(1.0, -mv.z)));
  vA = smoothstep(uBox * 0.5, uBox * 0.28, length(p.xz - uCenter.xz)) * smoothstep(0.5, 3.0, -mv.z);
}`;

const dustFrag = /* glsl */`
uniform sampler2D uMap; uniform vec3 uColor; uniform float uOpacity;
varying float vA;
void main(){
  float a = texture2D(uMap, gl_PointCoord).a * uOpacity * vA;
  if (a < 0.01) discard;
  gl_FragColor = vec4(uColor, a);
  #include <colorspace_fragment>
}`;

function smooth(e0: number, e1: number, x: number): number {
  const t = THREE.MathUtils.clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

export class Environment implements IEnvironment {
  readonly scene = new THREE.Scene();
  readonly sun = new THREE.DirectionalLight(0xfff1d6, 2.6);
  readonly hemi = new THREE.HemisphereLight(0xcfe8f2, 0x8a6a48, 1.0);
  readonly sky: THREE.Mesh;
  readonly terrain: THREE.Mesh;
  readonly mountains: THREE.Mesh;
  private stars: THREE.Points;
  private dust: THREE.Points;
  private skyU: Record<string, THREE.IUniform>;
  private dustU: Record<string, THREE.IUniform>;
  private fog: THREE.Fog;
  private night = 0;
  private time = 0;
  private readonly center: [number, number];
  private readonly flatR: number;
  private readonly shadowExtent = 18;

  /** Dirección del sol (unitaria, hacia el sol) del último update. */
  readonly sunDir = new THREE.Vector3(0, 1, 0);

  constructor(private readonly factory: ModelFactory, opts: EnvironmentOptions = {}) {
    const seed = opts.seed ?? 7;
    this.center = opts.center ?? [2, -4];
    this.flatR = opts.flatRadius ?? 40;
    const quality = opts.quality ?? factory.mats.quality;
    const paths = opts.paths ?? DEFAULT_PATHS;
    const clearings = opts.clearings ?? [{ x: 1, z: -3, r: 21 }, { x: 29, z: -27, r: 15 }];

    const s = this.scene;
    s.name = 'environment';
    this.fog = new THREE.Fog(0xcfe8f2, 70, 700);
    s.fog = this.fog;
    s.background = new THREE.Color(0x9fd3ea);

    // Cielo
    this.skyU = {
      uTop: { value: SKY.dayTop.clone() }, uHorizon: { value: SKY.dayHorizon.clone() }, uGround: { value: new THREE.Color(0xb59a74) },
      uSunDir: { value: new THREE.Vector3(0, 1, 0) }, uSunColor: { value: new THREE.Color(1, 0.9, 0.7) }, uMoonDir: { value: new THREE.Vector3(0, 1, 0) },
      uNight: { value: 0 }, uClouds: { value: 0 }, uZonda: { value: 0 }, uTime: { value: 0 }, uSunVis: { value: 1 },
      uHaze: { value: SKY.zonda.clone() }, uCloudLit: { value: new THREE.Color(1, 1, 1) }, uCloudShade: { value: new THREE.Color(0.7, 0.75, 0.82) },
    };
    const skyMat = new THREE.ShaderMaterial({ uniforms: this.skyU, vertexShader: skyVert, fragmentShader: skyFrag, side: THREE.BackSide, depthWrite: false, fog: false });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(450, 32, 16), skyMat);
    this.sky.renderOrder = -10; this.sky.frustumCulled = false; this.sky.name = 'sky';
    s.add(this.sky);

    // Estrellas
    const r0 = rng(seed + 1);
    const starPos: number[] = [];
    for (let i = 0; i < 900; i++) {
      const th = r0() * Math.PI * 2, y = 0.06 + r0() * 0.94;
      const rr = Math.sqrt(1 - y * y);
      starPos.push(Math.cos(th) * rr * 420, y * 420, Math.sin(th) * rr * 420);
    }
    const starGeo = new THREE.BufferGeometry();
    starGeo.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3));
    this.stars = new THREE.Points(starGeo, new THREE.PointsMaterial({ color: 0xffffff, size: 1.8, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
    this.stars.renderOrder = -9; this.stars.frustumCulled = false; this.stars.visible = false;
    s.add(this.stars);

    // Luces
    this.sun.castShadow = true;
    const e = this.shadowExtent;
    Object.assign(this.sun.shadow.camera, { left: -e, right: e, top: e, bottom: -e, near: 1, far: 140 });
    this.sun.shadow.mapSize.set(quality === 'high' ? 2048 : 1024, quality === 'high' ? 2048 : 1024);
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.03;
    s.add(this.sun, this.sun.target, this.hemi);

    // Terreno + caminos
    this.terrain = this.buildTerrain(seed, paths);
    s.add(this.terrain);
    // Montañas
    this.mountains = this.buildMountains(seed);
    s.add(this.mountains);
    // Vegetación y piedras
    this.buildScatter(seed, paths, clearings, quality);

    // Polvo del Zonda
    const N = quality === 'low' ? 1200 : quality === 'medium' ? 2200 : 3200;
    const BOX = 60;
    const r1 = rng(seed + 3);
    const dp = new Float32Array(N * 3), ds = new Float32Array(N);
    for (let i = 0; i < N; i++) { dp[i * 3] = r1() * BOX; dp[i * 3 + 1] = Math.pow(r1(), 1.6) * 9; dp[i * 3 + 2] = r1() * BOX; ds[i] = r1(); }
    const dg = new THREE.BufferGeometry();
    dg.setAttribute('position', new THREE.BufferAttribute(dp, 3));
    dg.setAttribute('aSeed', new THREE.BufferAttribute(ds, 1));
    this.dustU = {
      uTime: { value: 0 }, uCenter: { value: new THREE.Vector3() }, uWind: { value: new THREE.Vector3(-14, 0, -4) },
      uSize: { value: 0.55 }, uBox: { value: BOX }, uMap: { value: factory.textures.dustSprite() },
      uColor: { value: new THREE.Color(0xe2bd85) }, uOpacity: { value: 0 },
    };
    this.dust = new THREE.Points(dg, new THREE.ShaderMaterial({
      uniforms: this.dustU, vertexShader: dustVert, fragmentShader: dustFrag, transparent: true, depthWrite: false, fog: false,
    }));
    this.dust.frustumCulled = false; this.dust.visible = false; this.dust.renderOrder = 5;
    s.add(this.dust);

    this.update(0, 11, { zonda: 0, clouds: 0, follow: new THREE.Vector3(this.center[0], 0, this.center[1]) });
  }

  /** Altura del terreno en (x, z). Dentro del radio plano es 0. */
  heightAt(x: number, z: number): number {
    const d = Math.hypot(x - this.center[0], z - this.center[1]);
    const m = smooth(this.flatR, this.flatR + 60, d);
    if (m <= 0) return 0;
    const n = fbm2(x * 0.011, z * 0.011, 4, 3);
    return m * ((n - 0.35) * 26 + m * 7);
  }

  nightFactor(): number { return this.night; }

  update(dt: number, hour: number, opts: { zonda: number; clouds: number; follow: THREE.Vector3 }): void {
    this.time += dt;
    const zonda = THREE.MathUtils.clamp(opts.zonda, 0, 1);
    const clouds = THREE.MathUtils.clamp(opts.clouds, 0, 1);
    const f = opts.follow;

    // Sol: día de 6:30 a 20:00; noche de 20:00 a 6:30 (continuo).
    const h = ((hour % 24) + 24) % 24;
    let a: number;
    if (h >= 6.5 && h <= 20) a = Math.PI * (h - 6.5) / 13.5;
    else { const hn = h > 20 ? h - 20 : h + 4; a = Math.PI + Math.PI * hn / 10.5; }
    const sd = this.sunDir.set(-Math.cos(a), Math.sin(a) * 0.86, Math.sin(a) * 0.5 + 0.18).normalize();
    const elev = sd.y;
    const moon = new THREE.Vector3(-sd.x * 0.8, Math.max(0.35, -sd.y), -0.45).normalize();

    const day = smooth(-0.04, 0.38, elev);
    const dusk = (1 - smooth(0.0, 0.32, Math.abs(elev - 0.04))) * (1 - zonda * 0.6);
    const night = smooth(0.06, -0.16, elev);
    this.night = smooth(0.14, -0.06, elev);

    // Colores de cielo
    const top = SKY.nightTop.clone().lerp(SKY.dayTop, day).lerp(SKY.duskTop, dusk * 0.55);
    const hor = SKY.nightHorizon.clone().lerp(SKY.dayHorizon, day).lerp(SKY.duskHorizon, dusk * 0.85);
    const haze = SKY.zonda.clone().lerp(SKY.zondaDark, night * 0.85);
    const U = this.skyU;
    (U.uTop.value as THREE.Color).copy(top);
    (U.uHorizon.value as THREE.Color).copy(hor);
    (U.uGround.value as THREE.Color).copy(hor).multiplyScalar(0.75);
    (U.uSunDir.value as THREE.Vector3).copy(sd);
    (U.uMoonDir.value as THREE.Vector3).copy(moon);
    const sunCol = new THREE.Color(1, 0.93, 0.78).lerp(new THREE.Color(1, 0.55, 0.25), dusk);
    (U.uSunColor.value as THREE.Color).copy(sunCol);
    U.uSunVis.value = smooth(-0.03, 0.02, elev);
    U.uNight.value = night;
    U.uClouds.value = clouds;
    U.uZonda.value = zonda;
    U.uTime.value = this.time;
    (U.uHaze.value as THREE.Color).copy(haze);
    (U.uCloudLit.value as THREE.Color).setRGB(1, 1, 1).lerp(new THREE.Color(1, 0.72, 0.5), dusk).lerp(new THREE.Color(0.18, 0.22, 0.32), night);
    (U.uCloudShade.value as THREE.Color).setRGB(0.66, 0.72, 0.8).lerp(new THREE.Color(0.55, 0.42, 0.45), dusk).lerp(new THREE.Color(0.06, 0.08, 0.14), night);
    this.sky.position.copy(f);
    this.stars.position.copy(f);

    // Luz principal (sol o luna)
    const sunI = 2.9 * smooth(-0.05, 0.16, elev) * (1 - 0.55 * clouds) * (1 - 0.55 * zonda);
    const moonI = 0.42 * night * (1 - 0.6 * clouds) * (1 - 0.7 * zonda);
    const useSun = sunI >= moonI;
    const dir = useSun ? sd : moon;
    this.sun.intensity = Math.max(sunI, moonI);
    if (useSun) this.sun.color.setRGB(1, 0.95, 0.86).lerp(new THREE.Color(1, 0.72, 0.48), dusk * 0.85).lerp(new THREE.Color(1, 0.78, 0.55), zonda * 0.6);
    else this.sun.color.setRGB(0.62, 0.72, 1.0);
    // Sombras centradas en follow, ajustadas al tamaño de texel para evitar parpadeo
    const texel = (this.shadowExtent * 2) / this.sun.shadow.mapSize.x;
    const cx = Math.round(f.x / texel) * texel, cz = Math.round(f.z / texel) * texel;
    this.sun.target.position.set(cx, 0, cz);
    this.sun.position.set(cx + dir.x * 60, dir.y * 60, cz + dir.z * 60);
    this.sun.target.updateMatrixWorld();

    // Hemisférica
    this.hemi.color.copy(hor).lerp(top, 0.35 * day).lerp(new THREE.Color(1, 0.92, 0.8), 0.25 * dusk).lerp(new THREE.Color(0.35, 0.42, 0.65), night * 0.6).lerp(SKY.zonda, zonda * 0.6);
    this.hemi.groundColor.setRGB(0.6, 0.48, 0.34).lerp(new THREE.Color(0.08, 0.08, 0.12), night);
    this.hemi.intensity = THREE.MathUtils.lerp(0.6, 1.25, day) + dusk * 0.6 + zonda * 0.2;

    // Niebla
    const fogCol = hor.clone().lerp(haze, zonda);
    this.fog.color.copy(fogCol);
    (this.scene.background as THREE.Color).copy(fogCol);
    this.fog.near = THREE.MathUtils.lerp(70, 3, Math.pow(zonda, 0.7));
    this.fog.far = THREE.MathUtils.lerp(700 - clouds * 150, 55, Math.pow(zonda, 0.6));

    // Estrellas
    const so = night * (1 - clouds * 0.85) * (1 - zonda);
    (this.stars.material as THREE.PointsMaterial).opacity = so;
    this.stars.visible = so > 0.01;

    // Polvo
    this.dustU.uTime.value = this.time;
    (this.dustU.uCenter.value as THREE.Vector3).copy(f);
    this.dustU.uOpacity.value = Math.min(1, zonda * 1.3) * 0.9;
    (this.dustU.uColor.value as THREE.Color).setRGB(0.86, 0.66, 0.4).lerp(new THREE.Color(0.35, 0.28, 0.22), night * 0.8);
    (this.dustU.uWind.value as THREE.Vector3).set(-16, 0, -5).multiplyScalar(0.4 + zonda * 0.8);
    this.dust.visible = zonda > 0.02;

    // Luminarias públicas
    this.factory.setNight(this.night);
  }

  /* ------------------------------------------------------------------ construcción */

  private buildTerrain(seed: number, paths: { points: [number, number][]; width?: number }[]): THREE.Mesh {
    const SIZE = 640, SEG = 100;
    const g = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG).rotateX(-Math.PI / 2);
    g.translate(this.center[0], 0, this.center[1]);
    const pos = g.attributes.position as THREE.BufferAttribute;
    const r = rng(seed + 9);
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      // jitter horizontal fuera de la zona plana (facetas menos regulares)
      const d = Math.hypot(x - this.center[0], z - this.center[1]);
      const j = d > this.flatR + 8 ? 1.6 : 0;
      const xx = x + (r() - 0.5) * j, zz = z + (r() - 0.5) * j;
      pos.setXYZ(i, xx, this.heightAt(xx, zz), zz);
    }
    const flat = g.toNonIndexed();
    g.dispose();
    flat.computeVertexNormals();
    const p = flat.attributes.position as THREE.BufferAttribute;
    const col = new Float32Array(p.count * 3);
    const cA = new THREE.Color(0xd8b67e), cB = new THREE.Color(0xc39561), cRed = new THREE.Color(0xb4794c), cDry = new THREE.Color(0xa9a466);
    const c = new THREE.Color();
    for (let i = 0; i < p.count; i += 3) {
      const x = (p.getX(i) + p.getX(i + 1) + p.getX(i + 2)) / 3;
      const y = (p.getY(i) + p.getY(i + 1) + p.getY(i + 2)) / 3;
      const z = (p.getZ(i) + p.getZ(i + 1) + p.getZ(i + 2)) / 3;
      const n = fbm2(x * 0.025, z * 0.025, 3, seed);
      c.copy(cA).lerp(cB, smooth(0.35, 0.7, n));
      c.lerp(cRed, smooth(3, 14, y) * 0.6);
      c.lerp(cDry, smooth(0.6, 0.9, fbm2(x * 0.02 + 50, z * 0.02, 3, seed + 2)) * 0.35);
      const k = 1 + (r() - 0.5) * 0.045;
      for (let v = 0; v < 3; v++) { col[(i + v) * 3] = c.r * k; col[(i + v) * 3 + 1] = c.g * k; col[(i + v) * 3 + 2] = c.b * k; }
    }
    flat.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    const uv = flat.attributes.uv as THREE.BufferAttribute;
    for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i) / 5, p.getZ(i) / 5);

    const gb = new GeoBuilder(seed + 11);
    gb.add(flat, 0xffffff, undefined, { keepColors: true });
    // caminos: borde suave más ancho + centro claro con huellas
    for (const path of paths) {
      const w = path.width ?? 3;
      gb.add(this.ribbon(path.points, w + 1.1, 0.018, seed + 1), 0xc29c66, undefined, { project: { axis: 'xz', scale: 5 }, jitter: 0.03 });
      gb.add(this.ribbon(path.points, w, 0.03, seed + 2), 0xdcc08e, undefined, { project: { axis: 'xz', scale: 5 }, jitter: 0.025 });
      for (const off of [-0.6, 0.6]) gb.add(this.ribbon(path.points, 0.35, 0.036, seed + 3, off * w / 2), 0xcbab77, undefined, { project: { axis: 'xz', scale: 5 } });
    }
    const geo = gb.build();
    const m = new THREE.Mesh(geo, this.factory.mats.terrain);
    m.receiveShadow = true; m.name = 'terrain';
    return m;
  }

  /** Cinta plana sobre el suelo siguiendo una polilínea, con bordes irregulares. */
  private ribbon(pts: [number, number][], width: number, y: number, seed: number, offset = 0): THREE.BufferGeometry {
    const samples: THREE.Vector2[] = [];
    const curve = new THREE.SplineCurve(pts.map(([x, z]) => new THREE.Vector2(x, z)));
    const len = curve.getLength();
    const n = Math.max(2, Math.ceil(len / 1.2));
    for (let i = 0; i <= n; i++) samples.push(curve.getPoint(i / n));
    const posArr: number[] = [];
    const L: THREE.Vector3[] = [], R: THREE.Vector3[] = [];
    for (let i = 0; i <= n; i++) {
      const a = samples[Math.max(0, i - 1)], b = samples[Math.min(n, i + 1)];
      const t = new THREE.Vector2().subVectors(b, a).normalize();
      const nx = -t.y, nz = t.x;
      const p = samples[i];
      const wl = width / 2 * (1 + (noise2(i * 0.7, 3, seed) - 0.5) * 0.35);
      const wr = width / 2 * (1 + (noise2(i * 0.7, 9, seed) - 0.5) * 0.35);
      const cx = p.x + nx * offset, cz = p.y + nz * offset;
      L.push(new THREE.Vector3(cx + nx * wl, y + this.heightAt(cx + nx * wl, cz + nz * wl), cz + nz * wl));
      R.push(new THREE.Vector3(cx - nx * wr, y + this.heightAt(cx - nx * wr, cz - nz * wr), cz - nz * wr));
    }
    for (let i = 0; i < n; i++) {
      const a = L[i], b = R[i], c = L[i + 1], d = R[i + 1];
      // orientación con normal hacia +Y
      posArr.push(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z);
      posArr.push(b.x, b.y, b.z, c.x, c.y, c.z, d.x, d.y, d.z);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(posArr, 3));
    g.computeVertexNormals();
    // asegurar normales hacia arriba
    const nrm = g.attributes.normal as THREE.BufferAttribute;
    if (nrm.count && nrm.getY(0) < 0) {
      const arr = g.attributes.position.array as Float32Array;
      for (let i = 0; i < arr.length; i += 9) for (let k = 0; k < 3; k++) { const tmp = arr[i + 3 + k]; arr[i + 3 + k] = arr[i + 6 + k]; arr[i + 6 + k] = tmp; }
      g.computeVertexNormals();
    }
    return g;
  }

  private buildMountains(seed: number): THREE.Mesh {
    const gb = new GeoBuilder(seed + 21);
    const layer = (R: number, N: number, hMin: number, hMax: number, cLow: number, cHigh: number, snow: number | null, s: number) => {
      const r = rng(s);
      const pos: number[] = [];
      const cols: number[] = [];
      const top: THREE.Vector3[] = [], mid: THREE.Vector3[] = [], bot: THREE.Vector3[] = [];
      for (let i = 0; i <= N; i++) {
        const a = (i / N) * Math.PI * 2;
        const ca = Math.cos(a), sa = Math.sin(a);
        const peak = i % 2 === 0;
        const env = 0.55 + 0.45 * fbm2(Math.cos(a) * 1.8 + 5, Math.sin(a) * 1.8, 3, s);
        const hh = (peak ? hMin + r() * (hMax - hMin) : (hMin + r() * (hMax - hMin)) * (0.5 + r() * 0.2)) * env;
        const rr = R + (r() - 0.5) * R * 0.08;
        top.push(new THREE.Vector3(this.center[0] + ca * rr, hh, this.center[1] + sa * rr));
        const rm = rr + (r() - 0.6) * 18;
        mid.push(new THREE.Vector3(this.center[0] + ca * rm, hh * (0.42 + r() * 0.15), this.center[1] + sa * rm));
        bot.push(new THREE.Vector3(this.center[0] + ca * (rr + 30), -6, this.center[1] + sa * (rr + 30)));
      }
      const lo = new THREE.Color(cLow), hi = new THREE.Color(cHigh), sn = new THREE.Color(0xf4f6fa);
      const tri = (a: THREE.Vector3, b: THREE.Vector3, c: THREE.Vector3) => {
        pos.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z);
        const y = Math.max(a.y, b.y, c.y), ym = (a.y + b.y + c.y) / 3;
        const col = lo.clone().lerp(hi, THREE.MathUtils.clamp(ym / hMax, 0, 1)).multiplyScalar(0.92 + r() * 0.16);
        if (snow !== null && ym > snow * hMax * 0.62 && y > snow * hMax) col.copy(sn).multiplyScalar(0.93 + r() * 0.07);
        for (let k = 0; k < 3; k++) cols.push(col.r, col.g, col.b);
      };
      // caras hacia el centro (el jugador está adentro del anillo)
      for (let i = 0; i < N; i++) {
        tri(mid[i], top[i + 1], top[i]);
        tri(mid[i], mid[i + 1], top[i + 1]);
        tri(bot[i], mid[i + 1], mid[i]);
        tri(bot[i], bot[i + 1], mid[i + 1]);
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      g.computeVertexNormals();
      g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
      gb.add(g, 0xffffff, undefined, { keepColors: true });
    };
    layer(330, 64, 75, 125, 0x76739a, 0x9c97bb, 0.56, seed + 31);
    layer(215, 80, 28, 58, 0x9a6b4c, 0xb98a63, null, seed + 37);
    const geo = gb.build();
    const m = new THREE.Mesh(geo, this.factory.mats.vc);
    m.name = 'mountains';
    m.matrixAutoUpdate = false;
    return m;
  }

  private buildScatter(seed: number, paths: { points: [number, number][]; width?: number }[], clearings: { x: number; z: number; r: number }[], quality: QualityLevel): void {
    const r = rng(seed + 41);
    const pathPts: THREE.Vector2[] = [];
    for (const p of paths) {
      const c = new THREE.SplineCurve(p.points.map(([x, z]) => new THREE.Vector2(x, z)));
      const n = Math.ceil(c.getLength() / 1.5);
      for (let i = 0; i <= n; i++) pathPts.push(c.getPoint(i / n));
    }
    const blocked = (x: number, z: number, pad: number) => {
      for (const c of clearings) if (Math.hypot(x - c.x, z - c.z) < c.r + pad) return true;
      for (const p of pathPts) if (Math.abs(p.x - x) < 3 + pad && Math.abs(p.y - z) < 3 + pad) return true;
      return false;
    };
    const k = quality === 'low' ? 0.6 : 1;
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), v = new THREE.Vector3(), sc = new THREE.Vector3();
    type Item = { x: number; z: number; s: number; sy?: number; ry?: number; col: THREE.Color };
    const place = (geo: THREE.BufferGeometry, mat: THREE.Material, count: number, gen: () => Item | null, cast: boolean, name: string) => {
      const items: Item[] = [];
      let guard = 0;
      while (items.length < count && guard++ < count * 30) { const it = gen(); if (it) items.push(it); }
      const im = new THREE.InstancedMesh(geo, mat, items.length);
      items.forEach((it, i) => {
        e.set((r() - 0.5) * 0.08, it.ry ?? r() * Math.PI * 2, (r() - 0.5) * 0.08);
        q.setFromEuler(e);
        sc.set(it.s, it.s * (it.sy ?? 1), it.s);
        v.set(it.x, this.heightAt(it.x, it.z) - 0.05, it.z);
        im.setMatrixAt(i, m4.compose(v, q, sc));
        im.setColorAt(i, it.col);
      });
      im.castShadow = cast; im.receiveShadow = true; im.name = name;
      im.computeBoundingSphere();
      this.scene.add(im);
      return im;
    };
    const ringPt = (rMin: number, rMax: number) => {
      const a = r() * Math.PI * 2, d = rMin + Math.sqrt(r()) * (rMax - rMin);
      return [this.center[0] + Math.cos(a) * d, this.center[1] + Math.sin(a) * d];
    };
    const tint = (base: number, amt: number) => new THREE.Color(base).multiplyScalar(1 + (r() - 0.5) * amt);

    // Piedras
    const rockGeo = (() => { const g = new GeoBuilder(seed + 50); g.add(lumpy(0.5, 0, 0.35, seed), 0xffffff, { s: [1, 0.6, 0.85] }, { jitter: 0.12 }); return g.build(); })();
    place(rockGeo, this.factory.mats.vc, Math.round(170 * k), () => {
      const [x, z] = ringPt(10, 170);
      if (blocked(x, z, 0)) return null;
      const d = Math.hypot(x - this.center[0], z - this.center[1]);
      return { x, z, s: (0.35 + r() * 0.9) * (d > 60 ? 2.2 : 1), col: tint(r() < 0.5 ? 0xa59a8a : 0xb48a64, 0.18) };
    }, true, 'rocks');
    // Jarillas
    place(this.factory.treeGeometry(2), this.factory.mats.vc, Math.round(190 * k), () => {
      const [x, z] = ringPt(14, 150);
      if (blocked(x, z, 1)) return null;
      return { x, z, s: 0.8 + r() * 0.7, col: tint(0xffffff, 0.2) };
    }, true, 'jarillas');
    // Pasto seco
    const grass = (() => {
      const g = new GeoBuilder(seed + 60);
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * Math.PI * 2;
        g.add(segment(new THREE.Vector3(Math.cos(a) * 0.05, 0, Math.sin(a) * 0.05), new THREE.Vector3(Math.cos(a) * 0.22, 0.45 + (i % 2) * 0.15, Math.sin(a) * 0.22), 0.035, 0.0, 3), 0xd9c27a);
      }
      return g.build();
    })();
    place(grass, this.factory.mats.vc, Math.round(320 * k), () => {
      const [x, z] = ringPt(8, 110);
      if (blocked(x, z, -1)) return null;
      return { x, z, s: 0.7 + r() * 0.8, col: tint(0xffffff, 0.25) };
    }, false, 'grass');
    // Algarrobos dispersos
    place(this.factory.treeGeometry(1, 1), this.factory.mats.vc, Math.round(16 * k + 4), () => {
      const [x, z] = ringPt(26, 120);
      if (blocked(x, z, 4)) return null;
      return { x, z, s: 0.9 + r() * 0.5, col: tint(0xffffff, 0.12) };
    }, true, 'algarrobos');
    // Cortinas de álamos (rompevientos típicos de las fincas sanjuaninas)
    const lines: [number, number, number, number][] = [[-95, -62, 75, -62], [-95, -62, -95, 40], [58, 34, 120, 34], [-70, 52, -10, 58]];
    const poplars: { x: number; z: number }[] = [];
    for (const [x0, z0, x1, z1] of lines) {
      const len = Math.hypot(x1 - x0, z1 - z0), n = Math.floor(len / 3.6);
      for (let i = 0; i <= n; i++) { const t = i / n; if (r() < 0.14) continue; poplars.push({ x: x0 + (x1 - x0) * t + (r() - 0.5) * 0.8, z: z0 + (z1 - z0) * t + (r() - 0.5) * 0.8 }); }
    }
    let pi = 0;
    place(this.factory.treeGeometry(0, 1), this.factory.mats.vc, Math.round(poplars.length * (quality === 'low' ? 0.5 : 1)), () => {
      const p = poplars[(pi++ * (quality === 'low' ? 2 : 1)) % poplars.length];
      return { x: p.x, z: p.z, s: 0.85 + r() * 0.35, col: tint(0xffffff, 0.14) };
    }, true, 'alamos');
    // Viñedo (hileras con postes) al fondo
    const vine = (() => {
      const g = new GeoBuilder(seed + 70);
      g.add(lumpy(1, 1, 0.25, seed + 3), 0x5f8f34, { p: [0, 0.75, 0], s: [3.0, 0.5, 0.42] }, { jitter: 0.1 });
      for (const x of [-2.9, 2.9]) g.box(0.07, 1.4, 0.07, 0x7a5b3e, { p: [x, 0.7, 0] });
      g.box(6, 0.015, 0.015, 0x666666, { p: [0, 1.25, 0] });
      return g.build();
    })();
    const vines: { x: number; z: number }[] = [];
    for (let row = 0; row < 12; row++) for (let i = 0; i < 6; i++) vines.push({ x: -82 + i * 6.1, z: 64 + row * 2.6 });
    for (let row = 0; row < 10; row++) for (let i = 0; i < 7; i++) vines.push({ x: 60 + i * 6.1, z: -78 - row * 2.6 });
    let vi = 0;
    place(vine, this.factory.mats.vc, vines.length, () => {
      const p = vines[vi++ % vines.length];
      return { x: p.x, z: p.z, s: 1, ry: 0, col: tint(0xffffff, 0.1) };
    }, quality !== 'low', 'vinedo');
  }
}
