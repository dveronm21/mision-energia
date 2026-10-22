/**
 * RendererFacade (IRendererFacade): WebGLRenderer + cámara + post-proceso según calidad.
 *  - low:    sin bloom, sombras 1024 PCF (no suaves), pixelRatio ≤ 1, sin antialias de composer.
 *  - medium: sin bloom, sombras 1024 PCFSoft, pixelRatio ≤ 1.5.
 *  - high:   bloom suave (UnrealBloomPass), sombras 2048 PCFSoft, pixelRatio ≤ 2.
 * Funciona en WebGL1 y WebGL2: si no hay render targets de punto flotante, desactiva el bloom.
 */
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import type { GraphicsSettings, IRendererFacade, QualityLevel } from '../../contracts';

export const DEFAULT_SETTINGS: Record<QualityLevel, GraphicsSettings> = {
  low: { quality: 'low', pixelRatioCap: 1.0 },
  medium: { quality: 'medium', pixelRatioCap: 1.5 },
  high: { quality: 'high', pixelRatioCap: 2.0 },
};

export interface RendererFacadeOptions {
  /** Canvas existente (si no, se crea uno y se agrega a `container`). */
  canvas?: HTMLCanvasElement;
  container?: HTMLElement;
  settings?: GraphicsSettings;
  /** Contexto ya creado (p.ej. para forzar WebGL1 en pruebas). */
  context?: WebGLRenderingContext | WebGL2RenderingContext;
  /** Para capturas (Playwright): conserva el buffer. */
  preserveDrawingBuffer?: boolean;
}

export class RendererFacade implements IRendererFacade {
  readonly renderer: THREE.WebGLRenderer;
  readonly camera: THREE.PerspectiveCamera;
  private settings: GraphicsSettings;
  private composer: EffectComposer | null = null;
  private renderPass: RenderPass | null = null;
  private bloom: UnrealBloomPass | null = null;
  private w = 1;
  private h = 1;
  private shadowsDirty = true;
  /** Draw calls y triángulos del último frame (todas las pasadas, incluidas sombras y post). */
  readonly stats = { calls: 0, triangles: 0, mainCalls: 0 };

  constructor(opts: RendererFacadeOptions = {}) {
    this.settings = opts.settings ?? DEFAULT_SETTINGS.high;
    this.renderer = new THREE.WebGLRenderer({
      canvas: opts.canvas,
      context: opts.context,
      antialias: this.settings.quality !== 'low',
      powerPreference: 'high-performance',
      preserveDrawingBuffer: opts.preserveDrawingBuffer ?? false,
      stencil: false,
    });
    const r = this.renderer;
    r.outputColorSpace = THREE.SRGBColorSpace;
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.toneMappingExposure = 1.0;
    r.shadowMap.enabled = true;
    r.info.autoReset = false;
    if (opts.container && !opts.canvas) opts.container.appendChild(r.domElement);
    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 1200);
    this.applyQuality();
    const el = r.domElement;
    this.resize(el.clientWidth || window.innerWidth, el.clientHeight || window.innerHeight);
  }

  get quality(): GraphicsSettings { return { ...this.settings }; }

  get isWebGL2(): boolean { return this.renderer.capabilities.isWebGL2; }

  private floatTargets(): boolean {
    const r = this.renderer;
    if (r.capabilities.isWebGL2) return r.extensions.has('EXT_color_buffer_float') || r.extensions.has('EXT_color_buffer_half_float');
    return r.extensions.has('OES_texture_half_float') && r.extensions.has('EXT_color_buffer_half_float');
  }

  private applyQuality(): void {
    const q = this.settings.quality;
    const r = this.renderer;
    const prevType = r.shadowMap.type;
    r.shadowMap.type = q === 'low' ? THREE.PCFShadowMap : THREE.PCFSoftShadowMap;
    if (prevType !== r.shadowMap.type) this.shadowsDirty = true;
    r.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.settings.pixelRatioCap, q === 'low' ? 1 : q === 'medium' ? 1.5 : 2));
    this.shadowsDirty = true;

    const wantBloom = q === 'high' && this.floatTargets();
    if (wantBloom && !this.composer) {
      const size = r.getDrawingBufferSize(new THREE.Vector2());
      const rt = new THREE.WebGLRenderTarget(size.x, size.y, {
        type: THREE.HalfFloatType,
        samples: r.capabilities.isWebGL2 ? 4 : 0,
      });
      this.composer = new EffectComposer(r, rt);
      this.renderPass = new RenderPass(new THREE.Scene(), this.camera);
      this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x / 2, size.y / 2), 0.32, 0.45, 1.0);
      this.composer.addPass(this.renderPass);
      this.composer.addPass(this.bloom);
      this.composer.addPass(new OutputPass());
    } else if (!wantBloom && this.composer) {
      this.composer.dispose();
      this.composer = null; this.renderPass = null; this.bloom = null;
    }
    if (this.composer) {
      this.composer.setPixelRatio(r.getPixelRatio());
      this.composer.setSize(this.w, this.h);
    }
  }

  setQuality(s: GraphicsSettings): void {
    this.settings = { ...s };
    this.applyQuality();
    this.resize(this.w, this.h);
  }

  /** Ajusta tamaño de sombras de las luces y recompila materiales tras cambiar de calidad. */
  private syncShadows(scene: THREE.Scene): void {
    const size = this.settings.quality === 'high' ? 2048 : 1024;
    scene.traverse((o) => {
      const l = o as THREE.DirectionalLight;
      if (l.isDirectionalLight && l.castShadow && l.shadow.mapSize.x !== size) {
        l.shadow.mapSize.set(size, size);
        if (l.shadow.map) { l.shadow.map.dispose(); l.shadow.map = null; }
      }
      const m = (o as THREE.Mesh).material;
      if (m) (Array.isArray(m) ? m : [m]).forEach((mm) => { mm.needsUpdate = true; });
    });
    this.shadowsDirty = false;
  }

  render(scene: THREE.Scene): void {
    if (this.shadowsDirty) this.syncShadows(scene);
    const info = this.renderer.info;
    info.reset();
    if (this.composer && this.renderPass) {
      this.renderPass.scene = scene;
      this.composer.render();
    } else {
      this.renderer.render(scene, this.camera);
    }
    this.stats.calls = info.render.calls;
    this.stats.triangles = info.render.triangles;
  }

  resize(w: number, h: number): void {
    this.w = Math.max(1, Math.floor(w)); this.h = Math.max(1, Math.floor(h));
    this.renderer.setSize(this.w, this.h, false);
    this.camera.aspect = this.w / this.h;
    this.camera.updateProjectionMatrix();
    if (this.composer) { this.composer.setPixelRatio(this.renderer.getPixelRatio()); this.composer.setSize(this.w, this.h); }
  }

  dispose(): void {
    this.composer?.dispose();
    this.renderer.dispose();
  }
}
