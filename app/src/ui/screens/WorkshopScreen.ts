import type { IInventory, IWallet, LevelDefinition, Product, Purchase } from '../../contracts';
import { button, clear, el, setText } from '../dom';
import { fmt1, fmtHour, fmtInt } from '../format';
import { icon, resolveIcon, type IconName } from '../icons';
import { WalletChip } from '../hud/WalletChip';
import type { UiScreen } from '../types';
import { actionButton, pageFrame } from './common';

export interface WorkshopDeps {
  level: LevelDefinition;
  /** Productos tipo booster del catálogo (se muestran los que el jugador tiene). */
  boosters: Product[];
  inventory: IInventory;
  wallet?: IWallet;
  initial?: Purchase;
  onBuild(purchase: Purchase, boosterIds: string[]): void;
  onBack(): void;
  onShop?(): void;
  /** [0.3] Presupuesto con/sin el booster boost_budget (Boosters.budgetFor). Si falta, se usa level.budget. */
  budgetFor?(boosted: boolean): number;
}

interface StepperRow { root: HTMLDivElement; out: HTMLOutputElement; minus: HTMLButtonElement; plus: HTMLButtonElement; }

/** Briefing del nivel + taller de compras (paneles, baterías, kit) con presupuesto, y elección de boosters. */
export class WorkshopScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private readonly lv: LevelDefinition;
  private p: Purchase;
  private readonly picked = new Set<string>();
  private readonly chip: WalletChip | null;
  private readonly rows: { panels: StepperRow; batteries: StepperRow; kit: StepperRow };
  private readonly spentEl: HTMLElement;
  private readonly fill: HTMLDivElement;
  private readonly bar: HTMLDivElement;
  private readonly warn: HTMLDivElement;
  private readonly build: HTMLButtonElement;
  private readonly summary: HTMLDivElement;
  private readonly boosterBox: HTMLDivElement;

  constructor(private readonly deps: WorkshopDeps) {
    const lv = (this.lv = deps.level);
    const maxPanels = lv.rows * lv.panelsPerRow;
    this.p = deps.initial ? { ...deps.initial } : { panels: Math.min(maxPanels, lv.minPanels), batteries: Math.min(1, lv.batterySlots), kitZonda: false };
    this.chip = deps.wallet ? new WalletChip(deps.wallet, deps.onShop) : null;

    // Columna izquierda: historia del nivel.
    const facts = el('ul', 'ws-facts');
    const fact = (ic: IconName, text: string, warn = false): void => {
      facts.appendChild(el('li', warn ? 'is-warn' : '', [icon(ic, 18), el('span', { text })]));
    };
    fact('panel', `Hasta ${maxPanels} paneles de ${fmt1(lv.panelKw)} kW`);
    fact('battery', `Hasta ${lv.batterySlots} baterías de ${fmt1(lv.batteryKwh)} kWh`);
    fact('sun', `Activás a las ${fmtHour(lv.startHour)}; aguantá hasta las ${fmtHour(lv.endHour)}`);
    if (lv.events.zondaAtHour !== null) fact('wind', `Pronóstico: viento Zonda a las ${fmtHour(lv.events.zondaAtHour)}`, true);
    if (lv.events.clouds.length) fact('cloud', 'Se esperan nubes durante el día', true);
    if (lv.events.looseConnector) fact('loose', 'Un panel puede venir con un conector flojo', true);
    if (lv.hasPump) fact('pump', 'Hay una bomba de agua que consume de día');

    const story = el('section', 'ws-story', [
      el('div', { cls: 'eyebrow', text: `Nivel ${lv.order} · ${lv.name}` }),
      el('h2', { cls: 'ws-sub', text: lv.subtitle }),
      el('p', { cls: 'ws-text', text: lv.story }),
      facts,
    ]);

    // Columna derecha: taller.
    this.rows = {
      panels: this.stepper('panel', 'Paneles solares', `${fmt1(lv.panelKw)} kW c/u · ${fmtInt(lv.prices.panel)} créditos`, 'panel'),
      batteries: this.stepper('battery', 'Baterías de litio', `${fmt1(lv.batteryKwh)} kWh c/u · ${fmtInt(lv.prices.battery)} créditos`, 'batería'),
      kit: this.stepper('wind', 'Kit anti-Zonda', `Trabas para los paneles · ${fmtInt(lv.prices.kitZonda)} créditos`, 'kit'),
    };
    this.spentEl = el('b');
    this.fill = el('div');
    this.bar = el('div', { cls: 'ws-bar', attrs: { role: 'progressbar', 'aria-label': 'Presupuesto usado', 'aria-valuemin': 0, 'aria-valuemax': 100 } }, [this.fill]);
    this.warn = el('div', { cls: 'ws-warn', attrs: { 'aria-live': 'polite' } });
    this.summary = el('div', 'ws-summary');
    this.boosterBox = el('div', 'ws-boosters');

    const shop = el('section', 'ws-shop', [
      el('div', { cls: 'eyebrow', text: 'Taller de compras' }),
      this.rows.panels.root, this.rows.batteries.root, this.rows.kit.root,
      el('div', 'ws-item is-fixed', [
        el('span', 'ws-ic', [icon('bolt', 26)]),
        el('div', 'ws-txt', [el('b', { text: 'Inversor híbrido + protección' }), el('small', { text: `Obligatorios · ${fmtInt(lv.prices.basePackage)} créditos` })]),
        el('span', { cls: 'ws-incl', text: 'Incluidos' }),
      ]),
      this.boosterBox,
    ]);
    this.rows.kit.root.hidden = lv.events.zondaAtHour === null;

    this.build = actionButton('Construir', () => this.deps.onBuild({ ...this.p }, [...this.picked]), { icon: 'bolt', attrs: { 'data-sfx': 'ok' } });
    const frame = pageFrame({
      title: 'Taller', onBack: deps.onBack, right: this.chip ? [this.chip.root] : [],
      body: [el('div', 'ws-grid', [story, shop])],
      footer: [
        el('div', 'ws-budget', [el('div', 'ws-budget-row', [el('span', { text: 'Gastás' }), this.spentEl]), this.bar, this.summary]),
        el('div', 'ws-foot-right', [this.warn, this.build]),
      ],
      cls: 'pg-workshop',
    });
    this.root = frame.root;
    this.renderBoosters();
    this.update();
  }

  onEnter(): void { this.chip?.refresh(); this.renderBoosters(); }
  onBack(): boolean { this.deps.onBack(); return true; }
  dispose(): void { this.chip?.dispose(); }

  purchase(): Purchase { return { ...this.p }; }
  spent(): number {
    const pr = this.lv.prices;
    return pr.basePackage + this.p.panels * pr.panel + this.p.batteries * pr.battery + (this.p.kitZonda ? pr.kitZonda : 0);
  }

  private stepper(ic: IconName, title: string, sub: string, noun: string): StepperRow {
    const out = el('output', { cls: 'ws-out', text: '0' });
    const minus = button('ws-step', [icon('minus', 22)], () => this.change(ic, -1), { 'aria-label': `Quitar ${noun}`, 'data-sfx': 'click' });
    const plus = button('ws-step', [icon('plus', 22)], () => this.change(ic, 1), { 'aria-label': `Agregar ${noun}`, 'data-sfx': 'click' });
    const root = el('div', 'ws-item', [
      el('span', 'ws-ic', [icon(ic, 26)]),
      el('div', 'ws-txt', [el('b', { text: title }), el('small', { text: sub })]),
      el('div', 'ws-stepper', [minus, out, plus]),
    ]);
    return { root, out, minus, plus };
  }

  private change(kind: IconName, d: number): void {
    if (kind === 'panel') this.p.panels += d;
    else if (kind === 'battery') this.p.batteries += d;
    else this.p.kitZonda = d > 0;
    this.update();
  }

  /** Presupuesto vigente: con "Presupuesto extra" elegido, el ampliado. */
  budget(): number {
    return this.picked.has('boost_budget') && this.deps.budgetFor ? this.deps.budgetFor(true) : this.lv.budget;
  }

  private update(): void {
    const lv = this.lv, pr = lv.prices;
    const budget = this.budget();
    const maxPanels = lv.rows * lv.panelsPerRow;
    this.p.panels = Math.max(0, Math.min(maxPanels, this.p.panels));
    this.p.batteries = Math.max(0, Math.min(lv.batterySlots, this.p.batteries));
    const spent = this.spent();
    const left = budget - spent;
    setText(this.rows.panels.out, String(this.p.panels));
    setText(this.rows.batteries.out, String(this.p.batteries));
    setText(this.rows.kit.out, this.p.kitZonda ? '1' : '0');
    this.rows.panels.minus.disabled = this.p.panels <= 0;
    this.rows.panels.plus.disabled = this.p.panels >= maxPanels || left < pr.panel;
    this.rows.batteries.minus.disabled = this.p.batteries <= 0;
    this.rows.batteries.plus.disabled = this.p.batteries >= lv.batterySlots || left < pr.battery;
    this.rows.kit.minus.disabled = !this.p.kitZonda;
    this.rows.kit.plus.disabled = this.p.kitZonda || left < pr.kitZonda;

    setText(this.spentEl, `${fmtInt(spent)} / ${fmtInt(budget)}`);
    const pct = Math.min(100, Math.round((spent / budget) * 100));
    this.fill.style.width = `${pct}%`;
    this.bar.setAttribute('aria-valuenow', String(pct));
    this.bar.classList.toggle('is-over', spent > budget);
    const gen = this.p.panels * lv.panelKw, store = this.p.batteries * lv.batteryKwh;
    setText(this.summary, `Generás hasta ${fmt1(gen)} kW · Guardás ${fmt1(store)} kWh`);

    let msg = '';
    if (spent > budget) msg = 'Te pasaste del presupuesto.';
    else if (this.p.panels < lv.minPanels) msg = `Necesitás al menos ${lv.minPanels} paneles.`;
    else if (this.p.batteries === 0) msg = 'Sin baterías, de noche se apaga todo.';
    setText(this.warn, msg);
    this.warn.hidden = !msg;
    this.build.disabled = spent > budget || this.p.panels < lv.minPanels;
  }

  private renderBoosters(): void {
    clear(this.boosterBox);
    const owned = this.deps.boosters.filter((b) => this.deps.inventory.count(b.id) > 0);
    for (const id of [...this.picked]) if (!owned.some((b) => b.id === id)) this.picked.delete(id);
    this.boosterBox.appendChild(el('div', { cls: 'ws-bst-title', text: 'Ayudas para llevar' }));
    if (!owned.length) {
      this.boosterBox.appendChild(el('div', 'ws-bst-empty', [
        el('span', { text: 'No tenés ayudas todavía.' }),
        this.deps.onShop ? button('link-btn', [el('span', { text: 'Ver en la tienda' })], () => this.deps.onShop?.()) : null,
      ]));
      return;
    }
    const list = el('div', 'ws-bst-list');
    for (const b of owned) {
      const on = this.picked.has(b.id);
      const chip = button(`ws-bst${on ? ' is-on' : ''}`, [
        icon(resolveIcon(b.icon), 22),
        el('span', 'ws-bst-txt', [el('b', { text: b.title }), el('small', { text: `Tenés ${this.deps.inventory.count(b.id)}` })]),
        el('span', 'ws-bst-check', [icon(on ? 'check' : 'plus', 18)]),
      ], () => {
        if (this.picked.has(b.id)) this.picked.delete(b.id); else this.picked.add(b.id);
        this.renderBoosters();
        this.update();
        this.boosterBox.querySelector<HTMLElement>(`[data-id="${CSS.escape(b.id)}"]`)?.focus();
      }, { 'aria-pressed': String(on), 'data-id': b.id });
      list.appendChild(chip);
    }
    this.boosterBox.appendChild(list);
  }
}
