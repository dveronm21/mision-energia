import type { IWallet } from '../../contracts';
import { el, prefersReducedMotion, setText } from '../dom';
import { fmtInt } from '../format';
import { icon } from '../icons';

/**
 * Saldo de Soles. Se suscribe a la billetera; al sumar anima el contador y muestra "+N".
 * Si se pasa onClick (ej. abrir la tienda) se renderiza como botón con un "+".
 */
export class WalletChip {
  readonly root: HTMLElement;
  private readonly num: HTMLSpanElement;
  private shown: number;
  private raf = 0;
  private readonly unsub: () => void;

  constructor(private readonly wallet: IWallet, onClick?: () => void) {
    this.shown = wallet.balance();
    this.num = el('span', { cls: 'wc-num', text: fmtInt(this.shown) });
    const kids = [el('span', 'wc-ic', [icon('soles', 22)]), this.num, el('span', { cls: 'wc-sr', text: ' Soles' })];
    if (onClick) {
      this.root = el('button', { cls: 'wallet-chip is-btn', attrs: { type: 'button', 'aria-label': 'Soles: abrir la tienda' }, on: { click: onClick } },
        [...kids, el('span', 'wc-plus', [icon('plus', 16)])]);
    } else {
      this.root = el('div', { cls: 'wallet-chip', attrs: { role: 'status' } }, kids);
    }
    this.unsub = wallet.onChange((b) => this.animateTo(b));
  }

  refresh(): void { this.animateTo(this.wallet.balance()); }

  dispose(): void { this.unsub(); cancelAnimationFrame(this.raf); }

  private animateTo(target: number): void {
    const from = this.shown;
    const delta = target - from;
    cancelAnimationFrame(this.raf);
    if (delta === 0) return;
    if (delta > 0) this.floatDelta(delta);
    if (prefersReducedMotion() || delta < 0) { this.shown = target; setText(this.num, fmtInt(target)); return; }
    this.root.classList.remove('is-bump');
    void this.root.offsetWidth;
    this.root.classList.add('is-bump');
    const t0 = performance.now();
    const dur = Math.min(900, 300 + delta * 4);
    const step = (now: number): void => {
      const k = Math.min(1, (now - t0) / dur);
      const e = 1 - Math.pow(1 - k, 3);
      this.shown = Math.round(from + delta * e);
      setText(this.num, fmtInt(this.shown));
      if (k < 1) this.raf = requestAnimationFrame(step);
    };
    this.raf = requestAnimationFrame(step);
  }

  private floatDelta(delta: number): void {
    const f = el('span', { cls: 'wc-float', text: `+${fmtInt(delta)}`, attrs: { 'aria-hidden': 'true' } });
    this.root.appendChild(f);
    window.setTimeout(() => f.remove(), 1100);
  }
}
