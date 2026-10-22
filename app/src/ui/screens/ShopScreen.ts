import type { IInventory, IShop, IWallet, PaymentResult, Product } from '../../contracts';
import { append, button, clear, el } from '../dom';
import { fmtInt, fmtMoney } from '../format';
import { icon, resolveIcon } from '../icons';
import { WalletChip } from '../hud/WalletChip';
import type { UiScreen } from '../types';
import { actionButton, pageFrame } from './common';
import { cosmeticColor, cosmeticSlot } from './WardrobeScreen';

export type ShopTab = 'soles' | 'mejoras' | 'vestuario';

export interface ShopDeps {
  shop: IShop;
  wallet: IWallet;
  inventory: IInventory;
  /** true cuando el proveedor de pagos es el de demo (muestra el banner fijo). */
  isDemo: boolean;
  /** Control parental antes de pagar con dinero real. Ej: () => ParentalGateModal.ask(ui.screens, gate). */
  askParent(): Promise<boolean>;
  onBack(): void;
  /** Avisos opcionales (ej. sonido "coin" al acreditar). */
  onPurchased?(product: Product): void;
  initialTab?: ShopTab;
}

const TABS: { id: ShopTab; label: string; ic: Parameters<typeof icon>[0] }[] = [
  { id: 'soles', label: 'Soles', ic: 'soles' },
  { id: 'mejoras', label: 'Mejoras', ic: 'bolt' },
  { id: 'vestuario', label: 'Vestuario', ic: 'helmet' },
];

/** Tienda con pestañas. Packs con dinero real pasan por control parental → procesando → resultado. */
export class ShopScreen implements UiScreen {
  readonly root: HTMLDivElement;
  private tab: ShopTab;
  private readonly chip: WalletChip;
  private readonly grid: HTMLDivElement;
  private readonly sheet: HTMLDivElement;
  private readonly tabBtns = new Map<ShopTab, HTMLButtonElement>();
  private confirming: string | null = null;
  private busy = false;

  constructor(private readonly deps: ShopDeps) {
    this.tab = deps.initialTab ?? 'soles';
    this.chip = new WalletChip(deps.wallet);
    const tabs = el('div', { cls: 'tabs', attrs: { role: 'tablist', 'aria-label': 'Secciones de la tienda' } });
    for (const t of TABS) {
      const b = button('tab', [icon(t.ic, 20), el('span', { text: t.label })], () => this.setTab(t.id),
        { role: 'tab', id: `tab-${t.id}`, 'aria-controls': 'shop-panel' });
      this.tabBtns.set(t.id, b);
      tabs.appendChild(b);
    }
    this.grid = el('div', { cls: 'shop-grid', attrs: { role: 'tabpanel', id: 'shop-panel' } });
    this.sheet = el('div', { cls: 'sheet', hidden: true });
    const banner = deps.isDemo
      ? el('div', { cls: 'demo-banner', attrs: { role: 'note' } }, [icon('lock', 18), el('span', { text: 'Modo demo: no se cobra dinero real' })])
      : null;
    const frame = pageFrame({
      title: 'Tienda', onBack: () => this.back(), right: [tabs, this.chip.root],
      body: [this.grid], cls: 'pg-shop',
    });
    if (banner) frame.root.insertBefore(banner, frame.body);
    frame.root.appendChild(this.sheet);
    this.root = frame.root;
    this.setTab(this.tab);
  }

  onEnter(): void { this.chip.refresh(); this.render(); }
  onBack(): boolean { this.back(); return true; }
  dispose(): void { this.chip.dispose(); }

  setTab(t: ShopTab): void {
    this.tab = t;
    this.confirming = null;
    this.tabBtns.forEach((b, id) => {
      b.setAttribute('aria-selected', String(id === t));
      b.classList.toggle('is-on', id === t);
      b.tabIndex = id === t ? 0 : -1;
    });
    this.grid.setAttribute('aria-labelledby', `tab-${t}`);
    this.render();
    this.grid.parentElement?.scrollTo?.({ top: 0 });
  }

  private back(): void {
    if (this.busy) return;
    if (!this.sheet.hidden) { this.closeSheet(); return; }
    this.deps.onBack();
  }

  private products(): Product[] {
    const all = this.deps.shop.catalog();
    if (this.tab === 'soles') return all.filter((p) => p.kind === 'token-pack');
    if (this.tab === 'mejoras') return all.filter((p) => p.kind === 'booster');
    return all.filter((p) => p.kind === 'cosmetic');
  }

  private render(): void {
    clear(this.grid);
    const list = this.products();
    if (!list.length) { this.grid.appendChild(el('p', { cls: 'shop-empty', text: 'No hay productos en esta sección por ahora.' })); return; }
    for (const p of list) this.grid.appendChild(this.card(p));
  }

  private card(p: Product): HTMLElement {
    const inv = this.deps.inventory;
    const owned = inv.count(p.id);
    const isCos = p.kind === 'cosmetic';
    const slot = isCos ? cosmeticSlot(p) : null;
    const equipped = slot ? inv.equippedCosmetic(slot) === p.id : false;
    const swatch = isCos ? el('span', 'sc-swatch') : null;
    if (swatch && slot) swatch.style.background = cosmeticColor(p);
    const card = el('article', `shop-card is-${p.kind}`, [
      el('div', 'sc-head', [
        el('span', 'sc-ic', [icon(resolveIcon(p.icon), 30), swatch]),
        el('div', 'sc-titles', [
          el('h3', { text: p.title }),
          p.kind === 'token-pack' && p.soles ? el('div', 'sc-amount', [icon('soles', 18), el('span', { text: `${fmtInt(p.soles)} Soles` })]) : null,
          owned > 0 && !isCos ? el('div', { cls: 'sc-owned', text: `Tenés ${owned}` }) : null,
        ]),
      ]),
      el('p', { cls: 'sc-desc', text: p.description }),
    ]);
    const foot = el('div', 'sc-foot');
    card.appendChild(foot);

    if (p.kind === 'token-pack') {
      const price = p.priceCents !== undefined ? fmtMoney(p.priceCents, p.currency ?? 'ARS') : '';
      append(foot, [
        actionButton(price ? `Comprar ${price}` : 'Comprar', () => void this.buyPack(p), { kind: 'primary', attrs: { 'data-sfx': 'click' } }),
        this.deps.isDemo ? el('small', { cls: 'sc-note', text: 'Precio de prueba' }) : null,
      ]);
      return card;
    }

    if (isCos && owned > 0 && slot) {
      foot.append(equipped
        ? el('div', 'sc-equipped', [icon('check', 18), el('span', { text: 'Puesto' })])
        : actionButton('Ponérmelo', () => { this.deps.inventory.equip(slot, p.id); this.render(); }, { kind: 'secondary', icon: slot === 'helmet' ? 'helmet' : 'vest' }));
      return card;
    }

    const cost = p.costSoles ?? 0;
    if (this.confirming === p.id) {
      foot.classList.add('is-confirm');
      foot.append(
        el('p', { cls: 'sc-q', text: `¿Comprar por ${fmtInt(cost)} Soles?` }),
        el('div', 'sc-btns', [
          actionButton('No', () => { this.confirming = null; this.render(); }, { kind: 'ghost' }),
          actionButton('Comprar', () => this.buySoles(p), { kind: 'primary', attrs: { 'data-sfx': 'coin', 'data-autofocus': true } }),
        ]),
      );
      return card;
    }
    const bal = this.deps.wallet.balance();
    if (bal < cost) {
      foot.append(
        button('btn btn-ghost sc-price', [icon('soles', 20), el('span', { text: fmtInt(cost) })], () => this.setTab('soles'),
          { 'aria-label': `Cuesta ${fmtInt(cost)} Soles. Te faltan ${fmtInt(cost - bal)}. Ver packs de Soles` }),
        el('small', { cls: 'sc-note', text: `Te faltan ${fmtInt(cost - bal)}` }),
      );
    } else {
      foot.append(button('btn btn-primary sc-price', [icon('soles', 20), el('span', { text: fmtInt(cost) })], () => {
        this.confirming = p.id; this.render();
        this.grid.querySelector<HTMLElement>('[data-autofocus]')?.focus();
      }, { 'aria-label': `Comprar ${p.title} por ${fmtInt(cost)} Soles` }));
    }
    return card;
  }

  private buySoles(p: Product): void {
    this.confirming = null;
    const ok = this.deps.shop.buyWithSoles(p.id);
    if (ok) {
      this.deps.onPurchased?.(p);
      const slot = p.kind === 'cosmetic' ? cosmeticSlot(p) : null;
      this.showResult(true, '¡Listo!', p.kind === 'cosmetic' ? `${p.title} ya es tuyo.` : `Sumaste 1 × ${p.title}.`,
        slot ? { label: 'Ponérmelo', run: () => this.deps.inventory.equip(slot, p.id) } : undefined);
    } else {
      this.showResult(false, 'No se pudo comprar', 'No te alcanzan los Soles.');
    }
    this.render();
  }

  private async buyPack(p: Product): Promise<void> {
    if (this.busy) return;
    const ok = await this.deps.askParent();
    if (!ok) return;
    this.busy = true;
    this.showProcessing();
    let res: PaymentResult;
    try {
      res = await this.deps.shop.buyTokenPack(p.id);
    } catch (e) {
      res = { status: 'failed', orderId: '', productId: p.id, message: e instanceof Error ? e.message : undefined };
    }
    this.busy = false;
    const demoNote = this.deps.isDemo ? ' Fue una compra de prueba: no se cobró dinero.' : '';
    switch (res.status) {
      case 'approved':
        this.deps.onPurchased?.(p);
        this.showResult(true, '¡Compra lista!', `Sumaste ${fmtInt(p.soles ?? 0)} Soles.${demoNote}`);
        break;
      case 'pending':
        this.showResult(false, 'Pago pendiente', 'Cuando se confirme el pago, los Soles aparecen en tu saldo.');
        break;
      case 'cancelled':
        this.showResult(false, 'Compra cancelada', 'No se cobró nada.');
        break;
      default:
        this.showResult(false, 'No se pudo completar', res.message ? `${res.message}` : 'Probá de nuevo más tarde. No se cobró nada.');
    }
    this.render();
  }

  private showProcessing(): void {
    clear(this.sheet);
    this.sheet.appendChild(el('div', { cls: 'mdl-card sheet-card', attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-busy': 'true', 'aria-label': 'Procesando compra' } }, [
      el('div', { cls: 'spinner', attrs: { 'aria-hidden': 'true' } }),
      el('h2', { text: 'Procesando compra…' }),
      el('p', { text: 'Esperá un momento, no cierres el juego.' }),
    ]));
    this.sheet.hidden = false;
  }

  private showResult(good: boolean, title: string, text: string, extra?: { label: string; run: () => void }): void {
    clear(this.sheet);
    const btns = el('div', 'sheet-btns', [
      extra ? actionButton(extra.label, () => { extra.run(); this.closeSheet(); this.render(); }, { kind: 'secondary' }) : null,
      actionButton('Listo', () => this.closeSheet(), { kind: 'primary', attrs: { 'data-autofocus': true } }),
    ]);
    this.sheet.appendChild(el('div', { cls: `mdl-card sheet-card ${good ? 'is-good' : 'is-bad'}`, attrs: { role: 'alertdialog', 'aria-modal': 'true', 'aria-labelledby': 'sheet-t' } }, [
      el('span', 'sheet-ic', [icon(good ? 'check' : 'close', 34)]),
      el('h2', { text: title, attrs: { id: 'sheet-t' } }),
      el('p', { text }),
      btns,
    ]));
    this.sheet.hidden = false;
    this.sheet.querySelector<HTMLElement>('[data-autofocus]')?.focus();
  }

  private closeSheet(): void { this.sheet.hidden = true; clear(this.sheet); }
}
