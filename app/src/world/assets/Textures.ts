/**
 * Textures: texturas procedurales (CanvasTexture), cacheadas. Sin archivos externos ni red.
 *
 * Convención "atlas + color por vértice": varias texturas reservan una zona lisa blanca
 * (SOLID_UV.*) para que las piezas sin detalle de un modelo fusionado tomen sólo su color de vértice.
 */
import * as THREE from 'three';
import { rng } from './Geo';

export const FONT_LABEL = 'Fredoka';

/** Coordenadas UV de zonas lisas (blancas/negras) dentro de cada atlas. */
export const SOLID_UV = {
  /** Panel: franja blanca a la derecha (u > 0.9). */
  panel: [0.95, 0.5] as [number, number],
  /** Cajón: cuadrante superior derecho blanco. */
  crate: [0.75, 0.75] as [number, number],
  /** Fachada: zona de pared lisa (esquina de cada celda, pared sin ventana). */
  facade: [0.012, 0.888] as [number, number],
};
/** Rectángulo UV del vidrio del panel dentro del atlas (u0,v0,u1,v1). */
export const PANEL_GLASS_RECT: [number, number, number, number] = [0.004, 0.008, 0.871, 0.992];
/** Rectángulos UV de la madera y los íconos del cajón. */
export const CRATE_WOOD_RECT: [number, number, number, number] = [0, 0.5, 0.5, 1];
export const CRATE_ICON_RECT: Record<'battery' | 'protection' | 'kit' | 'panel', [number, number, number, number]> = {
  battery: [0, 0.25, 0.25, 0.5],
  protection: [0.25, 0.25, 0.5, 0.5],
  kit: [0.5, 0.25, 0.75, 0.5],
  panel: [0.75, 0.25, 1, 0.5],
};
/** Celdas de fachada en el atlas (8×8 ventanas). */
export const FACADE_TILES = 8;

export interface CanvasTex { texture: THREE.CanvasTexture; canvas: HTMLCanvasElement; ctx: CanvasRenderingContext2D; }

type Draw = (g: CanvasRenderingContext2D, w: number, h: number) => void;

function roundRect(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  r = Math.min(r, w / 2, h / 2);
  g.beginPath();
  g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}

/**
 * Fredoka tiene un kerning "IV" muy negativo (ACTIVAR se lee "ACTVAR"): desactivamos el kerning
 * (ctx.fontKerning) y agregamos algo de tracking (ctx.letterSpacing, Chrome/WebView ≥ 99).
 */
function setSpacing(g: CanvasRenderingContext2D, px: number): void {
  const anyG = g as unknown as { letterSpacing?: string; fontKerning?: string };
  // El problema real es el kerning "IV" de Fredoka: lo apagamos y sumamos un poco de tracking.
  if ('fontKerning' in anyG) anyG.fontKerning = 'none';
  if ('letterSpacing' in anyG) anyG.letterSpacing = px + 'px';
}

export class Textures {
  private cache = new Map<string, THREE.Texture>();
  private labels: { tex: CanvasTex; redraw: () => void }[] = [];
  anisotropy = 4;
  fontsLoaded = false;

  /** Crea un canvas + CanvasTexture (no cacheado). */
  canvas(w: number, h: number, draw: Draw, srgb = true): CanvasTex {
    const canvas = document.createElement('canvas');
    canvas.width = w; canvas.height = h;
    const ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
    draw(ctx, w, h);
    const texture = new THREE.CanvasTexture(canvas);
    if (srgb) texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = this.anisotropy;
    return { texture, canvas, ctx };
  }

  private cached(key: string, w: number, h: number, draw: Draw, repeat = false, srgb = true): THREE.Texture {
    const hit = this.cache.get(key);
    if (hit) return hit;
    const t = this.canvas(w, h, draw, srgb).texture;
    if (repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
    this.cache.set(key, t);
    return t;
  }

  /**
   * Carga las fuentes del juego con FontFace (base = carpeta de fuentes, p.ej. 'fonts/').
   * Al terminar redibuja las etiquetas ya creadas. Nunca falla (sin fuentes usa sans-serif).
   */
  async loadFonts(base = 'fonts/'): Promise<void> {
    if (this.fontsLoaded || typeof FontFace === 'undefined') return;
    const list: [string, string, string][] = [
      [FONT_LABEL, 'fredoka-latin-600-normal.woff2', '600'],
      [FONT_LABEL, 'fredoka-latin-700-normal.woff2', '700'],
      ['Share Tech Mono', 'share-tech-mono-latin-400-normal.woff2', '400'],
    ];
    await Promise.all(list.map(async ([fam, file, weight]) => {
      try {
        const f = new FontFace(fam, `url(${base}${file})`, { weight });
        await f.load();
        (document.fonts as unknown as { add(f: FontFace): void }).add(f);
      } catch { /* sin fuente: fallback */ }
    }));
    this.fontsLoaded = true;
    for (const l of this.labels) l.redraw();
  }

  /* ---------------------------------------------------------------- panel */

  /** Atlas del panel: celdas monocristalinas con busbars y reflejo; franja blanca para el marco. */
  solarPanel(dirty: boolean): THREE.Texture {
    return this.cached('panel:' + dirty, 512, 256, (g, w, h) => {
      const gw = Math.round(w * PANEL_GLASS_RECT[2]);
      g.fillStyle = '#ffffff'; g.fillRect(0, 0, w, h);
      // fondo (backsheet) entre celdas
      g.fillStyle = '#c9d6e3'; g.fillRect(0, 0, gw, h);
      const cols = 10, rows = 6, m = 3;
      const cw = (gw - m * 2) / cols, ch = (h - m * 2) / rows;
      const r = rng(7);
      for (let i = 0; i < cols; i++) for (let j = 0; j < rows; j++) {
        const x = m + i * cw + 1.2, y = m + j * ch + 1.2, ww = cw - 2.4, hh = ch - 2.4;
        const grad = g.createLinearGradient(x, y, x + ww, y + hh);
        const k = 0.9 + r() * 0.12;
        grad.addColorStop(0, `rgb(${Math.round(36 * k)},${Math.round(66 * k)},${Math.round(112 * k)})`);
        grad.addColorStop(1, `rgb(${Math.round(22 * k)},${Math.round(44 * k)},${Math.round(80 * k)})`);
        g.fillStyle = grad;
        // celdas con esquinas en chaflán (mono PERC)
        const c = 4;
        g.beginPath(); g.moveTo(x + c, y); g.lineTo(x + ww - c, y); g.lineTo(x + ww, y + c); g.lineTo(x + ww, y + hh - c);
        g.lineTo(x + ww - c, y + hh); g.lineTo(x + c, y + hh); g.lineTo(x, y + hh - c); g.lineTo(x, y + c); g.closePath(); g.fill();
        // dedos finos
        g.strokeStyle = 'rgba(160,190,220,0.18)'; g.lineWidth = 0.6;
        for (let f = 1; f < 7; f++) { g.beginPath(); g.moveTo(x, y + f * hh / 7); g.lineTo(x + ww, y + f * hh / 7); g.stroke(); }
        // busbars
        g.strokeStyle = 'rgba(215,225,235,0.85)'; g.lineWidth = 1.2;
        for (let b = 1; b <= 3; b++) { const bx = x + b * ww / 4; g.beginPath(); g.moveTo(bx, y); g.lineTo(bx, y + hh); g.stroke(); }
      }
      // reflejo diagonal del vidrio
      const s = g.createLinearGradient(0, 0, gw, h);
      s.addColorStop(0.0, 'rgba(255,255,255,0.0)');
      s.addColorStop(0.32, 'rgba(255,255,255,0.0)');
      s.addColorStop(0.40, 'rgba(255,255,255,0.20)');
      s.addColorStop(0.47, 'rgba(255,255,255,0.05)');
      s.addColorStop(0.55, 'rgba(255,255,255,0.14)');
      s.addColorStop(0.62, 'rgba(255,255,255,0.0)');
      g.fillStyle = s; g.fillRect(0, 0, gw, h);
      if (dirty) {
        const rr = rng(31);
        for (let i = 0; i < 260; i++) {
          const x = rr() * gw, y = rr() * h, rad = 6 + rr() * 26;
          const gg = g.createRadialGradient(x, y, 0, x, y, rad);
          gg.addColorStop(0, `rgba(176,128,70,${0.35 + rr() * 0.3})`); gg.addColorStop(1, 'rgba(176,128,70,0)');
          g.fillStyle = gg; g.fillRect(x - rad, y - rad, rad * 2, rad * 2);
        }
        // acumulación en el borde inferior (v=0 → abajo de la imagen)
        const e = g.createLinearGradient(0, h, 0, h * 0.6);
        e.addColorStop(0, 'rgba(190,140,80,0.9)'); e.addColorStop(1, 'rgba(190,140,80,0)');
        g.fillStyle = e; g.fillRect(0, h * 0.6, gw, h * 0.4);
      }
    });
  }

  /* ---------------------------------------------------------------- superficies */

  concrete(): THREE.Texture {
    return this.cached('concrete', 256, 256, (g, w, h) => {
      g.fillStyle = '#f1efe9'; g.fillRect(0, 0, w, h);
      const r = rng(3);
      for (let i = 0; i < 2600; i++) {
        const v = 200 + Math.floor(r() * 50);
        g.fillStyle = `rgba(${v},${v - 4},${v - 10},${0.25 + r() * 0.4})`;
        g.fillRect(r() * w, r() * h, 1 + r() * 2.5, 1 + r() * 2.5);
      }
      g.strokeStyle = 'rgba(120,115,105,0.35)'; g.lineWidth = 1;
      for (let i = 0; i < 3; i++) {
        let x = r() * w, y = r() * h; g.beginPath(); g.moveTo(x, y);
        for (let k = 0; k < 6; k++) { x += (r() - 0.5) * 40; y += (r() - 0.3) * 30; g.lineTo(x, y); }
        g.stroke();
      }
      // juntas
      g.strokeStyle = 'rgba(110,105,95,0.5)'; g.lineWidth = 2;
      g.beginPath(); g.moveTo(w / 2, 0); g.lineTo(w / 2, h); g.moveTo(0, h / 2); g.lineTo(w, h / 2); g.stroke();
    }, true);
  }

  /** Detalle de tierra (se multiplica por el color de vértice del terreno). */
  soil(): THREE.Texture {
    return this.cached('soil', 256, 256, (g, w, h) => {
      g.fillStyle = '#f4efe6'; g.fillRect(0, 0, w, h);
      const r = rng(11);
      for (let i = 0; i < 70; i++) {
        const x = r() * w, y = r() * h, rad = 10 + r() * 34;
        const gg = g.createRadialGradient(x, y, 0, x, y, rad);
        const d = r() > 0.5 ? '255,250,240' : '205,190,170';
        gg.addColorStop(0, `rgba(${d},0.35)`); gg.addColorStop(1, `rgba(${d},0)`);
        g.fillStyle = gg; g.fillRect(x - rad, y - rad, rad * 2, rad * 2);
      }
      for (let i = 0; i < 1600; i++) {
        const v = 150 + Math.floor(r() * 90);
        g.fillStyle = `rgba(${v},${v - 12},${v - 28},${0.3 + r() * 0.4})`;
        const s = 1 + r() * 2.2; g.fillRect(r() * w, r() * h, s, s);
      }
      // piedritas con luz arriba y sombra abajo
      for (let i = 0; i < 90; i++) {
        const x = r() * w, y = r() * h, s = 1.5 + r() * 2.5;
        g.fillStyle = 'rgba(120,100,80,0.55)'; g.beginPath(); g.ellipse(x + 0.8, y + 1, s, s * 0.7, 0, 0, 7); g.fill();
        g.fillStyle = 'rgba(255,248,235,0.8)'; g.beginPath(); g.ellipse(x, y, s, s * 0.7, 0, 0, 7); g.fill();
      }
    }, true);
  }

  /** Chapa acanalada (techos, tanque). */
  metalSheet(): THREE.Texture {
    return this.cached('sheet', 128, 128, (g, w, h) => {
      for (let x = 0; x < w; x++) {
        const v = Math.round(205 + 45 * Math.sin((x / w) * Math.PI * 2 * 8));
        g.fillStyle = `rgb(${v},${v},${v})`; g.fillRect(x, 0, 1, h);
      }
      const r = rng(5);
      for (let i = 0; i < 300; i++) { g.fillStyle = `rgba(150,140,120,${r() * 0.15})`; g.fillRect(r() * w, r() * h, 2, 4); }
    }, true);
  }

  /** Atlas de cajón: madera (arriba izq.), blanco liso (arriba der.), íconos (fila media). */
  crate(): THREE.Texture {
    return this.cached('crate', 512, 512, (g, w, h) => {
      // nota: canvas y=0 es arriba; en UV v=1 es arriba.
      g.fillStyle = '#ffffff'; g.fillRect(0, 0, w, h);
      // madera (0..256 x 0..256)
      const r = rng(9);
      const planks = 5, ph = 256 / planks;
      for (let i = 0; i < planks; i++) {
        const k = 0.88 + r() * 0.14;
        g.fillStyle = `rgb(${Math.round(222 * k)},${Math.round(176 * k)},${Math.round(116 * k)})`;
        g.fillRect(0, i * ph, 256, ph);
        g.strokeStyle = 'rgba(120,80,40,0.25)'; g.lineWidth = 1;
        for (let l = 0; l < 7; l++) {
          const y0 = i * ph + 3 + r() * (ph - 6);
          g.beginPath(); g.moveTo(0, y0);
          for (let x = 0; x <= 256; x += 32) g.lineTo(x, y0 + Math.sin(x * 0.05 + l) * 1.5);
          g.stroke();
        }
        g.fillStyle = 'rgba(80,50,25,0.55)'; g.fillRect(0, i * ph, 256, 2);
        // clavos
        g.fillStyle = 'rgba(70,60,50,0.8)';
        g.beginPath(); g.arc(14, i * ph + ph / 2, 2.2, 0, 7); g.arc(242, i * ph + ph / 2, 2.2, 0, 7); g.fill();
      }
      g.strokeStyle = 'rgba(80,50,25,0.6)'; g.lineWidth = 6; g.strokeRect(3, 3, 250, 250);
      // íconos (y 256..384 en canvas = v 0.25..0.5)
      const icons: [string, (x: number, y: number) => void][] = [
        ['#3FA34D', (x, y) => { // batería
          g.fillStyle = '#fff'; roundRect(g, x + 30, y + 40, 68, 52, 8); g.fill(); g.fillRect(x + 98, y + 56, 8, 20);
          g.fillStyle = '#3FA34D'; g.fillRect(x + 38, y + 48, 16, 36); g.fillRect(x + 58, y + 48, 16, 36);
        }],
        ['#F28C28', (x, y) => { // protección: escudo con rayo
          g.fillStyle = '#fff'; g.beginPath(); g.moveTo(x + 64, y + 22); g.lineTo(x + 100, y + 36); g.lineTo(x + 96, y + 76);
          g.lineTo(x + 64, y + 106); g.lineTo(x + 32, y + 76); g.lineTo(x + 28, y + 36); g.closePath(); g.fill();
          g.fillStyle = '#F28C28'; g.beginPath(); g.moveTo(x + 70, y + 36); g.lineTo(x + 50, y + 70); g.lineTo(x + 64, y + 70);
          g.lineTo(x + 58, y + 94); g.lineTo(x + 80, y + 58); g.lineTo(x + 66, y + 58); g.closePath(); g.fill();
        }],
        ['#2F7BE0', (x, y) => { // kit anti-Zonda: traba / candado
          g.strokeStyle = '#fff'; g.lineWidth = 10; g.beginPath(); g.arc(x + 64, y + 54, 20, Math.PI, 0); g.stroke();
          g.fillStyle = '#fff'; roundRect(g, x + 34, y + 54, 60, 46, 8); g.fill();
          g.fillStyle = '#2F7BE0'; g.beginPath(); g.arc(x + 64, y + 74, 7, 0, 7); g.fill(); g.fillRect(x + 61, y + 76, 6, 14);
        }],
        ['#1E3A5F', (x, y) => { // panel
          g.fillStyle = '#9FB8D0'; g.fillRect(x + 22, y + 34, 84, 60);
          g.strokeStyle = '#1E3A5F'; g.lineWidth = 3;
          for (let i = 1; i < 4; i++) { g.beginPath(); g.moveTo(x + 22 + i * 21, y + 34); g.lineTo(x + 22 + i * 21, y + 94); g.stroke(); }
          g.beginPath(); g.moveTo(x + 22, y + 64); g.lineTo(x + 106, y + 64); g.stroke();
          g.fillStyle = '#FFB82E'; g.beginPath(); g.arc(x + 98, y + 30, 12, 0, 7); g.fill();
        }],
      ];
      icons.forEach(([bg, fn], i) => {
        const x = i * 128, y = 256;
        g.fillStyle = bg; roundRect(g, x + 6, y + 6, 116, 116, 18); g.fill();
        fn(x, y);
      });
    });
  }

  /**
   * Atlas de fachada 8×8 ventanas (una por celda). kind 'map' = color difuso (pared blanca, vidrio oscuro);
   * 'emissive' = sólo ventanas encendidas (variación aleatoria de tono y de cuáles se prenden).
   */
  facade(kind: 'map' | 'emissive'): THREE.Texture {
    return this.cached('facade:' + kind, 512, 512, (g, w, h) => {
      const n = FACADE_TILES, cs = w / n;
      const r = rng(21);
      g.fillStyle = kind === 'map' ? '#ffffff' : '#000000'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
        const x = i * cs, y = j * cs;
        const wx = x + cs * 0.24, wy = y + cs * 0.2, ww = cs * 0.52, wh = cs * 0.5;
        if (kind === 'map') {
          g.fillStyle = 'rgba(0,0,0,0.10)'; g.fillRect(wx - 3, wy + wh, ww + 6, 4); // alféizar sombra
          g.fillStyle = '#e8e4dc'; g.fillRect(wx - 4, wy - 4, ww + 8, wh + 8); // marco
          const gr = g.createLinearGradient(wx, wy, wx + ww, wy + wh);
          gr.addColorStop(0, '#5d7b93'); gr.addColorStop(0.5, '#3a556d'); gr.addColorStop(1, '#2c4257');
          g.fillStyle = gr; g.fillRect(wx, wy, ww, wh);
          g.fillStyle = 'rgba(255,255,255,0.25)'; g.fillRect(wx + 3, wy + 3, ww * 0.3, wh * 0.18);
          g.fillStyle = '#e8e4dc'; g.fillRect(wx + ww / 2 - 1.5, wy, 3, wh);
        } else {
          const on = r() < 0.62;
          if (on) {
            const warm = r();
            const c = warm < 0.7 ? `rgb(255,${200 + Math.floor(r() * 30)},${110 + Math.floor(r() * 40)})` : 'rgb(220,235,255)';
            g.fillStyle = c; g.fillRect(wx, wy, ww, wh);
            // cortina / silueta para variar
            if (r() < 0.4) { g.fillStyle = 'rgba(0,0,0,0.45)'; g.fillRect(wx, wy, ww * (0.2 + r() * 0.3), wh); }
            g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillRect(wx + ww / 2 - 1.5, wy, 3, wh);
          }
        }
      }
    });
  }

  /** Partícula de polvo suave. */
  dustSprite(): THREE.Texture {
    return this.cached('dust', 64, 64, (g, w, h) => {
      const gg = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
      gg.addColorStop(0, 'rgba(255,255,255,1)'); gg.addColorStop(0.4, 'rgba(255,255,255,0.5)'); gg.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = gg; g.fillRect(0, 0, w, h);
    });
  }

  /* ---------------------------------------------------------------- dinámicas (no cacheadas) */

  /**
   * Frente del inversor: LCD con texto + LEDs + marca. `map` = color, `emissive` = sólo lo que brilla
   * (texto del LCD y LEDs encendidos). draw() redibuja ambos.
   */
  inverterFace(): { map: CanvasTex; emissive: CanvasTex; draw(text: string, color?: string, leds?: [boolean, boolean, boolean]): void } {
    const map = this.canvas(256, 320, () => { /* abajo */ });
    const emissive = this.canvas(256, 320, () => { /* abajo */ });
    const lc = ['#46e06a', '#ffb82e', '#ff4d4d'];
    const draw = (text: string, color = '#5fe3f5', leds: [boolean, boolean, boolean] = [true, false, false]) => {
      const w = 256, h = 320;
      for (const pass of [0, 1]) {
        const g = pass === 0 ? map.ctx : emissive.ctx;
        const glow = pass === 1;
        g.clearRect(0, 0, w, h);
        g.fillStyle = glow ? '#000000' : '#f4f7f6'; g.fillRect(0, 0, w, h);
        g.textAlign = 'center'; g.textBaseline = 'middle';
        if (!glow) {
          g.fillStyle = '#3FA34D'; g.fillRect(0, h - 58, w, 26);
          g.fillStyle = '#0E2420'; g.fillRect(0, h - 32, w, 32);
          g.fillStyle = '#ffffff'; g.font = `700 20px ${FONT_LABEL}, sans-serif`;
          g.fillText('HÍBRIDO 5K', w / 2, h - 15);
          g.fillStyle = '#c9d2d0'; roundRect(g, 26, 34, w - 52, 116, 12); g.fill();
        }
        g.fillStyle = glow ? '#06110f' : '#0b1d1a'; roundRect(g, 34, 42, w - 68, 100, 8); g.fill();
        g.fillStyle = color; g.font = `700 ${text.length > 9 ? 26 : 34}px ${FONT_LABEL}, sans-serif`;
        g.fillText(text, w / 2, 90);
        g.fillStyle = glow ? 'rgba(95,227,245,0.35)' : 'rgba(255,255,255,0.4)'; g.font = `600 14px ${FONT_LABEL}, sans-serif`;
        g.fillText('PV \u25B8 BAT \u25B8 AC', w / 2, 126);
        for (let i = 0; i < 3; i++) {
          const x = 70 + i * 58, y = 190;
          if (!glow) { g.fillStyle = '#d5dcda'; g.beginPath(); g.arc(x, y, 13, 0, 7); g.fill(); }
          g.fillStyle = leds[i] ? lc[i] : (glow ? '#000000' : '#59615f');
          g.beginPath(); g.arc(x, y, 8, 0, 7); g.fill();
        }
        if (!glow) {
          g.fillStyle = '#6b7673'; g.font = `600 13px ${FONT_LABEL}, sans-serif`;
          ['RED', 'BAT', 'FALLA'].forEach((s, i) => g.fillText(s, 70 + i * 58, 218));
        }
      }
      map.texture.needsUpdate = true; emissive.texture.needsUpdate = true;
    };
    // NPOT (256×320): sin mipmaps para que WebGL1 no la redimensione.
    for (const t of [map.texture, emissive.texture]) { t.minFilter = THREE.LinearFilter; t.generateMipmaps = false; }
    draw('STANDBY', '#8fa7a1', [false, false, false]);
    return { map, emissive, draw };
  }

  /**
   * Etiqueta: fondo redondeado + texto Fredoka. Devuelve la textura y su relación de aspecto.
   * Se redibuja sola cuando terminan de cargar las fuentes.
   */
  label(text: string, bg = 'rgba(14,36,32,0.88)', fg = '#ffffff'): { texture: THREE.CanvasTexture; aspect: number } {
    const H = 128, font = `700 64px ${FONT_LABEL}, 'Trebuchet MS', sans-serif`;
    const measure = document.createElement('canvas').getContext('2d') as CanvasRenderingContext2D;
    measure.font = font;
    setSpacing(measure, 2);
    const W = Math.min(1024, Math.ceil(measure.measureText(text).width + 84));
    const tex = this.canvas(W, H, () => { /* abajo */ });
    const redraw = () => {
      const g = tex.ctx;
      g.clearRect(0, 0, W, H);
      g.font = font; g.textAlign = 'center'; g.textBaseline = 'middle';
      setSpacing(g, 2);
      // sombra suave
      g.fillStyle = 'rgba(0,0,0,0.25)'; roundRect(g, 6, 18, W - 12, H - 28, 40); g.fill();
      g.fillStyle = bg; roundRect(g, 4, 10, W - 8, H - 28, 40); g.fill();
      g.strokeStyle = 'rgba(255,255,255,0.35)'; g.lineWidth = 4; roundRect(g, 6, 12, W - 12, H - 32, 38); g.stroke();
      let size = 64;
      while (size > 30 && g.measureText(text).width > W - 70) { size -= 4; g.font = `700 ${size}px ${FONT_LABEL}, sans-serif`; }
      g.fillStyle = fg; g.fillText(text, W / 2, H / 2 - 7);
      tex.texture.needsUpdate = true;
    };
    redraw();
    tex.texture.minFilter = THREE.LinearFilter;
    tex.texture.generateMipmaps = false;
    this.labels.push({ tex, redraw });
    return { texture: tex.texture, aspect: W / H };
  }

  dispose(): void {
    this.cache.forEach((t) => t.dispose());
    this.cache.clear();
  }
}
