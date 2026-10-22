import type { IInventory, IWallet, Product } from '../../contracts';
import { append, button, clear, el, setText } from '../dom';
import { fmtInt } from '../format';
import { icon } from '../icons';
import { WalletChip } from '../hud/WalletChip';
import type { UiScreen } from '../types';
import { actionButton, pageFrame } from './common';

export type CosmeticSlot = 'helmet' | 'vest';

export const DEFAULT_COLORS: Record<CosmeticSlot, string> = { helmet: '#FFB82E', vest: '#F28C28' };

const COLOR_WORDS: [string[], string][] = [
  [['blue', 'azul'], '#2F7FD1'], [['celeste', 'sky', 'cyan'], '#5BC0EB'], [['red', 'rojo'], '#D64541'],
  [['green', 'verde'], '#3FA34D'], [['orange', 'naranja'], '#F28C28'], [['yellow', 'amarillo'], '#FFD23F'],
  [['white', 'blanco'], '#F4F6F5'], [['pink', 'rosa'], '#E86AA6'], [['violet', 'violeta', 'purple', 'lila'], '#8A5CD1'],
  [['black', 'negro'], '#2A2F2E'], [['gold', 'dorado'], '#D4A017'], [['lime', 'lima'], '#9BD13D'],
];

/** Casco o chaleco según el id/ícono del producto. */
export function cosmeticSlot(p: Product): CosmeticSlot | null {
  const s = `${p.id} ${p.icon}`.toLowerCase();
  if (s.includes('helmet') || s.includes('casco')) return 'helmet';
  if (s.includes('vest') || s.includes('chaleco')) return 'vest';
  return null;
}

/** Color CSS de un cosmético deducido de su id ("skin_helmet_blue" → azul). */
export function cosmeticColor(p: Product | string | null, slot: CosmeticSlot = 'helmet'): string {
  if (!p) return DEFAULT_COLORS[slot];
  const id = (typeof p === 'string' ? p : p.id).toLowerCase();
  for (const [words, c] of COLOR_WORDS) if (words.some((w) => id.includes(w))) return c;
  return DEFAULT_COLORS[slot];
}

/** Mismo color como número (0xRRGGBB) para WorkerRig.setCosmetics. */
export function cosmeticColorHex(id: string | null, slot: CosmeticSlot): number {
  return parseInt(cosmeticColor(id, slot).slice(1), 16);
}

export interface WardrobeDeps {
  catalog: Product[];
  inventory: IInventory;
  wallet?: IWallet;
  onBack(): void;
  onShop?(): void;
  /** Se llama al equipar (para actualizar el personaje 3D). */
  onEquip?(slot: CosmeticSlot, productId: string | null): void;
}

const NS = 'http://www.w3.org/2000/svg';
function svgEl(tag: string, attrs: Record<string, string | number>): SVGElement {
  const n = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, String(v));
  return n;
}

/** Vestuario: colores de casco y chaleco, con vista previa. */
export class WardrobeScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private readonly chip: WalletChip | null;
  private readonly lists: Record<CosmeticSlot, HTMLDivElement>;
  private readonly helmetParts: SVGElement[] = [];
  private readonly vestParts: SVGElement[] = [];
  private readonly info: HTMLDivElement;
  private readonly previewName: HTMLDivElement;

  constructor(private readonly deps: WardrobeDeps) {
    this.chip = deps.wallet ? new WalletChip(deps.wallet, deps.onShop) : null;
    this.lists = { helmet: el('div', { cls: 'wr-swatches', attrs: { role: 'radiogroup', 'aria-label': 'Color del casco' } }), vest: el('div', { cls: 'wr-swatches', attrs: { role: 'radiogroup', 'aria-label': 'Color del chaleco' } }) };
    this.info = el('div', { cls: 'wr-info', attrs: { 'aria-live': 'polite' } });
    this.previewName = el('div', 'wr-name');
    const frame = pageFrame({
      title: 'Vestuario', onBack: deps.onBack, right: this.chip ? [this.chip.root] : [],
      body: [el('div', 'wr-grid', [
        el('div', 'wr-preview', [this.buildPreview(), this.previewName, this.info]),
        el('div', 'wr-options', [
          el('section', 'wr-sec', [el('h2', {}, [icon('helmet', 22), el('span', { text: 'Casco' })]), this.lists.helmet]),
          el('section', 'wr-sec', [el('h2', {}, [icon('vest', 22), el('span', { text: 'Chaleco' })]), this.lists.vest]),
        ]),
      ])],
      cls: 'pg-wardrobe',
    });
    this.root = frame.root;
    this.render();
  }

  onEnter(): void { this.chip?.refresh(); this.render(); }
  onBack(): boolean { this.deps.onBack(); return true; }
  dispose(): void { this.chip?.dispose(); }

  private items(slot: CosmeticSlot): Product[] {
    return this.deps.catalog.filter((p) => p.kind === 'cosmetic' && cosmeticSlot(p) === slot);
  }

  private render(): void {
    for (const slot of ['helmet', 'vest'] as CosmeticSlot[]) {
      const list = this.lists[slot];
      clear(list);
      const eq = this.deps.inventory.equippedCosmetic(slot);
      list.appendChild(this.swatch(slot, null, 'Clásico', DEFAULT_COLORS[slot], true, eq === null));
      for (const p of this.items(slot)) {
        list.appendChild(this.swatch(slot, p, p.title, cosmeticColor(p, slot), this.deps.inventory.count(p.id) > 0, eq === p.id));
      }
    }
    this.paintPreview(
      cosmeticColor(this.deps.inventory.equippedCosmetic('helmet'), 'helmet'),
      cosmeticColor(this.deps.inventory.equippedCosmetic('vest'), 'vest'),
    );
  }

  private swatch(slot: CosmeticSlot, p: Product | null, name: string, color: string, owned: boolean, on: boolean): HTMLElement {
    const dot = el('span', 'wr-dot');
    dot.style.background = color;
    const b = button(`wr-sw${on ? ' is-on' : ''}${owned ? '' : ' is-locked'}`, [
      dot,
      on ? el('span', 'wr-badge', [icon('check', 16)]) : null,
      owned ? null : el('span', 'wr-badge is-lock', [icon('lock', 14)]),
      el('span', { cls: 'wr-label', text: name }),
    ], () => {
      if (owned) {
        this.deps.inventory.equip(slot, p ? p.id : null);
        this.deps.onEquip?.(slot, p ? p.id : null);
        clear(this.info);
        this.render();
      } else if (p) {
        this.paintPreview(slot === 'helmet' ? color : this.currentColor('helmet'), slot === 'vest' ? color : this.currentColor('vest'));
        setText(this.previewName, `Vista previa: ${p.title}`);
        clear(this.info);
        append(this.info, [
          el('span', { text: `Cuesta ${fmtInt(p.costSoles ?? 0)} Soles en la tienda.` }),
          this.deps.onShop ? actionButton('Ir a la tienda', () => this.deps.onShop?.(), { kind: 'secondary', icon: 'cart' }) : null,
        ]);
      }
    }, { role: 'radio', 'aria-checked': String(on), 'aria-label': `${name}${owned ? '' : ' (bloqueado)'}` });
    return b;
  }

  private currentColor(slot: CosmeticSlot): string {
    return cosmeticColor(this.deps.inventory.equippedCosmetic(slot), slot);
  }

  private paintPreview(helmet: string, vest: string): void {
    this.helmetParts.forEach((n) => n.setAttribute('fill', helmet));
    this.vestParts.forEach((n) => n.setAttribute('fill', vest));
    setText(this.previewName, 'Tu técnico');
  }

  /** Busto simple del técnico (SVG) con casco y chaleco coloreables. */
  private buildPreview(): SVGSVGElement {
    const svg = svgEl('svg', { viewBox: '0 0 200 220', class: 'wr-svg', role: 'img', 'aria-label': 'Vista previa del técnico' }) as SVGSVGElement;
    const ink = '#10231F';
    svg.appendChild(svgEl('circle', { cx: 100, cy: 112, r: 96, fill: '#1F3D37' }));
    // Remera y brazos
    svg.appendChild(svgEl('path', { d: 'M38 220 C40 168 62 146 100 146 C138 146 160 168 162 220 Z', fill: '#3C6E9E', stroke: ink, 'stroke-width': 4 }));
    // Chaleco
    const vest = svgEl('path', { d: 'M56 220 C58 178 70 156 86 150 L100 182 L114 150 C130 156 142 178 144 220 Z', stroke: ink, 'stroke-width': 4, 'stroke-linejoin': 'round' });
    this.vestParts.push(vest);
    svg.appendChild(vest);
    svg.appendChild(svgEl('path', { d: 'M62 196 H88 M112 196 H138', stroke: '#E6EEEC', 'stroke-width': 7, 'stroke-linecap': 'round' }));
    // Cuello y cabeza
    svg.appendChild(svgEl('rect', { x: 88, y: 128, width: 24, height: 24, rx: 8, fill: '#C98A5E', stroke: ink, 'stroke-width': 4 }));
    svg.appendChild(svgEl('circle', { cx: 100, cy: 102, r: 34, fill: '#E2A878', stroke: ink, 'stroke-width': 4 }));
    svg.appendChild(svgEl('circle', { cx: 88, cy: 106, r: 4, fill: ink }));
    svg.appendChild(svgEl('circle', { cx: 112, cy: 106, r: 4, fill: ink }));
    svg.appendChild(svgEl('path', { d: 'M90 120 Q100 128 110 120', fill: 'none', stroke: ink, 'stroke-width': 4, 'stroke-linecap': 'round' }));
    // Casco
    const dome = svgEl('path', { d: 'M60 94 C60 58 78 42 100 42 C122 42 140 58 140 94 Z', stroke: ink, 'stroke-width': 4, 'stroke-linejoin': 'round' });
    const brim = svgEl('rect', { x: 52, y: 88, width: 96, height: 12, rx: 6, stroke: ink, 'stroke-width': 4 });
    this.helmetParts.push(dome, brim);
    svg.appendChild(dome);
    svg.appendChild(brim);
    svg.appendChild(svgEl('path', { d: 'M100 44 V86 M84 50 L88 86 M116 50 L112 86', stroke: 'rgba(16,35,31,.35)', 'stroke-width': 4, 'stroke-linecap': 'round', fill: 'none' }));
    return svg;
  }
}
