import { button, el, setText } from '../dom';
import { icon } from '../icons';
import type { ActionState } from '../types';

export interface ActionButtonsCallbacks {
  onAction(): void;
  onInspect(): void;
  onMeter(): void;
  onPause(): void;
}

/**
 * Botonera derecha: acción contextual grande, Revisar, Multímetro; y botón de pausa arriba a la derecha.
 */
export class ActionButtons {
  readonly root: HTMLDivElement;
  readonly pauseButton: HTMLButtonElement;
  private readonly act: HTMLButtonElement;
  private readonly actLabel: HTMLSpanElement;
  private readonly inspect: HTMLButtonElement;
  private readonly meter: HTMLButtonElement;

  constructor(host: HTMLElement, cb: ActionButtonsCallbacks) {
    this.meter = button('hud-round', [el('span', 'hr-circle', [icon('meter', 26)]), el('span', { cls: 'hr-cap', text: 'Multímetro' })], () => cb.onMeter(),
      { 'aria-pressed': 'false', 'aria-label': 'Sacar o guardar el multímetro', 'data-sfx': 'pick' });
    this.inspect = button('hud-round', [el('span', 'hr-circle', [icon('search', 26)]), el('span', { cls: 'hr-cap', text: 'Revisar' })], () => cb.onInspect(),
      { 'aria-label': 'Revisar lo que tenés cerca' });
    this.actLabel = el('span', { text: 'Acercate a algo' });
    this.act = button('hud-act is-idle', [this.actLabel], () => cb.onAction(), { 'data-sfx': 'none' });
    this.root = el('div', 'hud-btns', [this.meter, this.inspect, this.act]);
    this.pauseButton = button('hud-pause', [icon('pause', 24)], () => cb.onPause(), { 'aria-label': 'Pausa' });
    host.append(this.root, this.pauseButton);
  }

  /** Texto y estado del botón grande. idle = gris (nada cerca), drop = blanco (soltar lo que cargás). */
  setAction(label: string, state: ActionState = 'normal', enabled = true): void {
    setText(this.actLabel, label);
    this.act.classList.toggle('is-idle', state === 'idle');
    this.act.classList.toggle('is-drop', state === 'drop');
    this.act.disabled = !enabled;
  }

  setMeterOn(on: boolean): void {
    this.meter.classList.toggle('is-on', on);
    this.meter.setAttribute('aria-pressed', String(on));
  }

  setInspectEnabled(on: boolean): void { this.inspect.disabled = !on; }
  setMeterEnabled(on: boolean): void { this.meter.disabled = !on; }
}
