import { button, el, setText } from '../dom';
import { icon } from '../icons';
import type { InspectInfo } from '../types';

/** Ficha de "Revisar": qué es el equipo y cómo está funcionando (dato en vivo opcional). */
export class InspectCard {
  readonly root: HTMLDivElement;
  private readonly title: HTMLHeadingElement;
  private readonly body: HTMLParagraphElement;
  private readonly live: HTMLDivElement;

  constructor(host: HTMLElement, private readonly onClose?: () => void) {
    this.title = el('h2', { attrs: { id: 'ins-title' } });
    this.body = el('p');
    this.live = el('div', { cls: 'ins-live', hidden: true });
    const close = button('ins-close', [icon('close', 22)], () => { this.hide(); this.onClose?.(); }, { 'aria-label': 'Cerrar ficha' });
    this.root = el('div', { cls: 'hud-inspect', attrs: { role: 'dialog', 'aria-labelledby': 'ins-title' }, hidden: true }, [
      el('div', 'ins-head', [this.title, close]), el('div', 'ins-scroll', [this.body, this.live]),
    ]);
    host.appendChild(this.root);
  }

  show(info: InspectInfo): void {
    setText(this.title, info.title);
    setText(this.body, info.body);
    this.updateLive(info.live ?? null);
    this.root.hidden = false;
  }

  updateLive(text: string | null): void {
    this.live.hidden = !text;
    if (text) setText(this.live, text);
  }

  hide(): void { this.root.hidden = true; }
  get visible(): boolean { return !this.root.hidden; }
}
