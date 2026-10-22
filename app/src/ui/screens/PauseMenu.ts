import type { IAudio } from '../../contracts';
import { button, el, setText } from '../dom';
import { icon } from '../icons';
import type { UiScreen } from '../types';
import { actionButton } from './common';

export interface PauseDeps {
  audio?: IAudio;
  levelName?: string;
  onResume(): void;
  onRestart(): void;
  onExitToMap(): void;
}

/** Menú de pausa. Reiniciar y Salir piden un segundo toque para confirmar (sin diálogos del sistema). */
export class PauseMenu implements UiScreen {
  readonly root: HTMLDivElement;
  readonly modal = true;
  private armed: 'restart' | 'exit' | null = null;
  private armTimer = 0;
  private readonly restartBtn: HTMLButtonElement;
  private readonly exitBtn: HTMLButtonElement;
  private readonly soundBtn: HTMLButtonElement;

  constructor(private readonly deps: PauseDeps) {
    this.restartBtn = actionButton('Reiniciar nivel', () => this.arm('restart'), { kind: 'secondary', icon: 'retry' });
    this.exitBtn = actionButton('Salir al mapa', () => this.arm('exit'), { kind: 'secondary', icon: 'map' });
    this.soundBtn = button('btn btn-ghost pm-sound', [], () => this.toggleSound());
    this.paintSound();
    const card = el('div', { cls: 'mdl-card pm', attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'pm-title' } }, [
      el('div', 'pm-head', [
        el('span', 'pm-ic', [icon('pause', 26)]),
        el('div', {}, [
          deps.levelName ? el('div', { cls: 'eyebrow', text: deps.levelName }) : null,
          el('h2', { text: 'Pausa', attrs: { id: 'pm-title' } }),
        ]),
      ]),
      actionButton('Seguir jugando', deps.onResume, { icon: 'play', big: true, attrs: { 'data-autofocus': true } }),
      el('div', 'pm-grid', [this.restartBtn, this.exitBtn, deps.audio ? this.soundBtn : null]),
    ]);
    this.root = el('div', 'mdl', [card]);
  }

  onBack(): boolean { this.deps.onResume(); return true; }
  dispose(): void { window.clearTimeout(this.armTimer); }

  private arm(what: 'restart' | 'exit'): void {
    if (this.armed === what) {
      this.disarm();
      if (what === 'restart') this.deps.onRestart(); else this.deps.onExitToMap();
      return;
    }
    this.disarm();
    this.armed = what;
    const b = what === 'restart' ? this.restartBtn : this.exitBtn;
    b.classList.add('is-armed');
    setText(b.querySelector('span') as HTMLElement, 'Tocá otra vez');
    this.armTimer = window.setTimeout(() => this.disarm(), 3500);
  }

  private disarm(): void {
    window.clearTimeout(this.armTimer);
    this.armed = null;
    this.restartBtn.classList.remove('is-armed');
    this.exitBtn.classList.remove('is-armed');
    setText(this.restartBtn.querySelector('span') as HTMLElement, 'Reiniciar nivel');
    setText(this.exitBtn.querySelector('span') as HTMLElement, 'Salir al mapa');
  }

  private toggleSound(): void {
    const a = this.deps.audio;
    if (!a) return;
    a.setMuted(!a.muted());
    this.paintSound();
  }

  private paintSound(): void {
    const muted = this.deps.audio?.muted() ?? false;
    while (this.soundBtn.firstChild) this.soundBtn.removeChild(this.soundBtn.firstChild);
    this.soundBtn.append(icon(muted ? 'mute' : 'sound', 22), el('span', { text: muted ? 'Sonido: apagado' : 'Sonido: prendido' }));
    this.soundBtn.setAttribute('aria-pressed', String(!muted));
  }
}
