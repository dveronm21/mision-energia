import type { ILevelManager, IWallet, LevelDefinition, LevelId } from '../../contracts';
import { append, button, clear, el } from '../dom';
import { fmtInt } from '../format';
import { icon } from '../icons';
import { WalletChip } from '../hud/WalletChip';
import type { UiScreen } from '../types';
import { actionButton, inlineConfirm, pageFrame, starsRow } from './common';

export interface LevelMapDeps {
  levels: LevelDefinition[];
  manager: ILevelManager;
  wallet: IWallet;
  onPlay(id: LevelId): void;
  onBack(): void;
  onShop?(): void;
}

const SVG_NS = 'http://www.w3.org/2000/svg';
/** Posiciones (en %) de los nodos sobre el camino. */
const POS: [number, number][] = [[10, 62], [30, 38], [50, 62], [70, 38], [90, 62]];

/** Mapa con los 5 niveles en un camino, estrellas, candados y desbloqueo con Soles. */
export class LevelMapScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private readonly chip: WalletChip;
  private readonly map: HTMLDivElement;
  private readonly sheet: HTMLDivElement;
  private readonly levels: LevelDefinition[];

  constructor(private readonly deps: LevelMapDeps) {
    this.levels = [...deps.levels].sort((a, b) => a.order - b.order);
    this.chip = new WalletChip(deps.wallet, deps.onShop);
    this.map = el('div', 'lm-map');
    this.sheet = el('div', { cls: 'lm-sheet', hidden: true });
    const frame = pageFrame({
      title: 'Elegí tu misión', onBack: deps.onBack, right: [this.chip.root],
      body: [this.map, this.sheet], cls: 'pg-map',
    });
    this.root = frame.root;
    this.render();
  }

  onEnter(): void { this.chip.refresh(); this.render(); }
  onBack(): boolean {
    if (!this.sheet.hidden) { this.closeSheet(); return true; }
    this.deps.onBack();
    return true;
  }
  dispose(): void { this.chip.dispose(); }
  refresh(): void { this.render(); }

  private render(): void {
    clear(this.map);
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'lm-path');
    svg.setAttribute('viewBox', '0 0 100 100');
    svg.setAttribute('preserveAspectRatio', 'none');
    svg.setAttribute('aria-hidden', 'true');
    const pts = this.levels.map((_, i) => POS[i % POS.length]);
    const d = pts.map((p, i) => {
      if (i === 0) return `M${p[0]} ${p[1]}`;
      const q = pts[i - 1];
      const mx = (q[0] + p[0]) / 2;
      return `C${mx} ${q[1]} ${mx} ${p[1]} ${p[0]} ${p[1]}`;
    }).join(' ');
    for (const cls of ['lm-road', 'lm-dash']) {
      const path = document.createElementNS(SVG_NS, 'path');
      path.setAttribute('d', d);
      path.setAttribute('class', cls);
      path.setAttribute('vector-effect', 'non-scaling-stroke');
      svg.appendChild(path);
    }
    this.map.appendChild(svg);

    let nextFound = false;
    this.levels.forEach((lv, i) => {
      const p = this.deps.manager.progress(lv.id);
      const unlocked = this.deps.manager.isUnlocked(lv.id);
      const isNext = unlocked && !p.completed && !nextFound;
      if (isNext) nextFound = true;
      const cls = `lm-node${unlocked ? '' : ' is-locked'}${p.completed ? ' is-done' : ''}${isNext ? ' is-next' : ''}`;
      const label = unlocked ? `Nivel ${lv.order}: ${lv.name}. ${p.bestStars} de 3 estrellas` : `Nivel ${lv.order}: ${lv.name}. Bloqueado`;
      const bubble = button('lm-bubble', [unlocked ? el('span', { cls: 'lm-num', text: String(lv.order) }) : icon('lock', 30)],
        () => (unlocked ? this.deps.onPlay(lv.id) : this.openLocked(lv)), { 'aria-label': label });
      const node = el('div', cls, [
        bubble,
        el('div', { cls: 'lm-name', text: lv.name }),
        unlocked ? starsRow(p.bestStars, 18) : el('div', { cls: 'lm-cost' }, [icon('soles', 16), el('span', { text: fmtInt(lv.unlockCostSoles) })]),
      ]);
      const [x, y] = POS[i % POS.length];
      node.style.left = `${x}%`;
      node.style.top = `${y}%`;
      this.map.appendChild(node);
    });
  }

  private openLocked(lv: LevelDefinition): void {
    const req = lv.requires ? this.levels.find((l) => l.id === lv.requires) : null;
    const bal = this.deps.wallet.balance();
    const enough = bal >= lv.unlockCostSoles;
    clear(this.sheet);
    const card = el('div', { cls: 'lm-card', attrs: { role: 'dialog', 'aria-label': `${lv.name} bloqueado` } });
    const actions = el('div', 'lm-card-btns');
    const showMain = (): void => {
      clear(actions);
      actions.append(actionButton('Cerrar', () => this.closeSheet(), { kind: 'ghost' }));
      if (enough) {
        actions.append(actionButton(`Desbloquear por ${fmtInt(lv.unlockCostSoles)} Soles`, showConfirm, { icon: 'lock', attrs: { 'data-autofocus': true } }));
      } else if (this.deps.onShop) {
        actions.append(actionButton('Conseguir Soles', () => this.deps.onShop?.(), { kind: 'secondary', icon: 'cart' }));
      }
    };
    const showConfirm = (): void => {
      clear(actions);
      actions.append(inlineConfirm(`¿Gastar ${fmtInt(lv.unlockCostSoles)} Soles en desbloquear ${lv.name}?`, 'Sí, desbloquear', () => {
        if (this.deps.manager.unlockWithSoles(lv.id)) { this.closeSheet(); this.render(); this.flash(lv.id); }
        else showMain();
      }, showMain));
      actions.querySelector<HTMLElement>('[data-autofocus]')?.focus();
    };
    append(card, [
      el('div', 'lm-card-head', [el('span', 'lm-card-ic', [icon('lock', 26)]), el('div', {}, [
        el('div', { cls: 'eyebrow', text: `Nivel ${lv.order}` }),
        el('h2', { text: lv.name }),
      ])]),
      el('p', { text: req ? `Se abre cuando completes ${req.name}. También podés desbloquearlo ahora.` : 'Podés desbloquearlo ahora con Soles.' }),
      enough ? null : el('p', { cls: 'lm-short', text: `Te faltan ${fmtInt(lv.unlockCostSoles - bal)} Soles.` }),
      actions,
    ]);
    showMain();
    this.sheet.appendChild(card);
    this.sheet.hidden = false;
  }

  private closeSheet(): void { this.sheet.hidden = true; clear(this.sheet); }

  private flash(id: LevelId): void {
    const idx = this.levels.findIndex((l) => l.id === id);
    const node = this.map.querySelectorAll<HTMLElement>('.lm-node')[idx];
    node?.classList.add('is-new');
    node?.querySelector<HTMLElement>('button')?.focus();
  }
}
