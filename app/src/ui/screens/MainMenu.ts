import type { IWallet } from '../../contracts';
import { button, clear, el } from '../dom';
import { fmtInt } from '../format';
import { icon } from '../icons';
import { WalletChip } from '../hud/WalletChip';
import type { IDailyBonus, UiScreen } from '../types';
import { actionButton } from './common';
import { logo } from './logo';

export interface MainMenuDeps {
  wallet: IWallet;
  dailyBonus?: IDailyBonus;
  onPlay(): void;
  onShop(): void;
  onWardrobe(): void;
  onSettings(): void;
}

/** Menú principal: Jugar, Tienda, Vestuario, Ajustes, saldo y bono diario. */
export class MainMenu implements UiScreen {
  readonly root: HTMLDivElement;
  private readonly chip: WalletChip;
  private readonly bonusBox: HTMLDivElement;

  constructor(private readonly deps: MainMenuDeps) {
    this.chip = new WalletChip(deps.wallet, deps.onShop);
    this.bonusBox = el('div', 'mm-bonus');
    const tile = (label: string, ic: Parameters<typeof icon>[0], fn: () => void): HTMLButtonElement =>
      button('mm-tile', [icon(ic, 30), el('span', { text: label })], fn);
    this.root = el('div', 'pg pg-menu', [
      el('header', 'mm-top', [el('div', 'pg-right', [this.chip.root])]),
      el('div', 'mm-main', [
        el('div', 'mm-hero', [
          logo('mm-logo'),
          el('p', { cls: 'mm-tag', text: 'Construí una planta solar híbrida y mantené la ciudad encendida cuando se oculta el sol.' }),
        ]),
        el('div', 'mm-actions', [
          actionButton('Jugar', deps.onPlay, { icon: 'play', big: true, attrs: { 'data-autofocus': true } }),
          el('div', 'mm-tiles', [
            tile('Tienda', 'cart', deps.onShop),
            tile('Vestuario', 'helmet', deps.onWardrobe),
            tile('Ajustes', 'gear', deps.onSettings),
          ]),
          this.bonusBox,
        ]),
      ]),
    ]);
    this.renderBonus();
  }

  onEnter(): void { this.chip.refresh(); this.renderBonus(); }
  dispose(): void { this.chip.dispose(); }

  /** Volver a pintar (ej. después de cambiar de día). */
  refresh(): void { this.onEnter(); }

  private renderBonus(): void {
    const b = this.deps.dailyBonus;
    clear(this.bonusBox);
    this.bonusBox.hidden = !b;
    if (!b) return;
    if (b.available()) {
      this.bonusBox.className = 'mm-bonus is-ready';
      this.bonusBox.append(
        el('span', 'mm-bonus-ic', [icon('gift', 26)]),
        el('span', 'mm-bonus-txt', [el('b', { text: 'Bono diario' }), el('small', { text: `+${fmtInt(b.amount())} Soles` })]),
        actionButton('Reclamar', () => this.claim(), { kind: 'secondary', attrs: { 'data-sfx': 'coin' } }),
      );
    } else {
      this.bonusBox.className = 'mm-bonus';
      this.bonusBox.append(
        el('span', 'mm-bonus-ic', [icon('gift', 26)]),
        el('span', 'mm-bonus-txt', [el('b', { text: 'Bono diario' }), el('small', { text: 'Volvé mañana por más Soles' })]),
      );
    }
  }

  private claim(): void {
    const b = this.deps.dailyBonus;
    if (!b) return;
    const got = b.claim();
    clear(this.bonusBox);
    this.bonusBox.className = 'mm-bonus is-claimed';
    this.bonusBox.append(
      el('span', 'mm-bonus-ic', [icon('check', 26)]),
      el('span', 'mm-bonus-txt', [el('b', { text: got > 0 ? `¡Sumaste ${fmtInt(got)} Soles!` : 'Ya lo reclamaste hoy' }), el('small', { text: 'Volvé mañana por más' })]),
    );
  }
}
