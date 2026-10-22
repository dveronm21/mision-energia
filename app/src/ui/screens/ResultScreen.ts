import type { LevelResult } from '../../contracts';
import { el, prefersReducedMotion } from '../dom';
import { fmtHour, fmtInt, fmtPct } from '../format';
import { icon } from '../icons';
import type { UiScreen } from '../types';
import { actionButton } from './common';

export interface ResultDeps {
  result: LevelResult;
  levelName: string;
  /** Soles acreditados por estrellas nuevas (de ILevelManager.recordResult). */
  solesEarned: number;
  /** Nombre del nivel que se acaba de desbloquear, si hubo. */
  unlockedName?: string | null;
  /** ¿Hay un siguiente nivel jugable? Si no, se oculta "Siguiente nivel". */
  hasNext: boolean;
  bestScore?: number;
  onRetry(): void;
  onNext(): void;
  onMap(): void;
}

/** Resultado del nivel: estrellas animadas, puntaje, Soles ganados, consejos y acciones. */
export class ResultScreen implements UiScreen {
  readonly root: HTMLDivElement;
  readonly modal = true;
  private timers: number[] = [];

  constructor(private readonly deps: ResultDeps) {
    const r = deps.result;
    const title = !r.won ? 'Se apagó la ciudad' : r.stars === 3 ? '¡Planta perfecta!' : r.stars === 2 ? '¡Muy bien!' : '¡Lo lograste!';
    const sub = !r.won
      ? (r.blackoutHour !== null ? `La batería se agotó a las ${fmtHour(r.blackoutHour)}.` : 'La planta no alcanzó para toda la noche.')
      : 'La ciudad tuvo luz toda la noche.';

    const stars = el('div', { cls: 'rs-stars', attrs: { role: 'img', 'aria-label': `${r.stars} de 3 estrellas` } });
    const starEls: HTMLElement[] = [];
    for (let i = 0; i < 3; i++) {
      const s = el('span', `rs-star${i < r.stars ? ' is-on' : ''}`, [icon(i < r.stars ? 'starFill' : 'star', 54)]);
      starEls.push(s);
      stars.appendChild(s);
    }
    if (!prefersReducedMotion()) {
      starEls.forEach((s, i) => {
        if (i >= r.stars) return;
        s.classList.add('is-wait');
        this.timers.push(window.setTimeout(() => { s.classList.remove('is-wait'); s.classList.add('is-pop'); }, 250 + i * 320));
      });
    }

    const kpi = (value: string, label: string, ic?: Parameters<typeof icon>[0]): HTMLDivElement =>
      el('div', 'rs-kpi', [el('b', {}, [ic ? icon(ic, 20) : null, el('span', { text: value })]), el('span', { text: label })]);

    const tips = r.tips.slice(0, 3);
    const nextBtn = deps.hasNext && r.won ? actionButton('Siguiente nivel', deps.onNext, { icon: 'next', attrs: { 'data-autofocus': true } }) : null;
    const retryBtn = actionButton('Reintentar', deps.onRetry, { kind: nextBtn ? 'secondary' : 'primary', icon: 'retry', attrs: nextBtn ? {} : { 'data-autofocus': true } });

    const card = el('div', { cls: `mdl-card rs ${r.won ? 'is-won' : 'is-lost'}`, attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'rs-title' } }, [
      el('div', 'rs-left', [
        el('div', { cls: 'eyebrow', text: deps.levelName }),
        el('h2', { cls: 'rs-title', text: title, attrs: { id: 'rs-title' } }),
        stars,
        el('p', { cls: 'rs-sub', text: sub }),
        el('div', 'rs-kpis', [
          kpi(fmtInt(r.score), deps.bestScore !== undefined && deps.bestScore > r.score ? `puntos · récord ${fmtInt(deps.bestScore)}` : 'puntos'),
          kpi(fmtPct(r.finalSocPct), 'batería al final', 'battery'),
          kpi(`+${fmtInt(deps.solesEarned)}`, 'Soles ganados', 'soles'),
        ]),
      ]),
      el('div', 'rs-right', [
        deps.unlockedName ? el('div', 'rs-unlock', [icon('starFill', 20), el('span', { text: `¡Desbloqueaste ${deps.unlockedName}!` })]) : null,
        tips.length ? el('div', 'rs-tips', [
          el('div', { cls: 'rs-tips-t' }, [icon('hint', 20), el('span', { text: 'Consejos' })]),
          el('ul', {}, tips.map((t) => el('li', { text: t }))),
        ]) : null,
      ]),
      el('div', 'rs-btns', [
        actionButton('Mapa', deps.onMap, { kind: 'ghost', icon: 'map' }),
        retryBtn,
        nextBtn,
      ]),
    ]);
    this.root = el('div', 'mdl mdl-result', [card]);
  }

  onBack(): boolean { this.deps.onMap(); return true; }
  dispose(): void { this.timers.forEach((t) => window.clearTimeout(t)); }
}
