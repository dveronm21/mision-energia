import { clear, el, setText } from '../dom';
import { fmtClock } from '../format';
import { icon, type IconName } from '../icons';

/** Alerta grande (viento Zonda) con cuenta regresiva opcional. */
export class AlertBanner {
  readonly root: HTMLDivElement;
  private readonly title: HTMLElement;
  private readonly text: HTMLSpanElement;
  private readonly count: HTMLSpanElement;
  private readonly iconWrap: HTMLSpanElement;

  constructor(host: HTMLElement, private readonly onResize?: (heightPx: number) => void) {
    this.title = el('b', { text: '¡Alerta de viento Zonda!' });
    this.text = el('span', 'al-text');
    this.count = el('span', { cls: 'al-count', hidden: true });
    this.iconWrap = el('span', 'al-icon', [icon('wind', 34)]);
    this.root = el('div', { cls: 'hud-alert', attrs: { role: 'alert' }, hidden: true }, [
      this.iconWrap,
      el('div', 'al-body', [this.title, this.text]),
      this.count,
    ]);
    host.appendChild(this.root);
  }

  /** secondsLeft = null oculta la cuenta regresiva. */
  show(title: string, text: string, secondsLeft: number | null = null, ic: IconName = 'wind'): void {
    setText(this.title, title);
    setText(this.text, text);
    clear(this.iconWrap);
    this.iconWrap.appendChild(icon(ic, 34));
    this.setCountdown(secondsLeft);
    this.root.hidden = false;
    this.onResize?.(this.root.offsetHeight);
  }

  setCountdown(secondsLeft: number | null): void {
    if (secondsLeft === null) { this.count.hidden = true; return; }
    this.count.hidden = false;
    setText(this.count, fmtClock(secondsLeft));
    this.root.classList.toggle('is-urgent', secondsLeft <= 5);
  }

  hide(): void {
    this.root.hidden = true;
    this.onResize?.(0);
  }

  get visible(): boolean { return !this.root.hidden; }
}
