import type { IAudio } from '../contracts';
import { el } from './dom';
import { ScreenManager } from './ScreenManager';
import { UI_CSS } from './styles';
import { Toast } from './hud/Toast';
import type { ToastKind } from './types';

export interface UiRootOptions {
  /** Si se pasa, cada botón de la UI hace "click" (salvo data-sfx="none" o data-sfx="<otro>"). */
  audio?: IAudio;
}

const STYLE_ID = 'me-ui-styles';

/**
 * Raíz de la UI: inyecta el CSS, crea las capas (HUD, pantallas, avisos) y expone el ScreenManager.
 * Capas (de abajo hacia arriba): hudLayer → screens → topLayer (toast).
 */
export class UiRoot {
  readonly root: HTMLElement;
  readonly hudLayer: HTMLDivElement;
  readonly screenLayer: HTMLDivElement;
  readonly topLayer: HTMLDivElement;
  readonly screens: ScreenManager;
  readonly toast: Toast;
  private readonly audio?: IAudio;

  constructor(host: HTMLElement, opts: UiRootOptions = {}) {
    UiRoot.injectStyles();
    this.audio = opts.audio;
    this.root = host;
    host.classList.add('ui-root');
    this.hudLayer = el('div', { cls: 'ui-layer ui-hud', hidden: true });
    this.screenLayer = el('div', { cls: 'ui-layer ui-screens' });
    this.topLayer = el('div', { cls: 'ui-layer ui-top' });
    host.append(this.hudLayer, this.screenLayer, this.topLayer);
    this.screens = new ScreenManager(this.screenLayer);
    this.toast = new Toast(this.topLayer);
    host.addEventListener('click', this.onClickSfx);
    // Evita el menú contextual por toque largo dentro de la UI.
    host.addEventListener('contextmenu', (e) => {
      const t = e.target as HTMLElement | null;
      if (!t || !t.closest('input,textarea')) e.preventDefault();
    });
  }

  /** Inyecta el CSS de la UI una sola vez (idempotente). */
  static injectStyles(doc: Document = document): void {
    if (doc.getElementById(STYLE_ID)) return;
    const style = doc.createElement('style');
    style.id = STYLE_ID;
    style.textContent = UI_CSS;
    doc.head.appendChild(style);
  }

  /** Muestra/oculta el HUD de juego. En modo HUD los avisos se ubican entre los paneles superiores. */
  setHudVisible(on: boolean): void {
    this.hudLayer.hidden = !on;
    this.root.classList.toggle('hud-mode', on);
  }

  showToast(text: string, kind: ToastKind = 'info', ms?: number): void {
    this.toast.show(text, kind, ms);
  }

  /** Para el botón atrás de Android: true si una pantalla lo consumió. */
  handleBack(): boolean { return this.screens.handleBack(); }

  private onClickSfx = (e: MouseEvent): void => {
    if (!this.audio) return;
    const b = (e.target as HTMLElement | null)?.closest('button');
    if (!b || b.disabled) return;
    const sfx = b.getAttribute('data-sfx');
    if (sfx === 'none') return;
    this.audio.play((sfx as Parameters<IAudio['play']>[0]) || 'click');
  };
}
