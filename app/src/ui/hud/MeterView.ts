import { el, setText } from '../dom';
import type { MeterState } from '../types';

/** Multímetro con display LCD. */
export class MeterView {
  readonly root: HTMLDivElement;
  private readonly value: HTMLDivElement;
  private readonly unit: HTMLDivElement;
  private readonly note: HTMLDivElement;

  constructor(host: HTMLElement) {
    this.value = el('div', { cls: 'mt-value', text: '--- V' });
    this.unit = el('div', { cls: 'mt-unit', text: 'V⎓ CC' });
    this.note = el('div', { cls: 'mt-note', text: 'Acercate a la caja de conexión o a un panel y tocá Medir.' });
    this.root = el('div', { cls: 'hud-meter', attrs: { 'aria-live': 'polite', 'aria-label': 'Multímetro' }, hidden: true }, [
      el('div', 'mt-screen', [this.value, this.unit]),
      this.note,
    ]);
    host.appendChild(this.root);
  }

  show(): void { this.root.hidden = false; }
  hide(): void { this.root.hidden = true; }
  get visible(): boolean { return !this.root.hidden; }

  /** value: "38,4 V" o "--- V"; unit: "V⎓ CC"; note: explicación breve. */
  set(value: string, unit: string, note: string, state: MeterState = 'idle'): void {
    setText(this.value, value);
    setText(this.unit, unit);
    setText(this.note, note);
    this.root.classList.toggle('is-ok', state === 'ok');
    this.root.classList.toggle('is-bad', state === 'bad');
  }
}
