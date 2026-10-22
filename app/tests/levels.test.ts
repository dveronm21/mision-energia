import test from 'node:test';
import assert from 'node:assert/strict';
import { LevelCatalog } from '../src/levels/LevelCatalog';
import { LevelManager } from '../src/levels/LevelManager';
import { Wallet } from '../src/economy/Wallet';
import type { LevelResult } from '../src/contracts';
import { memStore } from './support/fixtures';
import { bestPurchase } from './support/autoplay';

const catalog = new LevelCatalog();
const result = (over: Partial<LevelResult>): LevelResult => ({
  levelId: 'casa', won: true, stars: 1, score: 1000, finalSocPct: 0.3, spent: 0, budget: 0, panelsLost: 0,
  blackoutHour: null, durationSec: 60, tips: [], ...over,
});
function setup() {
  const store = memStore();
  const wallet = new Wallet(store);
  return { store, wallet, lm: new LevelManager(catalog, store, wallet) };
}

test('catálogo: 5 niveles encadenados y coherentes', () => {
  const all = catalog.all();
  assert.deepEqual(all.map((l) => l.id), ['casa', 'escuela', 'finca', 'pueblo', 'parque']);
  all.forEach((l, i) => {
    assert.equal(l.order, i + 1);
    assert.equal(l.requires, i === 0 ? null : all[i - 1].id);
    assert.ok(l.minPanels <= l.rows * l.panelsPerRow);
    assert.ok(catalog.cost(l, { panels: l.minPanels, batteries: 1, kitZonda: false }) <= l.budget);
  });
  assert.equal(catalog.get('finca').hasPump, true);
});

test('cada nivel se puede ganar con 3 estrellas jugando bien', () => {
  for (const l of catalog.all()) assert.equal(bestPurchase(l)!.outcome.result.stars, 3, l.id);
});

test('LevelManager: nivel 1 siempre desbloqueado; ganar desbloquea el siguiente', () => {
  const { lm } = setup();
  assert.equal(lm.isUnlocked('casa'), true);
  assert.equal(lm.isUnlocked('escuela'), false);
  assert.deepEqual(lm.recordResult(result({ won: false, stars: 0 })).newlyUnlocked, null);
  assert.equal(lm.isUnlocked('escuela'), false);
  const r = lm.recordResult(result({ stars: 1 }));
  assert.equal(r.newlyUnlocked, 'escuela');
  assert.equal(lm.isUnlocked('escuela'), true);
  assert.equal(lm.recordResult(result({ stars: 1 })).newlyUnlocked, null);
});

test('LevelManager: Soles solo por estrellas NUEVAS y persiste', () => {
  const { lm, wallet, store } = setup();
  const [r1, r2, r3] = catalog.get('casa').rewards;
  assert.equal(lm.recordResult(result({ stars: 2 })).solesEarned, r1 + r2);
  assert.equal(lm.recordResult(result({ stars: 2 })).solesEarned, 0);
  assert.equal(lm.recordResult(result({ stars: 1 })).solesEarned, 0);
  assert.equal(lm.recordResult(result({ stars: 3, score: 2000 })).solesEarned, r3);
  assert.equal(wallet.balance(), r1 + r2 + r3);
  const again = new LevelManager(catalog, store, new Wallet(store));
  assert.deepEqual(again.progress('casa'), { unlocked: true, bestStars: 3, bestScore: 2000, completed: true });
  assert.equal(again.totalStars(), 3);
});

test('LevelManager: unlockWithSoles cobra y desbloquea; sin saldo no', () => {
  const { lm, wallet } = setup();
  const cost = catalog.get('finca').unlockCostSoles;
  assert.equal(lm.unlockWithSoles('finca'), false);
  wallet.add(cost + 5, 'test');
  assert.equal(lm.unlockWithSoles('finca'), true);
  assert.equal(wallet.balance(), 5);
  assert.equal(lm.isUnlocked('finca'), true);
  assert.equal(lm.unlockWithSoles('finca'), true);
  assert.equal(wallet.balance(), 5);
});
