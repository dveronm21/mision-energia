import { el } from '../dom';
import { icon } from '../icons';

/** Logotipo: sol + "MISIÓN ENERGÍA". */
export function logo(cls = ''): HTMLDivElement {
  return el('div', { cls: `logo ${cls}`.trim(), attrs: { role: 'img', 'aria-label': 'Misión Energía' } }, [
    el('span', 'logo-sun', [icon('sun', 44)]),
    el('span', 'logo-words', [
      el('span', { cls: 'logo-a', text: 'MISIÓN' }),
      el('span', { cls: 'logo-b', text: 'ENERGÍA' }),
    ]),
  ]);
}
