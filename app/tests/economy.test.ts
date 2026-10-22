import test from 'node:test';
import assert from 'node:assert/strict';
import { Wallet } from '../src/economy/Wallet';
import { Inventory } from '../src/economy/Inventory';
import { Catalog } from '../src/economy/Catalog';
import { Shop } from '../src/economy/Shop';
import { RewardService, WELCOME_SOLES, DAILY_SOLES } from '../src/economy/RewardService';
import { ParentalGate } from '../src/economy/ParentalGate';
import { Boosters } from '../src/economy/Boosters';
import { DemoPaymentProvider } from '../src/economy/payments/DemoPaymentProvider';
import { MercadoPagoProvider } from '../src/economy/payments/MercadoPagoProvider';
import { EventBus } from '../src/core/EventBus';
import { LEVELS } from '../src/levels/levels';
import type { IPaymentProvider, PaymentResult, Product } from '../src/contracts';
import { memStore } from './support/fixtures';

test('Wallet: suma, gasta si alcanza, historial, listeners, bus y persistencia', () => {
  const store = memStore();
  const bus = new EventBus();
  const seen: number[] = [], busSeen: number[] = [];
  bus.on('wallet-changed', (e) => busSeen.push(e.balance));
  const w = new Wallet(store, bus, () => 42);
  const off = w.onChange((b) => seen.push(b));
  w.add(100, 'regalo');
  assert.equal(w.spend(150, 'caro'), false);
  assert.equal(w.spend(30, 'pista'), true);
  w.add(-5, 'ignorado');
  off(); w.add(1, 'x');
  assert.equal(w.balance(), 71);
  assert.deepEqual(seen, [100, 70]);
  assert.deepEqual(busSeen, [100, 70, 71]);
  assert.deepEqual(w.history().map((h) => h.delta), [100, -30, 1]);
  assert.equal(w.history()[0].at, 42);
  assert.equal(new Wallet(store).balance(), 71);
});

test('Inventory: grant/consume/equip y persistencia', () => {
  const store = memStore();
  const inv = new Inventory(store);
  inv.grant('boost_hint', 2);
  assert.equal(inv.consume('boost_hint'), true);
  assert.equal(inv.count('boost_hint'), 1);
  assert.equal(inv.consume('nada'), false);
  inv.equip('helmet', 'skin_helmet_blue');
  assert.equal(inv.equippedCosmetic('helmet'), null); // no lo tiene
  inv.grant('skin_helmet_blue', 1);
  inv.equip('helmet', 'skin_helmet_blue');
  const again = new Inventory(store);
  assert.equal(again.equippedCosmetic('helmet'), 'skin_helmet_blue');
  assert.equal(again.count('boost_hint'), 1);
});

class ControlledProvider implements IPaymentProvider {
  readonly id = 'mercadopago' as const;
  readonly isDemo = false;
  release!: (ok: boolean) => void;
  verifyCalled = false;
  constructor(private readonly purchaseStatus: PaymentResult['status'] = 'approved') {}
  async purchase(p: Product): Promise<PaymentResult> { return { status: this.purchaseStatus, orderId: 'ORD-1', productId: p.id }; }
  verifyOnServer(): Promise<boolean> { this.verifyCalled = true; return new Promise((r) => { this.release = r; }); }
}

function shopWith(provider: IPaymentProvider) {
  const store = memStore();
  const wallet = new Wallet(store);
  const inv = new Inventory(store);
  return { wallet, inv, shop: new Shop(new Catalog(), wallet, inv, provider, store) };
}
const tick = () => new Promise((r) => setTimeout(r, 0));

test('Shop + DemoPaymentProvider: aprueba, verifica y acredita; orden DEMO-', async () => {
  const { shop, wallet } = shopWith(new DemoPaymentProvider({ delayMs: 5 }));
  assert.equal(shop.isDemo(), true);
  const r = await shop.buyTokenPack('pack_small');
  assert.equal(r.status, 'approved');
  assert.ok(r.orderId.startsWith('DEMO-'));
  assert.equal(wallet.balance(), 120);
});

test('Shop: no acredita hasta que el servidor verifica', async () => {
  const p = new ControlledProvider();
  const { shop, wallet } = shopWith(p);
  const pending = shop.buyTokenPack('pack_medium');
  await tick(); await tick();
  assert.equal(p.verifyCalled, true);
  assert.equal(wallet.balance(), 0);
  p.release(true);
  assert.equal((await pending).status, 'approved');
  assert.equal(wallet.balance(), 650);
  // misma orden otra vez: no duplica
  const again = shop.buyTokenPack('pack_medium'); await tick(); p.release(true); await again;
  assert.equal(wallet.balance(), 650);
});

test('Shop: verificación fallida o pago rechazado no acreditan', async () => {
  const p = new ControlledProvider();
  const a = shopWith(p);
  const pending = a.shop.buyTokenPack('pack_large');
  await tick(); p.release(false);
  assert.equal((await pending).status, 'failed');
  assert.equal(a.wallet.balance(), 0);

  const b = shopWith(new ControlledProvider('cancelled'));
  assert.equal((await b.shop.buyTokenPack('pack_large')).status, 'cancelled');
  assert.equal(b.wallet.balance(), 0);

  const mp = shopWith(new MercadoPagoProvider());
  const r = await mp.shop.buyTokenPack('pack_small');
  assert.equal(r.status, 'failed');
  assert.equal(r.message, 'Pagos reales aún no configurados');
  assert.equal(mp.wallet.balance(), 0);
  assert.equal((await mp.shop.buyTokenPack('boost_hint')).status, 'failed');
});

test('Shop: buyWithSoles para boosters y cosméticos (permanentes, una vez)', () => {
  const { shop, wallet, inv } = shopWith(new DemoPaymentProvider({ delayMs: 0 }));
  assert.equal(shop.buyWithSoles('boost_drone'), false);
  wallet.add(200, 'test');
  assert.equal(shop.buyWithSoles('boost_drone'), true);
  assert.equal(shop.buyWithSoles('boost_drone'), true);
  assert.equal(inv.count('boost_drone'), 2);
  assert.equal(shop.buyWithSoles('skin_vest_green'), true);
  assert.equal(shop.buyWithSoles('skin_vest_green'), false);
  assert.equal(shop.buyWithSoles('pack_small'), false);
  assert.equal(wallet.balance(), 200 - 25 * 2 - 60);
});

test('Catálogo: ético (sin aleatorios) y la campaña se cubre sin pagar', () => {
  const cat = new Catalog();
  assert.equal(cat.byKind('token-pack').length, 3);
  cat.byKind('token-pack').forEach((p) => { assert.equal(p.currency, 'ARS'); assert.ok(p.priceCents! > 0); });
  assert.equal(cat.byKind('booster').length, 4);
  assert.equal(cat.byKind('cosmetic').length, 6);
  assert.equal(cat.cosmeticSlot('skin_vest_green'), 'vest');
  assert.ok(cat.all().every((p) => !/sorpresa|aleatori|caja misteriosa/i.test(p.title + p.description)));
  // Con solo jugar (todas las estrellas) + bienvenida alcanza para varios boosters.
  const campaign = LEVELS.reduce((a, l) => a + l.rewards[0] + l.rewards[1] + l.rewards[2], 0);
  assert.ok(campaign + WELCOME_SOLES >= 300);
});

test('Boosters: consumen del inventario y calculan efectos', () => {
  const inv = new Inventory(memStore());
  const b = new Boosters(inv);
  assert.equal(b.use('boost_budget'), false);
  inv.grant('boost_budget', 1);
  assert.equal(b.use('boost_budget'), true);
  assert.equal(b.budgetFor(LEVELS[0], true), Math.round(LEVELS[0].budget * 1.15));
  assert.equal(b.bonusKwh(true), 4);
});

test('RewardService: bienvenida una vez y bono diario una vez por día', () => {
  const store = memStore();
  const w = new Wallet(store);
  let now = new Date(2026, 9, 22, 9, 0);
  const rs = new RewardService(w, store, () => now);
  assert.equal(rs.claimWelcome(), WELCOME_SOLES);
  assert.equal(rs.claimWelcome(), 0);
  assert.equal(rs.claimDaily(), DAILY_SOLES);
  now = new Date(2026, 9, 22, 23, 59);
  assert.equal(rs.claimDaily(), 0);
  assert.equal(new RewardService(w, store, () => now).canClaimDaily(), false);
  now = new Date(2026, 9, 23, 0, 1);
  assert.equal(rs.claimDaily(), DAILY_SOLES);
  assert.equal(w.balance(), WELCOME_SOLES + 2 * DAILY_SOLES);
});

test('ParentalGate: multiplicación con factores 6..9', () => {
  const seq = [0, 0.99, 0.5, 0.3];
  let i = 0;
  const g = new ParentalGate(() => seq[i++ % seq.length]);
  const c1 = g.challenge();
  assert.equal(c1.answer, 6 * 9);
  assert.match(c1.question, /6 × 9/);
  assert.equal(g.check(c1, ' 54 '), true);
  assert.equal(g.check(c1, '45'), false);
  const rnd = new ParentalGate();
  for (let k = 0; k < 200; k++) { const c = rnd.challenge(); assert.ok(c.answer >= 36 && c.answer <= 81); }
});
