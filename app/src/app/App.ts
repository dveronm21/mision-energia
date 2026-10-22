/**
 * App: composition root. Crea los servicios, la UI, el renderer y navega entre pantallas:
 * Splash → Menú (regalo de bienvenida y bono diario) → Mapa → Taller → Partida → Resultado.
 * Tienda (con control parental), Vestuario (cosméticos del técnico) y Ajustes (calidad y sonido).
 */
import type * as THREE from 'three';
import type { LevelId, LevelResult, Purchase, QualityLevel } from '../contracts';
import { SynthAudio } from '../core/Audio';
import { SaveStore } from '../core/SaveStore';
import type { BoosterId } from '../economy/Boosters';
import { COSMETIC_COLORS } from '../economy/Catalog';
import { DAILY_SOLES } from '../economy/RewardService';
import {
  Hud, LevelMapScreen, MainMenu, ParentalGateModal, PauseMenu, ResultScreen, SettingsScreen, ShopScreen,
  SplashScreen, UiRoot, WardrobeScreen, WorkshopScreen, type IDailyBonus, type ShopTab, type UiScreen,
} from '../ui';
import { DEFAULT_SETTINGS, Environment, ModelFactory, RendererFacade } from '../world/assets';
import { GameSession } from '../world/GameSession';
import { KeyboardInput } from './KeyboardInput';
import { Services } from './Services';

const QUALITY_KEY = 'settings.quality';
const BOOSTER_IDS: BoosterId[] = ['boost_hint', 'boost_drone', 'boost_battery', 'boost_budget'];

interface World3D { factory: ModelFactory; env: Environment; quality: QualityLevel; }
interface LevelRun { levelId: LevelId; purchase: Purchase; boosters: BoosterId[]; }

export class App {
  readonly store = new SaveStore();
  readonly bus = Services.createBus();
  readonly audio: SynthAudio;
  services: Services;
  readonly ui: UiRoot;
  readonly hud: Hud;
  readonly renderer: RendererFacade;
  private world3d: World3D | null = null;
  session: GameSession | null = null;
  private run: LevelRun | null = null;
  private quality: QualityLevel;
  private readonly keyboard: KeyboardInput;
  private last = 0;
  private welcomeChecked = false;
  private fontsReady: Promise<void> | null = null;

  constructor(private readonly appEl: HTMLElement, uiEl: HTMLElement) {
    this.audio = new SynthAudio(undefined, this.store);
    this.services = new Services(this.store, this.bus, this.audio);
    this.bus.on('sfx', (e) => this.audio.play(e.name));
    this.ui = new UiRoot(uiEl, { audio: this.audio });
    this.hud = new Hud(this.ui.hudLayer, {
      onAction: () => this.session?.doAction(),
      onInspect: () => this.session?.toggleInspect(),
      onMeter: () => this.session?.toggleMeter(),
      onPause: () => this.pause(),
      onUseBooster: (id) => this.session?.useBooster(id),
      onToggleLoad: (label, on) => this.session?.toggleLoad(label, on),
      onInspectClose: () => this.session?.closeInspect(),
    });
    this.quality = this.store.load<QualityLevel>(QUALITY_KEY, 'medium');
    if (!DEFAULT_SETTINGS[this.quality]) this.quality = 'medium';
    this.renderer = new RendererFacade({ container: appEl, settings: DEFAULT_SETTINGS[this.quality] });
    this.renderer.renderer.domElement.setAttribute('aria-hidden', 'true');
    this.keyboard = new KeyboardInput({
      onAction: () => this.session?.doAction(),
      onInspect: () => this.session?.toggleInspect(),
      onMeter: () => this.session?.toggleMeter(),
      onBack: () => { this.handleBack(); },
    });
    window.addEventListener('resize', this.onResize);
    document.addEventListener('visibilitychange', () => { if (document.hidden && this.session && !this.session.paused && this.session.phase !== 'finished') this.pause(); });
    (window as unknown as { meHandleBack: () => boolean }).meHandleBack = () => this.handleBack();
  }

  start(): void {
    this.onResize();
    this.showSplash();
    requestAnimationFrame(this.frame);
  }

  /* ================================================================ navegación */

  private get s(): Services { return this.services; }

  showSplash(): void {
    this.ui.screens.reset(new SplashScreen({ audio: this.audio, version: __APP_VERSION__, onStart: () => this.showMenu() }));
  }

  showMenu(): void {
    this.endSession();
    const daily: IDailyBonus = {
      available: () => this.s.rewards.canClaimDaily(),
      amount: () => DAILY_SOLES,
      claim: () => this.s.rewards.claimDaily(),
    };
    this.ui.screens.reset(new MainMenu({
      wallet: this.s.wallet, dailyBonus: daily,
      onPlay: () => this.pushMap(),
      onShop: () => this.pushShop(),
      onWardrobe: () => this.pushWardrobe(),
      onSettings: () => this.pushSettings(),
    }));
    if (!this.welcomeChecked) {
      this.welcomeChecked = true;
      if (this.s.rewards.canClaimWelcome()) {
        const got = this.s.rewards.claimWelcome();
        if (got > 0) window.setTimeout(() => this.ui.showToast(`¡Regalo de bienvenida! Sumaste ${got} Soles.`, 'good', 3600), 350);
        this.audio.play('coin');
      }
    }
    this.warmUp();
  }

  /** Menú → Mapa (con "atrás" al menú). */
  private pushMap(): void {
    this.ui.screens.push(this.mapScreen());
  }

  private mapScreen(): LevelMapScreen {
    return new LevelMapScreen({
      levels: this.s.levels.all(), manager: this.s.progress, wallet: this.s.wallet,
      onPlay: (id) => this.pushWorkshop(id),
      onBack: () => this.ui.screens.pop(),
      onShop: () => this.pushShop(),
    });
  }

  /** Pila Menú → Mapa (al volver de una partida). */
  showMap(): void {
    this.showMenu();
    this.pushMap();
  }

  pushWorkshop(id: LevelId, initial?: Purchase): void {
    const level = this.s.levels.get(id);
    const ws = new WorkshopScreen({
      level, boosters: this.s.catalog.byKind('booster'), inventory: this.s.inventory, wallet: this.s.wallet, initial,
      budgetFor: (boosted) => this.s.boosters.budgetFor(level, boosted),
      onBuild: (purchase, ids) => {
        const used = ids.filter((x): x is BoosterId => (BOOSTER_IDS as string[]).includes(x)).filter((b) => this.s.boosters.use(b));
        this.startLevel({ levelId: id, purchase, boosters: used });
      },
      onBack: () => this.ui.screens.pop(),
      onShop: () => this.pushShop('mejoras'),
    });
    this.ui.screens.push(ws);
  }

  pushShop(tab?: ShopTab): void {
    this.ui.screens.push(new ShopScreen({
      shop: this.s.shop, wallet: this.s.wallet, inventory: this.s.inventory, isDemo: this.s.shop.isDemo(),
      askParent: () => ParentalGateModal.ask(this.ui.screens, this.s.gate),
      onBack: () => this.ui.screens.pop(),
      initialTab: tab,
    }));
  }

  pushWardrobe(): void {
    this.ui.screens.push(new WardrobeScreen({
      catalog: this.s.catalog.all(), inventory: this.s.inventory, wallet: this.s.wallet,
      onBack: () => this.ui.screens.pop(),
      onShop: () => this.pushShop('vestuario'),
    }));
  }

  pushSettings(): void {
    this.ui.screens.push(new SettingsScreen({
      quality: this.quality, audio: this.audio, version: __APP_VERSION__,
      onQualityChange: (q) => this.setQuality(q),
      onResetProgress: () => this.resetProgress(),
      onBack: () => this.ui.screens.pop(),
    }));
  }

  private setQuality(q: QualityLevel): void {
    this.quality = q;
    this.store.save(QUALITY_KEY, q);
    this.renderer.setQuality(DEFAULT_SETTINGS[q]);
  }

  private resetProgress(): void {
    const q = this.quality, muted = this.audio.muted();
    this.store.clearAll();
    this.store.save(QUALITY_KEY, q);
    this.audio.setMuted(muted);
    this.services = new Services(this.store, this.bus, this.audio);
    this.welcomeChecked = false;
  }

  /* ================================================================ partida */

  private cosmetics(): { helmet?: number; vest?: number } {
    const inv = this.s.inventory;
    const h = inv.equippedCosmetic('helmet'), v = inv.equippedCosmetic('vest');
    return { helmet: h ? COSMETIC_COLORS[h] : undefined, vest: v ? COSMETIC_COLORS[v] : undefined };
  }

  /** Crea (o recrea si cambió la calidad) la fábrica de modelos y el ambiente. */
  private ensureWorld(): World3D {
    if (this.world3d && this.world3d.quality === this.quality) return this.world3d;
    if (this.world3d) {
      this.world3d.env.scene.traverse((o) => { (o as THREE.Mesh).geometry?.dispose(); });
      this.world3d.factory.dispose();
    }
    const factory = new ModelFactory({ quality: this.quality, skinning: this.renderer.renderer.capabilities.isWebGL2 });
    this.fontsReady = factory.textures.loadFonts('fonts/');
    const env = new Environment(factory, { quality: this.quality });
    this.world3d = { factory, env, quality: this.quality };
    return this.world3d;
  }

  /** Prepara el mundo 3D en segundo plano mientras el jugador está en el menú. */
  private warmUp(): void {
    if (this.world3d) return;
    window.setTimeout(() => { if (!this.session) this.ensureWorld(); }, 400);
  }

  startLevel(run: LevelRun): void {
    this.endSession();
    this.run = run;
    const w = this.ensureWorld();
    const level = this.s.levels.get(run.levelId);
    this.session = new GameSession({
      factory: w.factory, env: w.env, camera: this.renderer.camera, dragSurface: this.renderer.renderer.domElement,
      ui: this.ui, hud: this.hud, audio: this.audio, inventory: this.s.inventory, boosters: this.s.boosters,
      level, purchase: run.purchase, spent: this.s.levels.cost(level, run.purchase), activeBoosters: run.boosters,
      cosmetics: this.cosmetics(),
      onFinished: (r) => this.onFinished(r),
    });
    this.ui.screens.reset();
    this.ui.setHudVisible(true);
    this.bus.emit({ type: 'level-started', levelId: run.levelId });
    this.last = performance.now();
    void this.fontsReady;
  }

  private onFinished(result: LevelResult): void {
    const s = this.s;
    const { solesEarned, newlyUnlocked } = s.progress.recordResult(result);
    this.bus.emit({ type: 'level-finished', result });
    const next = s.levels.next(result.levelId);
    const level = s.levels.get(result.levelId);
    this.ui.setHudVisible(false);
    this.ui.screens.push(new ResultScreen({
      result, levelName: `Nivel ${level.order} · ${level.name}`, solesEarned,
      unlockedName: newlyUnlocked ? s.levels.get(newlyUnlocked).name : null,
      hasNext: !!next && s.progress.isUnlocked(next.id),
      bestScore: s.progress.progress(result.levelId).bestScore,
      onRetry: () => { const r = this.run; this.showMap(); if (r) this.pushWorkshop(r.levelId, r.purchase); },
      onNext: () => { this.showMap(); if (next) this.pushWorkshop(next.id); },
      onMap: () => this.showMap(),
    }));
  }

  pause(): void {
    const ss = this.session;
    if (!ss || ss.paused || ss.phase === 'finished') return;
    ss.paused = true;
    this.hud.joystick.reset();
    const menu: UiScreen = new PauseMenu({
      audio: this.audio, levelName: ss.level.name,
      onResume: () => this.resume(menu),
      onRestart: () => { const r = this.run; if (r) this.startLevel(r); },
      onExitToMap: () => this.showMap(),
    });
    this.ui.screens.push(menu);
  }

  private resume(menu: UiScreen): void {
    this.ui.screens.remove(menu);
    if (this.session) { this.session.paused = false; this.last = performance.now(); }
  }

  private endSession(): void {
    if (!this.session) return;
    this.session.dispose();
    this.session = null;
    this.ui.setHudVisible(false);
    this.audio.setWind(false);
  }

  /** Botón atrás de Android. false = no había nada que cerrar (la app puede salir). */
  handleBack(): boolean {
    if (this.ui.handleBack()) return true;
    if (this.session && this.session.phase !== 'finished') { this.pause(); return true; }
    return false;
  }

  /* ================================================================ bucle */

  private onResize = (): void => {
    this.renderer.resize(this.appEl.clientWidth || window.innerWidth, this.appEl.clientHeight || window.innerHeight);
  };

  private frame = (now: number): void => {
    requestAnimationFrame(this.frame);
    const dt = Math.min(0.1, Math.max(0, (now - this.last) / 1000));
    this.last = now;
    const ss = this.session;
    if (!ss || document.hidden || !this.world3d) return;
    const joy = this.hud.joystick.vector(), kb = this.keyboard.vector();
    ss.update(dt, { x: Math.max(-1, Math.min(1, joy.x + kb.x)), y: Math.max(-1, Math.min(1, joy.y + kb.y)) });
    if (this.session === ss) this.renderer.render(this.world3d.env.scene);
  };
}
