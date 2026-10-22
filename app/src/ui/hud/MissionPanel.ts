import { button, clear, el, setText } from '../dom';
import { fmtClock } from '../format';
import { icon } from '../icons';
import type { MissionObjective } from '../types';

/**
 * Panel de misión (arriba a la izquierda). Colapsable. En pantallas bajas el CSS sólo deja ver
 * el paso actual (now) y las alertas.
 */
export class MissionPanel {
  readonly root: HTMLElement;
  private readonly title: HTMLHeadingElement;
  private readonly timer: HTMLSpanElement;
  private readonly list: HTMLUListElement;
  private readonly toggle: HTMLButtonElement;
  private collapsed = false;
  private lastKey = '';

  constructor(host: HTMLElement, opts: { onToggle?: (collapsed: boolean) => void } = {}) {
    this.title = el('h2', { cls: 'mis-title', text: 'Misión' });
    this.timer = el('span', { cls: 'mis-timer', text: '0:00', attrs: { 'aria-label': 'Tiempo de juego' } });
    this.toggle = button('mis-toggle', [icon('back', 20)], () => {
      this.setCollapsed(!this.collapsed);
      opts.onToggle?.(this.collapsed);
    }, { 'aria-expanded': 'true', 'aria-label': 'Ocultar objetivos' });
    this.list = el('ul', 'mis-list');
    this.root = el('section', { cls: 'hud-mission', attrs: { 'aria-label': 'Misión' } }, [
      el('header', 'mis-head', [this.title, this.timer, this.toggle]),
      this.list,
    ]);
    host.appendChild(this.root);
  }

  setTitle(text: string): void { setText(this.title, text); }
  setTimer(seconds: number): void { setText(this.timer, fmtClock(seconds)); }
  setTimerVisible(on: boolean): void { this.timer.hidden = !on; }

  setObjectives(items: MissionObjective[]): void {
    const key = items.map((i) => `${i.state}|${i.text}`).join('\n');
    if (key === this.lastKey) return;
    this.lastKey = key;
    clear(this.list);
    for (const it of items) {
      const li = el('li', `mis-item is-${it.state}`, [el('span', { cls: 'mis-dot', attrs: { 'aria-hidden': 'true' } }), el('span', { text: it.text })]);
      if (it.state === 'now') li.setAttribute('aria-current', 'step');
      this.list.appendChild(li);
    }
  }

  setCollapsed(c: boolean): void {
    this.collapsed = c;
    this.root.classList.toggle('is-collapsed', c);
    this.toggle.setAttribute('aria-expanded', String(!c));
    this.toggle.setAttribute('aria-label', c ? 'Ver objetivos' : 'Ocultar objetivos');
  }
}
