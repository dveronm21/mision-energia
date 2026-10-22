import type { IAudio } from '../../contracts';
import { el } from '../dom';
import { icon } from '../icons';
import type { UiScreen } from '../types';
import { logo } from './logo';

/** Pantalla inicial: logo + "Tocá para empezar". El primer toque desbloquea el audio. */
export class SplashScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private done = false;

  constructor(private readonly deps: { audio?: IAudio; version?: string; onStart: () => void }) {
    const go = (): void => {
      if (this.done) return;
      this.done = true;
      try { this.deps.audio?.unlock(); } catch { /* sin audio */ }
      this.deps.onStart();
    };
    const tap = el('button', {
      cls: 'splash-tap', attrs: { type: 'button', 'data-autofocus': true, 'data-sfx': 'none' }, on: { click: go },
    }, [icon('play', 22), el('span', { text: 'Tocá para empezar' })]);
    this.root = el('div', { cls: 'splash', on: { pointerup: go } }, [
      el('div', 'splash-rays', []),
      el('div', 'splash-center', [
        logo('splash-logo'),
        el('p', { cls: 'splash-tag', text: 'Armá tu planta solar y mantené la ciudad encendida día y noche.' }),
        tap,
      ]),
      el('div', { cls: 'splash-foot', text: `Inkfusion · San Juan${deps.version ? ` · v${deps.version}` : ''}` }),
    ]);
  }
}
