import type { IAudio, QualityLevel } from '../../contracts';
import { button, clear, el } from '../dom';
import { icon } from '../icons';
import type { UiScreen } from '../types';
import { actionButton, pageFrame } from './common';

export interface SettingsDeps {
  quality: QualityLevel;
  audio?: IAudio;
  version: string;
  onQualityChange(q: QualityLevel): void;
  onResetProgress(): void;
  onBack(): void;
}

const CONFIRM_WORD = 'BORRAR';

/** Ajustes: calidad gráfica, sonido, reinicio de progreso con confirmación escrita, versión y créditos. */
export class SettingsScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private quality: QualityLevel;
  private readonly qBtns = new Map<QualityLevel, HTMLButtonElement>();
  private readonly soundBtn: HTMLButtonElement;
  private readonly resetBox: HTMLDivElement;

  constructor(private readonly deps: SettingsDeps) {
    this.quality = deps.quality;
    const seg = el('div', { cls: 'seg', attrs: { role: 'radiogroup', 'aria-label': 'Calidad gráfica' } });
    for (const [q, label] of [['low', 'Baja'], ['medium', 'Media'], ['high', 'Alta']] as [QualityLevel, string][]) {
      const b = button('seg-btn', [el('span', { text: label })], () => this.setQuality(q), { role: 'radio' });
      this.qBtns.set(q, b);
      seg.appendChild(b);
    }
    this.soundBtn = button('switch', [el('span', 'switch-knob')], () => this.toggleSound(), { role: 'switch', 'aria-label': 'Sonido' });
    this.resetBox = el('div', 'set-reset');

    const row = (ic: Parameters<typeof icon>[0], title: string, sub: string, control: HTMLElement): HTMLElement =>
      el('div', 'set-row', [el('span', 'set-ic', [icon(ic, 24)]), el('div', 'set-txt', [el('b', { text: title }), el('small', { text: sub })]), control]);

    const frame = pageFrame({
      title: 'Ajustes', onBack: deps.onBack,
      body: [el('div', 'set-list', [
        row('gear', 'Calidad gráfica', 'Si el juego va lento, probá con Baja.', seg),
        deps.audio ? row('sound', 'Sonido', 'Efectos y viento.', this.soundBtn) : null,
        this.resetBox,
        el('div', 'set-about', [
          el('span', { text: `Misión Energía · versión ${deps.version}` }),
          el('span', { text: 'Hecho por Inkfusion · San Juan' }),
        ]),
      ])],
      cls: 'pg-settings',
    });
    this.root = frame.root;
    this.paintQuality();
    this.paintSound();
    this.renderReset(false);
  }

  onBack(): boolean { this.deps.onBack(); return true; }

  private setQuality(q: QualityLevel): void {
    this.quality = q;
    this.paintQuality();
    this.deps.onQualityChange(q);
  }

  private paintQuality(): void {
    this.qBtns.forEach((b, q) => { b.setAttribute('aria-checked', String(q === this.quality)); b.classList.toggle('is-on', q === this.quality); });
  }

  private toggleSound(): void {
    const a = this.deps.audio;
    if (!a) return;
    a.setMuted(!a.muted());
    this.paintSound();
  }

  private paintSound(): void {
    const on = !(this.deps.audio?.muted() ?? false);
    this.soundBtn.setAttribute('aria-checked', String(on));
    this.soundBtn.classList.toggle('is-on', on);
  }

  private renderReset(open: boolean): void {
    clear(this.resetBox);
    const head = el('div', 'set-row', [
      el('span', 'set-ic is-danger', [icon('retry', 24)]),
      el('div', 'set-txt', [el('b', { text: 'Reiniciar progreso' }), el('small', { text: 'Borra niveles, estrellas, Soles y compras guardadas.' })]),
      open ? null : actionButton('Reiniciar', () => this.renderReset(true), { kind: 'ghost' }),
    ]);
    this.resetBox.appendChild(head);
    if (!open) return;
    const input = el('input', {
      cls: 'set-input',
      attrs: { type: 'text', id: 'set-confirm', autocomplete: 'off', autocapitalize: 'characters', spellcheck: 'false', maxlength: 12, placeholder: CONFIRM_WORD },
    });
    const go = actionButton('Borrar todo', () => {
      if (input.value.trim().toUpperCase() !== CONFIRM_WORD) return;
      this.deps.onResetProgress();
      clear(this.resetBox);
      this.resetBox.appendChild(el('div', 'set-row', [el('span', 'set-ic', [icon('check', 24)]), el('div', 'set-txt', [el('b', { text: 'Progreso reiniciado' }), el('small', { text: 'Empezás de cero.' })])]));
    }, { kind: 'danger' });
    go.disabled = true;
    input.addEventListener('input', () => { go.disabled = input.value.trim().toUpperCase() !== CONFIRM_WORD; });
    this.resetBox.appendChild(el('div', 'set-confirm', [
      el('label', { attrs: { for: 'set-confirm' } }, ['Para confirmar escribí ', el('b', { text: CONFIRM_WORD })]),
      el('div', 'set-confirm-row', [input, actionButton('Cancelar', () => this.renderReset(false), { kind: 'ghost' }), go]),
    ]));
    input.focus();
  }
}
