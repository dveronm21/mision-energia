import type { SimSnapshot } from '../../contracts';
import { el, setText } from '../dom';
import { fmtHour, fmtKw, fmtPct } from '../format';
import { icon } from '../icons';

/** Estado de la planta (arriba a la derecha): hora, generación, consumo y batería. */
export class StatsPanel {
  readonly root: HTMLElement;
  private readonly phase: HTMLDivElement;
  private readonly clock: HTMLDivElement;
  private readonly gen: HTMLElement;
  private readonly load: HTMLElement;
  private readonly bat: HTMLElement;
  private readonly fill: HTMLDivElement;
  private readonly bar: HTMLDivElement;

  constructor(host: HTMLElement) {
    this.phase = el('div', { cls: 'st-phase', text: 'Día' });
    this.clock = el('div', { cls: 'st-clock', text: '10:00' });
    this.gen = el('b', { text: '0,0 kW' });
    this.load = el('b', { text: '0,0 kW' });
    this.bat = el('b', { text: '0%' });
    this.fill = el('div', 'st-fill');
    this.bar = el('div', { cls: 'st-bar', attrs: { role: 'progressbar', 'aria-label': 'Carga de baterías', 'aria-valuemin': 0, 'aria-valuemax': 100, 'aria-valuenow': 0 } }, [this.fill]);
    const row = (ic: Parameters<typeof icon>[0], label: string, val: HTMLElement): HTMLDivElement =>
      el('div', 'st-row', [icon(ic, 16), el('span', { text: label }), val]);
    this.root = el('section', { cls: 'hud-stats', attrs: { 'aria-label': 'Estado de la planta' }, hidden: true }, [
      el('div', 'st-top', [this.clock, this.phase]),
      row('panel', 'Generan', this.gen),
      row('city', 'Consumo', this.load),
      row('battery', 'Batería', this.bat),
      this.bar,
    ]);
    host.appendChild(this.root);
  }

  setVisible(on: boolean): void { this.root.hidden = !on; }

  update(s: SimSnapshot): void {
    setText(this.clock, fmtHour(s.hour));
    setText(this.phase, s.blackout ? 'Apagón' : s.isNight ? 'Noche' : s.irradiance < 0.35 ? 'Nublado' : 'Día');
    this.root.classList.toggle('is-night', s.isNight);
    this.root.classList.toggle('is-blackout', s.blackout);
    setText(this.gen, fmtKw(s.genKw));
    setText(this.load, fmtKw(s.loadKw));
    setText(this.bat, fmtPct(s.socPct));
    const pct = Math.round(Math.max(0, Math.min(1, s.socPct)) * 100);
    this.fill.style.width = `${pct}%`;
    this.bar.setAttribute('aria-valuenow', String(pct));
    this.bar.classList.toggle('is-low', s.socPct < 0.2);
    this.bar.classList.toggle('is-charging', s.netKw > 0.05);
  }
}
