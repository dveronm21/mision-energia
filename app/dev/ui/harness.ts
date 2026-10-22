/**
 * Banco de pruebas visual de la UI. Monta una escena según ?scene=… con datos falsos.
 * Compilar: npx esbuild dev/ui/harness.ts --bundle --outfile=dev/ui/out/harness.js
 */
import type {
  IAudio, IInventory, ILevelManager, IParentalGate, IShop, IWallet, LevelDefinition, LevelId,
  LevelProgress, LevelResult, PaymentResult, Product, SimSnapshot,
} from '../../src/contracts';
import {
  Hud, LevelMapScreen, MainMenu, ParentalGateModal, PauseMenu, ResultScreen, SettingsScreen, ShopScreen,
  SplashScreen, UiRoot, WardrobeScreen, WorkshopScreen, type IDailyBonus, type ShopTab,
} from '../../src/ui';

/* ---------------- Mocks ---------------- */

class MockWallet implements IWallet {
  private b: number;
  private cbs = new Set<(b: number) => void>();
  private h: { at: number; delta: number; reason: string }[] = [];
  constructor(start: number) { this.b = start; }
  balance(): number { return this.b; }
  add(n: number, reason: string): void { this.b += n; this.h.push({ at: Date.now(), delta: n, reason }); this.cbs.forEach((c) => c(this.b)); }
  spend(n: number, reason: string): boolean { if (n > this.b) return false; this.b -= n; this.h.push({ at: Date.now(), delta: -n, reason }); this.cbs.forEach((c) => c(this.b)); return true; }
  history(): { at: number; delta: number; reason: string }[] { return this.h; }
  onChange(cb: (b: number) => void): () => void { this.cbs.add(cb); return () => this.cbs.delete(cb); }
}

class MockInventory implements IInventory {
  private c: Record<string, number> = { boost_hint: 2, boost_drone: 1, skin_helmet_blue: 1, skin_vest_green: 1 };
  private eq: Record<'helmet' | 'vest', string | null> = { helmet: 'skin_helmet_blue', vest: null };
  count(id: string): number { return this.c[id] ?? 0; }
  grant(id: string, q: number): void { this.c[id] = this.count(id) + q; }
  consume(id: string): boolean { if (!this.count(id)) return false; this.c[id]--; return true; }
  equippedCosmetic(s: 'helmet' | 'vest'): string | null { return this.eq[s]; }
  equip(s: 'helmet' | 'vest', id: string | null): void { this.eq[s] = id; }
}

const CATALOG: Product[] = [
  { id: 'pack_small', kind: 'token-pack', title: 'Bolsita de Soles', description: 'Para darte un empujón.', soles: 500, priceCents: 149900, currency: 'ARS', icon: 'soles' },
  { id: 'pack_medium', kind: 'token-pack', title: 'Caja de Soles', description: 'La más elegida: rinde para varias mejoras.', soles: 1200, priceCents: 299900, currency: 'ARS', icon: 'soles' },
  { id: 'pack_big', kind: 'token-pack', title: 'Cofre solar', description: 'Un montón de Soles para todo el vestuario.', soles: 3000, priceCents: 599900, currency: 'ARS', icon: 'soles' },
  { id: 'boost_hint', kind: 'booster', title: 'Pista', description: 'Te muestra el próximo paso en el mundo.', costSoles: 80, consumable: true, icon: 'hint' },
  { id: 'boost_drone', kind: 'booster', title: 'Dron limpiador', description: 'Limpia el polvo de una fila de paneles.', costSoles: 150, consumable: true, icon: 'drone' },
  { id: 'boost_battery', kind: 'booster', title: 'Batería de emergencia', description: 'Suma 2 kWh de reserva una vez por noche.', costSoles: 2000, consumable: true, icon: 'battery' },
  { id: 'skin_helmet_blue', kind: 'cosmetic', title: 'Casco azul', description: 'Casco de seguridad azul.', costSoles: 120, icon: 'helmet' },
  { id: 'skin_helmet_red', kind: 'cosmetic', title: 'Casco rojo', description: 'Casco de seguridad rojo.', costSoles: 120, icon: 'helmet' },
  { id: 'skin_helmet_white', kind: 'cosmetic', title: 'Casco blanco', description: 'Como el de la jefa de obra.', costSoles: 200, icon: 'helmet' },
  { id: 'skin_vest_green', kind: 'cosmetic', title: 'Chaleco verde', description: 'Chaleco reflectivo verde.', costSoles: 120, icon: 'vest' },
  { id: 'skin_vest_pink', kind: 'cosmetic', title: 'Chaleco rosa', description: 'Chaleco reflectivo rosa.', costSoles: 150, icon: 'vest' },
  { id: 'skin_vest_blue', kind: 'cosmetic', title: 'Chaleco azul', description: 'Chaleco reflectivo azul.', costSoles: 150, icon: 'vest' },
];

class MockShop implements IShop {
  constructor(private w: IWallet, private inv: IInventory) {}
  catalog(): Product[] { return CATALOG; }
  buyTokenPack(id: string): Promise<PaymentResult> {
    const p = CATALOG.find((x) => x.id === id)!;
    return new Promise((r) => setTimeout(() => { this.w.add(p.soles ?? 0, 'pack'); r({ status: 'approved', orderId: 'DEMO-1', productId: id }); }, 400));
  }
  buyWithSoles(id: string): boolean {
    const p = CATALOG.find((x) => x.id === id)!;
    if (!this.w.spend(p.costSoles ?? 0, id)) return false;
    this.inv.grant(id, 1);
    return true;
  }
}

const gate: IParentalGate = { challenge: () => ({ question: '¿Cuánto es 7 × 8?', answer: 56 }) };

class MockAudio implements IAudio {
  private m = false;
  unlock(): void {}
  play(): void {}
  setWind(): void {}
  setMuted(m: boolean): void { this.m = m; }
  muted(): boolean { return this.m; }
}

const base = (o: Partial<LevelDefinition> & Pick<LevelDefinition, 'id' | 'order' | 'name'>): LevelDefinition => ({
  subtitle: 'Mantené la casa con luz toda la noche', story: 'La familia Quiroga quiere dejar de depender de la red. Armales una planta chica pero bien pensada.',
  rows: 2, panelsPerRow: 4, batterySlots: 3, panelKw: 0.8, batteryKwh: 7, inverterKw: 5, budget: 14000,
  prices: { panel: 900, battery: 3200, kitZonda: 700, basePackage: 600 }, minPanels: 4,
  loads: [
    { from: 0, to: 24, kw: 0.6, label: 'Heladera', essential: true },
    { from: 19, to: 24, kw: 1.2, label: 'Alumbrado público', essential: false },
    { from: 20, to: 23, kw: 0.8, label: 'Cartel luminoso', essential: false },
    { from: 18, to: 24, kw: 1.5, label: 'Aire acondicionado', essential: false },
    { from: 19, to: 22, kw: 0.5, label: 'Fuente del parque', essential: false },
  ],
  hasPump: false, events: { looseConnector: true, zondaAtHour: 15, clouds: [{ from: 12, to: 13, factor: 0.5 }] },
  startHour: 10, endHour: 31, startSoc: 0.15, rewards: [50, 100, 150], twoStarSoc: 0.2, threeStarSpend: 0.9,
  requires: null, unlockCostSoles: 0, ...o,
});

const LEVELS: LevelDefinition[] = [
  base({ id: 'casa', order: 1, name: 'Casa familiar' }),
  base({ id: 'escuela', order: 2, name: 'Escuela rural', requires: 'casa', unlockCostSoles: 300 }),
  base({ id: 'finca', order: 3, name: 'Finca con bomba', requires: 'escuela', unlockCostSoles: 500, hasPump: true }),
  base({ id: 'pueblo', order: 4, name: 'Pueblo de montaña', requires: 'finca', unlockCostSoles: 800 }),
  base({ id: 'parque', order: 5, name: 'Parque solar', requires: 'pueblo', unlockCostSoles: 1200 }),
];

class MockLevels implements ILevelManager {
  private p: Record<string, LevelProgress> = {
    casa: { unlocked: true, bestStars: 3, bestScore: 980, completed: true },
    escuela: { unlocked: true, bestStars: 1, bestScore: 610, completed: true },
    finca: { unlocked: true, bestStars: 0, bestScore: 0, completed: false },
    pueblo: { unlocked: false, bestStars: 0, bestScore: 0, completed: false },
    parque: { unlocked: false, bestStars: 0, bestScore: 0, completed: false },
  };
  constructor(private w: IWallet) {}
  progress(id: LevelId): LevelProgress { return this.p[id]; }
  isUnlocked(id: LevelId): boolean { return this.p[id].unlocked; }
  unlockWithSoles(id: LevelId): boolean {
    const lv = LEVELS.find((l) => l.id === id)!;
    if (!this.w.spend(lv.unlockCostSoles, 'unlock')) return false;
    this.p[id].unlocked = true;
    return true;
  }
  recordResult(): { solesEarned: number; newlyUnlocked: LevelId | null } { return { solesEarned: 0, newlyUnlocked: null }; }
}

/* ---------------- Escenas ---------------- */

const params = new URLSearchParams(location.search);
const scene = params.get('scene') ?? 'menu';
const wallet = new MockWallet(Number(params.get('soles') ?? 1250));
const inventory = new MockInventory();
const shop = new MockShop(wallet, inventory);
const levels = new MockLevels(wallet);
const audio = new MockAudio();
let bonusAvail = true;
const bonus: IDailyBonus = { available: () => bonusAvail, amount: () => 50, claim: () => { if (!bonusAvail) return 0; bonusAvail = false; wallet.add(50, 'bono'); return 50; } };

const app = document.getElementById('app')!;
const ui = new UiRoot(document.getElementById('ui')!, { audio });
const noop = (): void => {};
const log = (m: string) => (): void => console.log('[harness]', m);

function world(night = false): void {
  app.className = night ? 'fake-world is-night' : 'fake-world';
}

function sleep(ms: number): Promise<void> { return new Promise((r) => setTimeout(r, ms)); }
function click(sel: string): void { (document.querySelector(sel) as HTMLElement | null)?.click(); }

const result = (won: boolean): LevelResult => ({
  levelId: 'casa', won, stars: won ? 2 : 0, score: won ? 840 : 310, finalSocPct: won ? 0.34 : 0, spent: 12600, budget: 14000,
  panelsLost: 0, blackoutHour: won ? null : 27.5, durationSec: 92,
  tips: won
    ? ['Con una batería más llegabas a 3 estrellas.', 'Limpiá los paneles con polvo: rinden menos.']
    : ['De noche los paneles no generan: sumá baterías.', 'Apagá cargas no esenciales en "Salvá la ciudad".', 'Revisá el conector flojo con el multímetro.'],
});

function shopScreen(tab: ShopTab): ShopScreen {
  return new ShopScreen({ shop, wallet, inventory, isDemo: true, askParent: () => (scene === 'shop-result' ? Promise.resolve(true) : ParentalGateModal.ask(ui.screens, gate)), onBack: () => ui.screens.pop(), initialTab: tab });
}

function mkHud(): Hud {
  ui.setHudVisible(true);
  const hud = new Hud(ui.hudLayer, {
    onAction: log('action'), onInspect: log('inspect'), onMeter: log('meter'), onPause: () => ui.screens.push(pause()),
    onUseBooster: log('booster'), onToggleLoad: log('load'),
  });
  hud.mission.setTitle('Casa familiar');
  hud.mission.setTimer(47);
  hud.mission.setObjectives([
    { text: 'Instalá 6 paneles', state: 'ok' },
    { text: 'Colocá inversor y baterías', state: 'ok' },
    { text: 'Conectá los 3 cables al inversor', state: 'now' },
    { text: 'Revisá el conector flojo', state: 'alert' },
    { text: 'Activá la planta', state: 'todo' },
  ]);
  hud.boosters.setBoosters([
    { id: 'boost_hint', label: 'Pista', icon: 'hint', count: 2 },
    { id: 'boost_drone', label: 'Dron limpiador', icon: 'drone', count: 1 },
    { id: 'boost_battery', label: 'Batería de emergencia', icon: 'battery', count: 0 },
  ]);
  return hud;
}

function pause(): PauseMenu {
  const p: PauseMenu = new PauseMenu({ audio, levelName: 'Casa familiar', onResume: () => ui.screens.remove(p), onRestart: log('restart'), onExitToMap: log('exit') });
  return p;
}

const snap = (o: Partial<SimSnapshot>): SimSnapshot => ({
  hour: 14.5, irradiance: 0.9, genKw: 4.2, loadKw: 1.8, netKw: 2.4, socKwh: 8, capKwh: 14, socPct: 0.57,
  isNight: false, blackout: false, finished: false, won: false, ...o,
});

async function run(): Promise<void> {
  switch (scene) {
    case 'splash': ui.screens.push(new SplashScreen({ audio, version: '0.3.0', onStart: log('start') })); break;
    case 'menu': ui.screens.push(new MainMenu({ wallet, dailyBonus: bonus, onPlay: log('play'), onShop: log('shop'), onWardrobe: log('wr'), onSettings: log('set') })); break;
    case 'menu-claimed': {
      ui.screens.push(new MainMenu({ wallet, dailyBonus: bonus, onPlay: noop, onShop: noop, onWardrobe: noop, onSettings: noop }));
      click('.mm-bonus .btn'); await sleep(1200); break;
    }
    case 'map':
    case 'map-locked': {
      ui.screens.push(new LevelMapScreen({ levels: LEVELS, manager: levels, wallet, onPlay: log('play'), onBack: noop, onShop: noop }));
      if (scene === 'map-locked') { (document.querySelectorAll('.lm-bubble')[3] as HTMLElement).click(); }
      break;
    }
    case 'workshop': ui.screens.push(new WorkshopScreen({ level: LEVELS[0], boosters: CATALOG.filter((p) => p.kind === 'booster'), inventory, wallet, onBuild: log('build'), onBack: noop, onShop: noop })); click('.ws-bst'); break;
    case 'shop-soles': ui.screens.push(shopScreen('soles')); break;
    case 'shop-mejoras': ui.screens.push(shopScreen('mejoras')); click('.shop-card.is-booster .sc-price'); break;
    case 'shop-vestuario': ui.screens.push(shopScreen('vestuario')); break;
    case 'shop-result': ui.screens.push(shopScreen('soles')); click('.shop-card .btn'); await sleep(800); break;
    case 'gate': ui.screens.push(shopScreen('soles')); click('.shop-card .btn'); await sleep(50); click('.pgm-key'); click('.pgm-key:nth-child(2)'); click('.pgm-key.is-ok'); await sleep(400); break;
    case 'wardrobe': ui.screens.push(new WardrobeScreen({ catalog: CATALOG, inventory, wallet, onBack: noop, onShop: noop })); click('.wr-sw.is-locked'); break;
    case 'result-win':
    case 'result-lose': {
      world(scene === 'result-lose'); mkHud();
      const win = scene === 'result-win';
      ui.screens.push(new ResultScreen({ result: result(win), levelName: 'Nivel 1 · Casa familiar', solesEarned: win ? 100 : 0, unlockedName: win ? 'Escuela rural' : null, hasNext: true, bestScore: 980, onRetry: noop, onNext: noop, onMap: noop }));
      await sleep(1400); break;
    }
    case 'pause': world(); mkHud(); ui.screens.push(pause()); click('.pm-grid .btn'); break;
    case 'settings': ui.screens.push(new SettingsScreen({ quality: 'medium', audio, version: '0.3.0', onQualityChange: log('q'), onResetProgress: log('reset'), onBack: noop })); break;
    case 'settings-reset': ui.screens.push(new SettingsScreen({ quality: 'high', audio, version: '0.3.0', onQualityChange: noop, onResetProgress: noop, onBack: noop })); click('.set-reset .btn'); break;
    case 'hud': {
      world();
      const hud = mkHud();
      hud.stats.setVisible(true);
      hud.stats.update(snap({}));
      hud.actions.setAction('Conectar cable', 'normal');
      hud.alert.show('¡Alerta de viento Zonda!', 'Tocá los postes de cada fila para poner los paneles en defensa.', 12);
      ui.showToast('¡Panel instalado! Van 5 de 6', 'good', 60000);
      hud.prompt.show('Caja de conexión');
      hud.prompt.setScreenPosition(innerWidth * 0.52, innerHeight * 0.5);
      hud.meter.show();
      hud.actions.setMeterOn(true);
      hud.meter.set('38,4 V', 'V⎓ CC · fila 1', 'Fila 1 bien. Ahora medí la fila 2.', 'ok');
      break;
    }
    case 'hud-inspect': {
      world();
      const hud = mkHud();
      hud.stats.setVisible(true);
      hud.stats.update(snap({ hour: 16.25, irradiance: 0.3, genKw: 1.1 }));
      hud.actions.setAction('Soltar panel', 'drop');
      hud.inspect.show({ title: 'Inversor híbrido', body: 'Convierte la corriente continua de los paneles y baterías en corriente alterna para la ciudad. También decide cuándo cargar las baterías.', live: 'Ahora: entra 4,2 kW · sale 1,8 kW · carga 2,4 kW' });
      hud.prompt.show('Inversor');
      hud.prompt.setScreenPosition(innerWidth * 0.8, innerHeight * 0.45);
      break;
    }
    case 'hud-night': {
      world(true);
      const hud = mkHud();
      hud.mission.setCollapsed(true);
      hud.stats.setVisible(true);
      hud.stats.update(snap({ hour: 26.5, irradiance: 0, genKw: 0, loadKw: 3.2, netKw: -3.2, socPct: 0.14, isNight: true }));
      hud.actions.setAction('Acercate a algo', 'idle');
      hud.shedding.setLoads(LEVELS[0].loads, ['Cartel luminoso']);
      hud.shedding.show();
      ui.showToast('La batería baja rápido: apagá cargas', 'bad', 60000);
      break;
    }
    default: ui.showToast(`Escena desconocida: ${scene}`, 'bad');
  }
  await document.fonts.ready;
  await sleep(250);
  (window as unknown as { __ready: boolean }).__ready = true;
}

void run();
