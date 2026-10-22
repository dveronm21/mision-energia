/**
 * Materials: biblioteca de materiales compartidos.
 * - high/medium: MeshStandardMaterial (PBR, flatShading para el look low-poly).
 * - low:         MeshLambertMaterial (más barato por píxel).
 * La calidad de materiales se fija al construir; para cambiarla hay que recrear la fábrica/mundo.
 * Los materiales "por instancia" (panel con brillo, inversor, edificio) se clonan: comparten programa.
 */
import * as THREE from 'three';
import type { QualityLevel } from '../../contracts';
import type { Textures } from './Textures';

export type SurfaceMaterial = THREE.MeshStandardMaterial | THREE.MeshLambertMaterial;

export interface SurfaceParams {
  color?: number;
  map?: THREE.Texture | null;
  emissive?: number;
  emissiveIntensity?: number;
  emissiveMap?: THREE.Texture | null;
  roughness?: number;
  metalness?: number;
  vertexColors?: boolean;
  flatShading?: boolean;
  transparent?: boolean;
  opacity?: number;
  side?: THREE.Side;
  depthWrite?: boolean;
}

export class Materials {
  readonly pbr: boolean;
  private cache = new Map<string, THREE.Material>();

  constructor(readonly textures: Textures, readonly quality: QualityLevel) {
    this.pbr = quality !== 'low';
  }

  /** Crea una superficie según la calidad (sin cachear). */
  surface(p: SurfaceParams): SurfaceMaterial {
    const common = {
      color: p.color ?? 0xffffff,
      map: p.map ?? null,
      emissive: p.emissive ?? 0x000000,
      emissiveIntensity: p.emissiveIntensity ?? 1,
      emissiveMap: p.emissiveMap ?? null,
      vertexColors: p.vertexColors ?? false,
      flatShading: p.flatShading ?? true,
      transparent: p.transparent ?? false,
      opacity: p.opacity ?? 1,
      side: p.side ?? THREE.FrontSide,
      depthWrite: p.depthWrite ?? true,
    };
    if (this.pbr) return new THREE.MeshStandardMaterial({ ...common, roughness: p.roughness ?? 0.85, metalness: p.metalness ?? 0 });
    return new THREE.MeshLambertMaterial(common);
  }

  private get<T extends THREE.Material>(key: string, make: () => T): T {
    let m = this.cache.get(key) as T | undefined;
    if (!m) { m = make(); this.cache.set(key, m); }
    return m;
  }

  /** Material base de los modelos fusionados (color por vértice, mate). */
  get vc(): SurfaceMaterial { return this.get('vc', () => this.surface({ vertexColors: true, roughness: 0.82 })); }
  /** Variante semibrillante (equipos, metal pintado). */
  get vcSatin(): SurfaceMaterial { return this.get('vcSatin', () => this.surface({ vertexColors: true, roughness: 0.5, metalness: 0.15 })); }
  /** Personaje: sombreado suave (no flat) para que se vea redondeado. */
  get vcSmooth(): SurfaceMaterial { return this.get('vcSmooth', () => this.surface({ vertexColors: true, roughness: 0.7, flatShading: false })); }
  /** Brillo sin iluminación (LEDs, flujo). Color HDR > 1 para que lo tome el bloom. */
  get glow(): THREE.MeshBasicMaterial {
    return this.get('glow', () => { const m = new THREE.MeshBasicMaterial({ vertexColors: true }); m.color.setScalar(2.2); return m; });
  }
  get ghost(): THREE.MeshBasicMaterial {
    return this.get('ghost', () => new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.32, depthWrite: false }));
  }
  get contactShadow(): THREE.MeshBasicMaterial {
    return this.get('contact', () => {
      const tex = this.textures.dustSprite();
      return new THREE.MeshBasicMaterial({ color: 0x000000, alphaMap: tex, transparent: true, opacity: 0.32, depthWrite: false });
    });
  }
  /** Cajones: atlas madera + íconos + color por vértice. */
  get crate(): SurfaceMaterial { return this.get('crate', () => this.surface({ vertexColors: true, map: this.textures.crate(), roughness: 0.9 })); }
  get concrete(): SurfaceMaterial { return this.get('concrete', () => this.surface({ vertexColors: true, map: this.textures.concrete(), roughness: 0.95 })); }
  get sheet(): SurfaceMaterial { return this.get('sheet', () => this.surface({ vertexColors: true, map: this.textures.metalSheet(), roughness: 0.55, metalness: 0.3 })); }
  get terrain(): SurfaceMaterial { return this.get('terrain', () => this.surface({ vertexColors: true, map: this.textures.soil(), roughness: 1 })); }

  /** Material del panel (uno por panel: brillo y polvo independientes). */
  panel(): SurfaceMaterial {
    const base = this.get('panel', () => this.surface({
      vertexColors: true, map: this.textures.solarPanel(false), roughness: 0.28, metalness: 0.35, emissive: 0x22d3ee, emissiveIntensity: 0,
    }));
    return base.clone();
  }
  /** Material del panel compartido (pila del pallet, sin brillo). */
  get panelShared(): SurfaceMaterial { return this.get('panelShared', () => this.panel()); }

  /** Material de edificio (uno por edificio para setLights). */
  building(): SurfaceMaterial {
    const base = this.get('building', () => this.surface({
      vertexColors: true, map: this.textures.facade('map'), emissiveMap: this.textures.facade('emissive'),
      emissive: 0xffd9a0, emissiveIntensity: 0, roughness: 0.9,
    }));
    return base.clone();
  }

  /** Luminarias públicas compartidas: la intensidad la maneja ModelFactory.setNight(). */
  get lamp(): THREE.MeshBasicMaterial {
    return this.get('lamp', () => new THREE.MeshBasicMaterial({ color: 0x555049 }));
  }

  dispose(): void {
    this.cache.forEach((m) => m.dispose());
    this.cache.clear();
  }
}
