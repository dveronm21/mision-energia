import type { IParentalGate } from '../../contracts';
import { button, el, setText } from '../dom';
import { icon } from '../icons';
import type { ScreenManager } from '../ScreenManager';
import type { UiScreen } from '../types';

/**
 * Control parental antes de pagar con dinero real: multiplicación con teclado numérico propio.
 * Uso típico: `const ok = await ParentalGateModal.ask(ui.screens, gate);`
 */
export class ParentalGateModal implements UiScreen {
  readonly root: HTMLDivElement;
  readonly modal = true;
  private readonly q: HTMLDivElement;
  private readonly display: HTMLOutputElement;
  private readonly msg: HTMLDivElement;
  private answer = 0;
  private typed = '';
  private fails = 0;

  constructor(private readonly gate: IParentalGate, private readonly cb: { onPass(): void; onCancel(): void }) {
    this.q = el('div', { cls: 'pgm-q', attrs: { id: 'pgm-q' } });
    this.display = el('output', { cls: 'pgm-display', attrs: { 'aria-live': 'polite', 'aria-labelledby': 'pgm-q' } });
    this.msg = el('div', { cls: 'pgm-msg', attrs: { 'aria-live': 'polite' } });
    const keys = el('div', { cls: 'pgm-keys', attrs: { role: 'group', 'aria-label': 'Teclado numérico' } });
    for (const k of ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'ok']) {
      if (k === 'del') keys.appendChild(button('pgm-key is-fn', [icon('back', 24)], () => this.del(), { 'aria-label': 'Borrar' }));
      else if (k === 'ok') keys.appendChild(button('pgm-key is-ok', [icon('check', 26)], () => this.submit(), { 'aria-label': 'Confirmar' }));
      else keys.appendChild(button('pgm-key', [k], () => this.type(k), { 'data-sfx': 'beep' }));
    }
    const card = el('div', { cls: 'mdl-card pgm', attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'pgm-title' } }, [
      el('div', 'pgm-left', [
        el('div', { cls: 'eyebrow', text: 'Sólo personas adultas' }),
        el('h2', { cls: 'pgm-title', text: 'Pedile ayuda a un adulto', attrs: { id: 'pgm-title' } }),
        this.q, this.display, this.msg,
        button('btn btn-ghost pgm-cancel', [el('span', { text: 'Cancelar' })], () => this.cb.onCancel(), { 'data-autofocus': true }),
      ]),
      keys,
    ]);
    this.root = el('div', 'mdl', [card]);
    this.root.addEventListener('keydown', (e) => {
      if (/^[0-9]$/.test(e.key)) this.type(e.key);
      else if (e.key === 'Backspace') this.del();
      else if (e.key === 'Enter') this.submit();
      else if (e.key === 'Escape') this.cb.onCancel();
    });
    this.newQuestion();
  }

  static ask(screens: ScreenManager, gate: IParentalGate): Promise<boolean> {
    return new Promise((resolve) => {
      const m: ParentalGateModal = new ParentalGateModal(gate, {
        onPass: () => { screens.remove(m); resolve(true); },
        onCancel: () => { screens.remove(m); resolve(false); },
      });
      screens.push(m);
    });
  }

  onBack(): boolean { this.cb.onCancel(); return true; }

  private newQuestion(): void {
    const c = this.gate.challenge();
    this.answer = c.answer;
    setText(this.q, c.question);
    this.typed = '';
    this.paint();
  }

  private type(k: string): void {
    if (this.typed.length >= 3) return;
    this.typed += k;
    setText(this.msg, '');
    this.paint();
  }

  private del(): void { this.typed = this.typed.slice(0, -1); this.paint(); }

  private submit(): void {
    if (!this.typed) return;
    if (Number(this.typed) === this.answer) { this.cb.onPass(); return; }
    this.fails++;
    this.root.querySelector('.pgm')?.classList.remove('is-shake');
    void this.root.offsetWidth;
    this.root.querySelector('.pgm')?.classList.add('is-shake');
    if (this.fails >= 3) { this.fails = 0; setText(this.msg, 'Probemos con otra cuenta.'); this.newQuestion(); setText(this.msg, 'Probemos con otra cuenta.'); }
    else { setText(this.msg, 'No es correcto. Probá de nuevo.'); this.typed = ''; this.paint(); }
  }

  private paint(): void {
    setText(this.display, this.typed || '?');
    this.display.classList.toggle('is-empty', !this.typed);
  }
}
