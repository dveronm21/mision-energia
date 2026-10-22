import type { LoadBlock } from '../../contracts';
import { button, clear, el, setText } from '../dom';
import { fmt1 } from '../format';
import { icon } from '../icons';

interface LoadItem { label: string; kw: number; on: boolean; btn: HTMLButtonElement; state: HTMLSpanElement; }

/**
 * "Salvá la ciudad": de noche el jugador apaga cargas NO esenciales para que la batería alcance.
 * Recibe los LoadBlock del nivel (filtra las esenciales) y avisa cada cambio con onToggle(label, encendida).
 */
export class LoadSheddingPanel {
  readonly root: HTMLElement;
  private readonly grid: HTMLDivElement;
  private readonly saving: HTMLSpanElement;
  private items: LoadItem[] = [];

  constructor(host: HTMLElement, private readonly onToggle: (label: string, on: boolean) => void) {
    this.grid = el('div', 'ls-grid');
    this.saving = el('span', 'ls-saving');
    this.root = el('section', { cls: 'hud-shed', attrs: { 'aria-label': 'Salvá la ciudad' }, hidden: true }, [
      el('header', 'ls-head', [icon('city', 22), el('b', { text: 'Salvá la ciudad' }), this.saving]),
      el('p', { cls: 'ls-hint', text: 'Apagá lo que no hace falta para que la batería llegue a la mañana.' }),
      this.grid,
    ]);
    host.appendChild(this.root);
  }

  /** shed = labels que ya están apagadas. */
  setLoads(loads: LoadBlock[], shed: string[] = []): void {
    const byLabel = new Map<string, number>();
    for (const l of loads) if (!l.essential) byLabel.set(l.label, Math.max(byLabel.get(l.label) ?? 0, l.kw));
    clear(this.grid);
    this.items = [];
    byLabel.forEach((kw, label) => {
      const state = el('span', 'ls-state');
      const item: LoadItem = { label, kw, on: !shed.includes(label), btn: null as unknown as HTMLButtonElement, state };
      item.btn = button('ls-switch', [
        el('span', 'ls-knob'),
        el('span', 'ls-txt', [el('b', { text: label }), el('small', { text: `${fmt1(kw)} kW` })]),
        state,
      ], () => { item.on = !item.on; this.paint(item); this.updateSaving(); this.onToggle(label, item.on); },
      { role: 'switch', 'data-sfx': 'beep' });
      this.paint(item);
      this.items.push(item);
      this.grid.appendChild(item.btn);
    });
    this.updateSaving();
  }

  show(): void { this.root.hidden = false; }
  hide(): void { this.root.hidden = true; }
  get visible(): boolean { return !this.root.hidden; }

  private paint(it: LoadItem): void {
    it.btn.setAttribute('aria-checked', String(it.on));
    it.btn.classList.toggle('is-off', !it.on);
    setText(it.state, it.on ? 'Prendido' : 'Apagado');
  }

  private updateSaving(): void {
    const kw = this.items.filter((i) => !i.on).reduce((a, i) => a + i.kw, 0);
    setText(this.saving, kw > 0 ? `Ahorrás ${fmt1(kw)} kW` : '');
  }
}
