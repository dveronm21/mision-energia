import { button, el, type Child } from '../dom';
import { icon, type IconName } from '../icons';

export interface PageFrameOptions {
  title: string;
  eyebrow?: string;
  onBack?: () => void;
  backLabel?: string;
  right?: Child[];
  body: Child[];
  footer?: Child[];
  cls?: string;
}

export interface PageFrame { root: HTMLDivElement; body: HTMLDivElement; footer: HTMLElement | null; }

/** Estructura común de página: cabecera (atrás + título + extras), cuerpo con scroll interno, pie opcional. */
export function pageFrame(o: PageFrameOptions): PageFrame {
  const head = el('header', 'pg-head', [
    o.onBack ? button('icon-btn', [icon('back', 26)], o.onBack, { 'aria-label': o.backLabel ?? 'Volver' }) : null,
    el('div', 'pg-titles', [
      o.eyebrow ? el('div', { cls: 'eyebrow', text: o.eyebrow }) : null,
      el('h1', { cls: 'pg-title', text: o.title }),
    ]),
    el('div', 'pg-right', o.right ?? []),
  ]);
  const body = el('div', 'pg-body', o.body);
  const footer = o.footer ? el('footer', 'pg-foot', o.footer) : null;
  const root = el('div', { cls: `pg ${o.cls ?? ''}`.trim(), attrs: { role: 'region', 'aria-label': o.title } }, [head, body, footer]);
  return { root, body, footer };
}

/** Botón con ícono + texto. kind: primary (amarillo), secondary (verde oscuro), ghost (contorno), danger. */
export function actionButton(
  label: string,
  onClick: () => void,
  opts: { kind?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'light'; icon?: IconName; big?: boolean; attrs?: Record<string, string | boolean | undefined> } = {},
): HTMLButtonElement {
  const cls = `btn btn-${opts.kind ?? 'primary'}${opts.big ? ' btn-big' : ''}`;
  return button(cls, [opts.icon ? icon(opts.icon, opts.big ? 28 : 22) : null, el('span', { text: label })], onClick, opts.attrs ?? {});
}

/** Fila de estrellas (0..3). */
export function starsRow(n: number, size = 20, cls = 'stars'): HTMLSpanElement {
  const wrap = el('span', { cls, attrs: { role: 'img', 'aria-label': `${n} de 3 estrellas` } });
  for (let i = 0; i < 3; i++) wrap.appendChild(icon(i < n ? 'starFill' : 'star', size, i < n ? 'is-on' : 'is-off'));
  return wrap;
}

/**
 * Confirmación dentro de la página (nunca alert/confirm): reemplaza un contenedor por pregunta + Sí/No.
 */
export function inlineConfirm(
  question: string,
  yesLabel: string,
  onYes: () => void,
  onNo: () => void,
  opts: { yesKind?: 'primary' | 'danger'; noLabel?: string } = {},
): HTMLDivElement {
  const yes = actionButton(yesLabel, onYes, { kind: opts.yesKind ?? 'primary', attrs: { 'data-autofocus': true } });
  return el('div', { cls: 'confirm', attrs: { role: 'group', 'aria-label': question } }, [
    el('p', { cls: 'confirm-q', text: question }),
    el('div', 'confirm-btns', [actionButton(opts.noLabel ?? 'No', onNo, { kind: 'ghost' }), yes]),
  ]);
}
