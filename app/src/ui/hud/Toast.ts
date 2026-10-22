import { el, setText } from '../dom';
import type { ToastKind } from '../types';

/** Aviso breve arriba al centro. Uno a la vez; el nuevo reemplaza al anterior. */
export class Toast {
  readonly root: HTMLDivElement;
  private timer = 0;

  constructor(host: HTMLElement) {
    this.root = el('div', { cls: 'ui-toast', attrs: { role: 'status', 'aria-live': 'polite' }, hidden: true });
    host.appendChild(this.root);
  }

  show(text: string, kind: ToastKind = 'info', ms = 2600): void {
    window.clearTimeout(this.timer);
    setText(this.root, text);
    this.root.className = `ui-toast is-${kind}`;
    this.root.hidden = false;
    this.timer = window.setTimeout(() => this.hide(), ms);
  }

  hide(): void {
    window.clearTimeout(this.timer);
    this.root.hidden = true;
  }
}
