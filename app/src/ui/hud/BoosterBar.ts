import { button, clear, el } from '../dom';
import { icon, resolveIcon } from '../icons';
import type { BoosterSlot } from '../types';

/** Boosters disponibles en la partida (pista, dron limpiador, batería de emergencia) con cantidad. */
export class BoosterBar {
  readonly root: HTMLDivElement;
  private lastKey = '';

  constructor(host: HTMLElement, private readonly onUse: (boosterId: string) => void) {
    this.root = el('div', { cls: 'hud-boosters', attrs: { role: 'toolbar', 'aria-label': 'Ayudas' }, hidden: true });
    host.appendChild(this.root);
  }

  setBoosters(slots: BoosterSlot[]): void {
    const key = slots.map((s) => `${s.id}:${s.count}`).join(',');
    if (key === this.lastKey) return;
    this.lastKey = key;
    clear(this.root);
    for (const s of slots) {
      const b = button('bst-btn', [icon(resolveIcon(s.icon), 26), el('span', { cls: 'bst-count', text: String(s.count) })],
        () => this.onUse(s.id), { 'aria-label': `${s.label} (te quedan ${s.count})`, title: s.label, 'data-sfx': 'ok' });
      b.disabled = s.count <= 0;
      this.root.appendChild(b);
    }
    this.root.hidden = slots.length === 0;
  }
}
