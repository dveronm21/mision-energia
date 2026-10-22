/**
 * GameSession: una partida de un nivel.
 *   build    → el jugador arma la planta (reloj detenido a la hora de activación).
 *   running  → corre el simulador y el clima (Zonda, nubes, noche); se puede medir, defender y limpiar.
 *   finished → Scoring y aviso a la App (onFinished) tras una breve pausa para ver el final.
 * Implementa SessionPort (reglas que usan las estrategias de interacción) y MissionFacts (objetivos).
 */
import * as THREE from 'three';
import type {
  IAudio, IInventory, LevelDefinition, LevelResult, PlantState, Purchase, SfxName, SimSnapshot, WeatherPhase,
} from '../contracts';
import type { BoosterId, Boosters } from '../economy/Boosters';
import { EnergySimulator } from '../sim/EnergySimulator';
import { Scoring } from '../sim/Scoring';
import { StormImpact } from '../sim/StormImpact';
import { WeatherSchedule } from '../sim/WeatherSchedule';
import { blockActive } from '../sim/solar';
import type { Hud, ToastKind, UiRoot } from '../ui';
import { fmt1, fmtHour } from '../ui/format';
import type { Environment, ModelFactory } from './assets';
import { CameraRig } from './CameraRig';
import { CABLE_NAME } from './entities/Cable';
import type { FlowHandle } from './entities/EnergyFlow';
import type { Mount } from './entities/Mount';
import type { Pickup } from './entities/Pickups';
import { HandsController } from './HandsController';
import { Highlights } from './interaction/Highlights';
import { Inspectables, PANEL_VOC, type LiveSource } from './interaction/Inspectables';
import { InteractionSystem } from './interaction/InteractionSystem';
import { ConsoleProvider, FieldCareProvider, MeterProvider, PickupProvider, PlacementProvider, WiringProvider } from './interaction/Providers';
import type { SessionPhase, SessionPort } from './interaction/SessionPort';
import type { CableColor, InspectEntry, TerminalId, WorldAction } from './interaction/types';
import { MissionTracker, type MissionFacts } from './MissionTracker';
import { Player } from './Player';
import { PlantWorld } from './PlantWorld';

/** Horas de juego por segundo real (normal / durante aviso y tormenta de Zonda). */
export const CLOCK = { normal: 0.45, slow: 0.05 };

export interface SessionDeps {
  factory: ModelFactory;
  env: Environment;
  camera: THREE.PerspectiveCamera;
  /** Elemento que recibe el arrastre para girar la cámara (el canvas). */
  dragSurface: HTMLElement;
  ui: UiRoot;
  hud: Hud;
  audio: IAudio;
  inventory: IInventory;
  boosters: Boosters;
  level: LevelDefinition;
  purchase: Purchase;
  /** Créditos gastados en el taller. */
  spent: number;
  /** Boosters ya consumidos en el taller para esta partida. */
  activeBoosters: BoosterId[];
  cosmetics: { helmet?: number; vest?: number };
  onFinished(result: LevelResult): void;
}

export interface InputVector { x: number; y: number; }

const CABLE_RULES: Record<CableColor, TerminalId> = { orange: 'protection', blue: 'inverter', violet: 'inverter' };
const FLOW_DC = 0xffd27a, FLOW_BAT = 0x7fb3ff, FLOW_AC = 0xd6c2ff, FLOW_GRID = 0xfff3a0;

export class GameSession implements SessionPort, MissionFacts, LiveSource {
  readonly level: LevelDefinition;
  readonly purchase: Purchase;
  readonly world: PlantWorld;
  readonly hands: HandsController;
  readonly player: Player;
  readonly camRig: CameraRig;
  phase: SessionPhase = 'build';
  weather: WeatherPhase = 'calm';
  paused = false;
  /** Multiplicador del reloj de juego (depuración). */
  timeScale = 1;
  readonly connector = { measured: false, rowFound: false, fixed: false };

  private readonly sim = new EnergySimulator();
  private readonly weatherSchedule: WeatherSchedule;
  private readonly storm = new StormImpact();
  private readonly interaction: InteractionSystem;
  private readonly tracker: MissionTracker;
  private readonly highlights = new Highlights();
  private snap: SimSnapshot | null = null;
  private hour: number;
  private zondaFx = 0;
  private stormApplied = false;
  private overHandled = false;
  private panelsLost = 0;
  private shed: string[] = [];
  private nightLoads: string[] | null = null;
  private elapsed = 0;
  private finishTimer = -1;
  private hudTimer = 0;
  private currentAction: WorldAction | null = null;
  private currentInspect: InspectEntry | null = null;
  private openInspectId: string | null = null;
  private lastPrompt = '';
  private hintOn: boolean;
  private droneOn: boolean;
  private readonly bonusKwh: number;
  private readonly flows: { rows: (FlowHandle | null)[]; orange?: FlowHandle; link?: FlowHandle; blue?: FlowHandle; violet?: FlowHandle; grid?: FlowHandle; pump?: FlowHandle } = { rows: [] };
  private readonly tmp = new THREE.Vector3();
  private disposed = false;

  constructor(private readonly d: SessionDeps) {
    this.level = d.level;
    this.purchase = d.purchase;
    this.hour = d.level.startHour;
    this.weatherSchedule = new WeatherSchedule(d.level.events);
    this.hintOn = d.activeBoosters.includes('boost_hint');
    this.droneOn = d.activeBoosters.includes('boost_drone');
    this.bonusKwh = d.boosters.bonusKwh(d.activeBoosters.includes('boost_battery'));

    const f = d.factory;
    this.world = new PlantWorld(f, d.level, d.purchase, (row) => this.cleanRow(row, true));
    this.flows.rows = this.world.rowWires.map(() => null);
    d.env.scene.add(this.world.root);
    this.world.root.add(this.highlights.root);

    const rig = f.createWorker(d.cosmetics);
    this.world.root.add(rig.root);
    this.player = new Player(rig, this.world.colliders, (x, z) => this.world.floorAt(x, z), this.world.layout.spawn);
    this.hands = new HandsController(f, rig);
    this.camRig = new CameraRig(d.camera, d.dragSurface);
    this.camRig.snap();

    this.interaction = new InteractionSystem(
      [new PickupProvider(this), new PlacementProvider(this), new WiringProvider(this), new MeterProvider(this), new FieldCareProvider(this), new ConsoleProvider(this)],
      [new Inspectables(this)],
    );
    this.tracker = new MissionTracker(this);
    this.world.batteries.forEach((b) => b.setCharge(d.level.startSoc));

    const hud = d.hud;
    hud.reset();
    hud.mission.setTitle(`Nivel ${d.level.order} · ${d.level.name}`);
    hud.mission.setTimerVisible(true);
    this.refreshBoosterBar();
    this.syncHud();
    this.d.env.update(0, this.hour, { zonda: 0, clouds: this.weatherSchedule.cloudinessAt(this.hour), follow: this.player.position });
    this.toast(d.level.events.looseConnector
      ? 'Empezá por el pallet de paneles. Ojo: uno puede venir con el conector flojo.'
      : 'Empezá por el pallet de paneles: está cerca tuyo, a la izquierda.');
  }

  /* ================================================================ SessionPort */

  get isNight(): boolean { return !!this.snap?.isNight; }
  get won(): boolean { return !!this.snap?.won; }
  get running(): boolean { return this.phase === 'running'; }
  isRunning(): boolean { return this.phase !== 'build'; }

  toast(text: string, kind: ToastKind = 'info'): void {
    this.d.ui.showToast(text, kind, kind === 'bad' ? 4600 : 3200);
    if (kind === 'bad') this.sfx('bad');
  }

  sfx(name: SfxName): void { this.d.audio.play(name); }

  takeFromPallet(): void {
    const faulty = this.world.pallet.take();
    this.hands.carry({ kind: 'panel', faulty });
    this.sfx('pick');
    this.changed();
  }

  takePickup(p: Pickup): void {
    this.hands.carry({ kind: p.kind, faulty: p.faulty });
    this.world.removePickup(p);
    this.sfx('pick');
    this.changed();
  }

  installPanel(m: Mount): void {
    const h = this.hands.hands;
    if (h.kind !== 'carry' || h.item.kind !== 'panel') return;
    this.hands.clear();
    m.install(h.item.faulty);
    this.ensureRowWire(m.row);
    this.sfx('place');
    const n = this.world.panelsInstalled(), total = this.purchase.panels;
    this.toast(n >= total ? '¡Campo solar completo!' : `Panel ${n} de ${total} instalado.`, 'good');
    this.changed();
  }

  installProtection(): void {
    this.hands.clear();
    this.world.protection.install();
    this.world.linkProtection();
    this.sfx('place');
    this.toast('Protección instalada: corta el circuito si hay una falla.', 'good');
    this.changed();
  }

  installBattery(i: number): void {
    const slot = this.world.batteries[i];
    if (!slot || slot.installed) return;
    this.hands.clear();
    slot.install();
    slot.setCharge(this.level.startSoc);
    this.world.colliders.add(slot.pos.x, slot.pos.z, 0.5, 0.32);
    this.sfx('place');
    this.toast(`Batería ${this.world.batteriesInstalled()} instalada: ${fmt1(this.level.batteryKwh)} kWh para guardar energía.`, 'good');
    this.changed();
  }

  installKit(_row: number): void {
    this.hands.clear();
    this.world.kitInstalled = true;
    this.sfx('place');
    this.toast('Trabas instaladas: el Zonda no podrá arrancar paneles.', 'good');
    this.changed();
  }

  takeCable(color: CableColor, from: TerminalId, point: THREE.Vector3): void {
    this.hands.takeCable(color, from, point);
    this.sfx('pick');
    this.toast(`Llevá el ${CABLE_NAME[color]} hasta su equipo.`);
    this.changed();
  }

  connectCable(to: TerminalId): void {
    const h = this.hands.hands;
    if (h.kind !== 'cable') return;
    if (CABLE_RULES[h.color] !== to) { this.toast(this.cableHint(h.color, to), 'bad'); return; }
    const w = this.world, c = w.cables, room = w.layout.room;
    let pts: THREE.Vector3[];
    if (h.color === 'orange') pts = c.groundRoute(w.junction.terminal, w.protection.terminal, { z: w.layout.junction.z + 0.45 });
    else if (h.color === 'blue') pts = c.groundRoute(h.fromPoint, w.inverter.terminalFor('bat'), { z: room.wallZ + 1.45 });
    else pts = c.groundRoute(w.switchboard.terminal, w.inverter.terminalFor('ac'), { z: room.wallZ + 1.15 });
    c.connect(h.color, pts);
    this.hands.clear();
    this.sfx('ok');
    this.toast(`¡Bien! Conectaste el ${CABLE_NAME[h.color]}.`, 'good');
    this.changed();
  }

  /** Pista didáctica cuando el cable va al equipo equivocado. */
  private cableHint(color: CableColor, to: TerminalId): string {
    if (color === 'orange' && to === 'inverter') return 'El cable de los paneles no va directo al inversor: primero pasa por la protección, en la pared a la izquierda del inversor.';
    if (color === 'orange') return 'El cable naranja lleva la corriente continua de los paneles. Llevalo hasta la protección.';
    if (color === 'blue') return 'Este es el cable de las baterías: tiene que llegar al inversor, que decide cuándo cargarlas y descargarlas.';
    return 'El tablero recibe la corriente alterna que sale del inversor. Llevá el cable violeta al inversor.';
  }

  measureRows(): void {
    const w = this.world, m = this.d.hud.meter;
    this.connector.measured = true;
    this.sfx('beep');
    m.show();
    if (this.running && this.isNight) {
      m.set('0 V', 'V⎓ por fila', 'De noche los paneles no generan tensión. Medí de día para buscar fallas.', 'idle');
      return;
    }
    const vals = w.rows.map((_, r) => (w.panelsInRow(r) === 0 ? null : w.rowOpen(r) ? 0 : w.panelsInRow(r) * PANEL_VOC));
    const text = vals.map((v, r) => `F${r + 1} ${v === null ? '–' : v}`).join('  ');
    const bad = vals.findIndex((v) => v === 0);
    if (bad >= 0) {
      this.connector.rowFound = true;
      m.set(text, 'V⎓ por fila', `La fila ${bad + 1} marca 0 V: hay un circuito abierto. Medí panel por panel en esa fila.`, 'bad');
    } else if (vals.every((v) => v === null)) {
      m.set(text, 'V⎓ por fila', 'Todavía no hay paneles conectados a la caja.', 'idle');
    } else {
      m.set(text, 'V⎓ por fila', `Tensiones normales: cada panel suma unos ${PANEL_VOC} V en serie.`, 'ok');
    }
    this.changed();
  }

  measurePanel(mt: Mount): void {
    const m = this.d.hud.meter;
    this.sfx('beep');
    m.show();
    if (mt.faulty) {
      mt.faultFound = true;
      this.connector.rowFound = true;
      m.set('OL', 'Ω conector', `Panel bien (${PANEL_VOC} V), pero el conector está abierto: tocá Reconectar.`, 'bad');
    } else {
      m.set('41,2 V', 'V⎓ panel', 'Panel y conector en buen estado.', 'ok');
    }
    this.changed();
  }

  repairPanel(mt: Mount): void {
    mt.repair();
    this.connector.fixed = true;
    this.sfx('ok');
    this.d.hud.meter.set('41,2 V', 'V⎓ panel', 'Conector reparado: la fila vuelve a sumar tensión.', 'ok');
    this.toast('Conector reconectado. La fila vuelve a generar.', 'good');
    this.changed();
  }

  setDefense(row: number): void {
    this.world.posts[row].setDefense(true);
    for (const m of this.world.rows[row]) m.setDefense(true);
    this.sfx('place');
    this.toast(`Fila ${row + 1} en horizontal: el viento ya no la empuja.`, 'good');
    this.changed();
  }

  cleanRow(row: number, byDrone = false): void {
    if (!this.world.rowDirty(row)) return;
    for (const m of this.world.rows[row]) m.setDirty(false);
    this.sfx('ok');
    this.toast(byDrone ? `El dron limpió la fila ${row + 1}.` : `Fila ${row + 1} limpia: recupera toda su generación.`, 'good');
    this.changed();
  }

  tryActivate(): void {
    const w = this.world, lv = this.level, miss: string[] = [];
    if (w.panelsInstalled() < lv.minPanels) miss.push(`instalá al menos ${lv.minPanels} paneles`);
    if (!w.protection.installed) miss.push('instalá la protección');
    const nb = w.batteriesInstalled();
    if (nb < this.purchase.batteries) miss.push(this.purchase.batteries === 1 ? 'instalá la batería' : `instalá las ${this.purchase.batteries} baterías`);
    for (const c of ['orange', 'blue', 'violet'] as CableColor[]) if (!w.cables.isConnected(c)) miss.push(`conectá el cable ${c === 'orange' ? 'naranja' : c === 'blue' ? 'azul' : 'violeta'}`);
    if (miss.length) { this.toast('Todavía no: ' + miss.slice(0, 2).join(' y ') + '.', 'bad'); return; }
    this.activate();
  }

  /* ================================================================ ciclo de vida */

  private activate(): void {
    const w = this.world;
    this.sim.start(this.level, this.plantState());
    this.snap = this.sim.snapshot();
    this.phase = 'running';
    const add = (run: { curve: THREE.Curve<THREE.Vector3> } | null | undefined, color: number) => (run ? w.flow.add(run.curve, color) : undefined);
    this.flows.orange = add(w.cables.connected.orange, FLOW_DC);
    this.flows.link = add(w.protectionLink, FLOW_DC);
    this.flows.blue = add(w.cables.connected.blue, FLOW_BAT);
    this.flows.violet = add(w.cables.connected.violet, FLOW_AC);
    this.flows.grid = add(w.city.line, FLOW_GRID);
    this.flows.pump = add(w.pumpWire, FLOW_AC);
    if (this.flows.violet) this.flows.violet.dir = -1;
    w.console.setActive(true);
    this.d.hud.stats.setVisible(true);
    this.d.hud.stats.update(this.snap);
    this.sfx('power');
    if (w.anyFaulty()) this.toast('¡Planta activada! Pero una fila marca 0 V en el inversor. Usá el multímetro.', 'bad');
    else this.toast('¡Planta activada! Mirá cómo viaja la energía.', 'good');
    this.changed();
  }

  private ensureRowWire(r: number): void {
    this.world.ensureRowWire(r);
    const run = this.world.rowWires[r];
    if (run && !this.flows.rows[r]) this.flows.rows[r] = this.world.flow.add(run.curve, FLOW_DC);
  }

  plantState(): PlantState {
    const w = this.world;
    return {
      panelsPerRow: w.rows.map((_, r) => w.panelsInRow(r)),
      rowOpen: w.rows.map((_, r) => w.rowOpen(r)),
      rowDirty: w.rows.map((_, r) => w.rowDirty(r)),
      rowDefense: w.posts.map((p) => p.inDefense),
      batteries: w.batteriesInstalled(),
      protectionInstalled: w.protection.installed,
      cablesOk: (['orange', 'blue', 'violet'] as CableColor[]).every((c) => w.cables.isConnected(c)),
      shedLoads: [...this.shed],
      bonusKwh: this.bonusKwh,
    };
  }

  snapshot(): SimSnapshot | null { return this.snap; }

  /** Un cuadro de juego. input: joystick/teclado. */
  update(dtReal: number, input: InputVector): void {
    if (this.disposed) return;
    const dt = Math.min(0.05, Math.max(0, dtReal));
    if (!this.paused) {
      if (this.phase !== 'finished') this.elapsed += Math.min(0.25, Math.max(0, dtReal));
      this.player.speedFactor = (this.hands.kind === 'carry' ? 0.85 : 1) * (this.weather === 'zonda-storm' ? 0.8 : 1);
      this.player.pose = this.hands.pose();
      const canMove = this.phase !== 'finished';
      this.player.update(dt, canMove ? input.x : 0, canMove ? input.y : 0, this.camRig.yaw);
      if (this.phase === 'running') this.stepSim(dt);
      if (this.phase === 'finished' && this.finishTimer >= 0) {
        this.finishTimer += dt;
        if (this.finishTimer > 1.6) { this.finishTimer = -1; this.d.onFinished(this.result()); }
      }
    }
    this.world.update(dt, dt * Math.max(1, this.timeScale));
    this.highlights.update(dt);
    this.updateVisuals(dt);
    this.camRig.shake = this.weather === 'zonda-storm' ? 1 : this.weather === 'zonda-warning' ? 0.15 : 0;
    this.camRig.update(dt, this.player.position);
    const live = this.hands.hands;
    this.world.cables.updateLive(live.kind === 'cable' ? live.fromPoint : null, this.hands.handWorld(), live.kind === 'cable' ? live.color : null);
    if (!this.paused && this.phase !== 'finished') this.updateInteraction();
    this.hudTimer -= dt;
    if (this.hudTimer <= 0) { this.hudTimer = 0.16; this.syncHud(); }
  }

  private stepSim(dt: number): void {
    const phase = this.weatherSchedule.phaseAt(this.hour);
    if (phase !== this.weather) this.onWeather(phase);
    const hps = (phase === 'zonda-warning' || phase === 'zonda-storm' ? CLOCK.slow : CLOCK.normal) * this.timeScale;
    const snap = this.sim.step(dt * hps, this.plantState(), phase);
    this.snap = snap;
    this.hour = snap.hour;
    this.checkNightLoads(snap);
    if (snap.finished) this.finish(snap);
  }

  private onWeather(phase: WeatherPhase): void {
    this.weather = phase;
    const hud = this.d.hud, w = this.world;
    if (phase === 'zonda-warning') {
      this.sfx('alarm');
      hud.alert.show('¡Alerta de viento Zonda!', w.kitInstalled ? 'Las trabas sostienen los paneles, pero se van a llenar de polvo.' : 'Corré a los postes y poné cada fila en defensa.', this.warningSeconds());
    }
    if (phase === 'zonda-storm' || (phase === 'zonda-over' && !this.stormApplied)) this.applyStorm();
    if (phase === 'zonda-storm') {
      this.d.audio.setWind(true);
      hud.alert.show('Zonda soplando', 'Ráfagas de 70 km/h · los paneles se llenan de polvo', null);
    }
    if (phase === 'zonda-over' && !this.overHandled) {
      this.overHandled = true;
      this.d.audio.setWind(false);
      hud.alert.hide();
      for (const p of w.posts) p.setDefense(false);
      for (const m of w.mounts) m.setDefense(false);
      const dirty = w.rows.map((_, r) => r).filter((r) => w.rowDirty(r));
      if (dirty.length && this.droneOn) this.launchDrone();
      else this.toast(dirty.length ? 'Pasó el Zonda. Los paneles quedaron con polvo: limpialos en el poste de cada fila.' : 'Pasó el Zonda.', dirty.length ? 'bad' : 'good');
    }
    this.changed();
  }

  private applyStorm(): void {
    if (this.stormApplied) return;
    this.stormApplied = true;
    const w = this.world;
    const hit = this.storm.apply(this.plantState(), w.kitInstalled);
    this.panelsLost += hit.panelsLost;
    hit.lostPerRow.forEach((lost, r) => {
      if (!lost) return;
      const victim = [...w.rows[r]].reverse().find((m) => m.filled);
      if (!victim) return;
      const faulty = victim.remove();
      const p = victim.position;
      w.addPickup('panel', new THREE.Vector3(p.x + 0.6 + r * 0.5, 0, -0.9 - r * 0.25), faulty, 0.4 + r);
    });
    hit.plant.rowDirty.forEach((dirty, r) => { if (dirty) for (const m of w.rows[r]) m.setDirty(true); });
    if (hit.panelsLost > 0) this.toast(hit.panelsLost === 1 ? '¡El viento arrancó un panel! Buscalo en el camino y volvé a colocarlo.' : `¡El viento arrancó ${hit.panelsLost} paneles! Buscalos en el camino y volvé a colocarlos.`, 'bad');
  }

  private launchDrone(): void {
    const w = this.world;
    const rows = w.rows.map((_, r) => r).filter((r) => w.rowDirty(r)).map((r) => {
      const ms = w.layout.rows[r].mounts;
      return { row: r, from: ms[0].clone().add(new THREE.Vector3(-1.2, 0, 0)), to: ms[ms.length - 1].clone().add(new THREE.Vector3(1.2, 0, 0)) };
    });
    if (!rows.length) return;
    w.drone.start(rows);
    this.toast('Pasó el Zonda. ¡El dron limpiador ya salió a limpiar los paneles!', 'good');
  }

  private warningSeconds(): number {
    return this.weatherSchedule.warningRemaining(this.hour) / (CLOCK.slow * this.timeScale);
  }

  /** "Salvá la ciudad": al llegar la noche, ofrecer apagar cargas no esenciales que consumen de noche. */
  private checkNightLoads(s: SimSnapshot): void {
    const hud = this.d.hud;
    if (s.isNight && this.nightLoads === null) {
      const lv = this.level;
      const labels = lv.loads.filter((l) => !l.essential && this.activeUntilEnd(l, s.hour)).map((l) => l.label);
      this.nightLoads = [...new Set(labels)];
      if (this.nightLoads.length) {
        hud.shedding.setLoads(lv.loads.filter((l) => this.nightLoads!.includes(l.label)), this.shed);
        hud.shedding.show();
        this.toast('Se hizo de noche: apagá lo que no haga falta para que la batería llegue a la mañana.');
      }
    }
    if (!s.isNight && this.nightLoads && hud.shedding.visible) hud.shedding.hide();
  }

  private activeUntilEnd(l: LevelDefinition['loads'][number], from: number): boolean {
    for (let h = from; h < this.level.endHour; h += 0.25) if (blockActive(l, h)) return true;
    return false;
  }

  toggleLoad(label: string, on: boolean): void {
    this.shed = on ? this.shed.filter((x) => x !== label) : [...new Set([...this.shed, label])];
  }

  private finish(s: SimSnapshot): void {
    if (this.phase === 'finished') return;
    this.phase = 'finished';
    this.finishTimer = 0;
    this.d.audio.setWind(false);
    this.d.hud.alert.hide();
    this.d.hud.shedding.hide();
    this.hands.clear();
    this.d.hud.meter.hide();
    this.d.hud.actions.setMeterOn(false);
    this.sfx(s.won ? 'win' : 'lose');
    if (!s.won) this.toast(`¡Apagón! La batería se agotó a las ${fmtHour(s.hour)}.`, 'bad');
    this.changed();
  }

  private result(): LevelResult {
    const s = this.snap ?? this.sim.snapshot();
    const plant = this.plantState();
    const nightLoads = this.nightLoads ?? [];
    return new Scoring().evaluate(this.level, {
      won: s.won, finalSocPct: s.socPct, spent: this.d.spent, panelsLost: this.panelsLost,
      blackoutHour: s.blackout ? s.hour : null, durationSec: Math.round(this.elapsed),
      hadOpenRowAtEnd: plant.rowOpen.some(Boolean), hadDirtyRowAtEnd: plant.rowDirty.some(Boolean),
      batteries: plant.batteries, panels: this.world.panelsInstalled(),
      nonEssentialOn: nightLoads.some((l) => !this.shed.includes(l)),
    });
  }

  /* ================================================================ interacción y HUD */

  private updateInteraction(): void {
    const pick = this.interaction.update(this.hands.hands, this.player.position);
    this.currentAction = pick.action;
    this.currentInspect = pick.inspect;
    const hud = this.d.hud;
    const h = this.hands.hands;
    const a = pick.action;
    if (a) hud.actions.setAction(a.label, 'normal');
    else if (h.kind === 'meter') hud.actions.setAction('Medir', 'idle');
    else if (h.kind === 'cable') hud.actions.setAction('Soltar cable', 'drop');
    else if (h.kind === 'carry') hud.actions.setAction('Soltar', 'drop');
    else hud.actions.setAction(this.phase === 'running' ? 'Planta en marcha' : 'Acercate a algo', 'idle');
    hud.actions.setInspectEnabled(!!pick.inspect || hud.inspect.visible);
    const floorY = a ? this.world.floorAt(a.pos.x, a.pos.z) : 0;
    this.highlights.setAction(a ? a.pos : null, floorY);
    if (a) {
      if (this.lastPrompt !== a.label) { hud.prompt.show(a.label); this.lastPrompt = a.label; }
      this.tmp.set(a.pos.x, floorY + 2.3, a.pos.z).project(this.d.camera);
      const visible = this.tmp.z < 1 && this.tmp.z > -1;
      hud.prompt.setScreenPosition((this.tmp.x + 1) / 2 * window.innerWidth, (1 - this.tmp.y) / 2 * window.innerHeight, visible);
    } else if (this.lastPrompt) { hud.prompt.hide(); this.lastPrompt = ''; }
    const hint = this.hintOn ? this.tracker.hintTarget() : null;
    this.highlights.setHint(hint, hint ? this.world.floorAt(hint.x, hint.z) : 0);
  }

  /** Botón de acción (o tecla E). */
  doAction(): void {
    if (this.paused || this.phase === 'finished') return;
    if (this.currentAction) { this.currentAction.run(); this.updateInteraction(); return; }
    const h = this.hands.hands;
    if (h.kind === 'meter') { this.toast('Con el multímetro podés medir la caja de conexión o un panel instalado.'); return; }
    if (h.kind === 'cable') { this.hands.clear(); this.toast('Soltaste el cable. Podés volver a tomarlo desde su equipo.'); this.changed(); return; }
    if (h.kind === 'carry') this.dropCarried();
  }

  private dropCarried(): void {
    const h = this.hands.hands;
    if (h.kind !== 'carry') return;
    const p = this.player.position.clone().add(this.player.forward().multiplyScalar(1.3));
    const b = this.world.layout.bounds;
    p.set(THREE.MathUtils.clamp(p.x, b.minX + 1, b.maxX - 1), 0, THREE.MathUtils.clamp(p.z, b.minZ + 1, b.maxZ - 1.2));
    this.hands.clear();
    this.world.addPickup(h.item.kind, p, h.item.faulty, this.player.root.rotation.y);
    this.sfx('place');
    this.changed();
  }

  toggleMeter(): void {
    if (this.paused || this.phase === 'finished') return;
    const hud = this.d.hud;
    if (this.hands.kind === 'meter') {
      this.hands.setMeter(false);
      hud.meter.hide();
      hud.actions.setMeterOn(false);
      return;
    }
    if (!this.hands.isFree) { this.toast('Primero soltá lo que tenés en la mano.'); return; }
    this.hands.setMeter(true);
    hud.actions.setMeterOn(true);
    hud.meter.set('--- V', 'V⎓ CC', 'Acercate a la caja de conexión o a un panel instalado y tocá Medir.', 'idle');
    hud.meter.show();
  }

  toggleInspect(): void {
    const ins = this.d.hud.inspect;
    if (ins.visible) { ins.hide(); this.openInspectId = null; return; }
    const c = this.currentInspect;
    if (!c) return;
    this.openInspectId = c.id;
    ins.show({ title: c.title, body: c.body, live: c.live?.() ?? null });
    this.sfx('beep');
  }

  closeInspect(): void { this.openInspectId = null; }

  /** Booster usado desde la barra durante la partida. */
  useBooster(id: string): void {
    if (id === 'boost_hint' && !this.hintOn && this.d.boosters.use('boost_hint')) {
      this.hintOn = true;
      this.toast('Pista activada: seguí la flecha celeste.', 'good');
    } else if (id === 'boost_drone' && !this.droneOn && this.d.boosters.use('boost_drone')) {
      this.droneOn = true;
      if (this.weather === 'zonda-over' && this.world.rows.some((_, r) => this.world.rowDirty(r))) this.launchDrone();
      else this.toast('El dron va a limpiar los paneles cuando pase el Zonda.', 'good');
    }
    this.refreshBoosterBar();
  }

  private refreshBoosterBar(): void {
    const inv = this.d.inventory, slots = [];
    if (!this.hintOn && inv.count('boost_hint') > 0) slots.push({ id: 'boost_hint', label: 'Pista', icon: 'hint', count: inv.count('boost_hint') });
    if (this.level.events.zondaAtHour !== null && !this.droneOn && inv.count('boost_drone') > 0) slots.push({ id: 'boost_drone', label: 'Dron limpiador', icon: 'drone', count: inv.count('boost_drone') });
    this.d.hud.boosters.setBoosters(slots);
  }

  private changed(): void { this.hudTimer = 0; }

  private syncHud(): void {
    const hud = this.d.hud;
    hud.mission.setObjectives(this.tracker.objectives());
    hud.mission.setTimer(this.elapsed);
    if (this.snap && this.phase !== 'build') hud.stats.update(this.snap);
    if (this.weather === 'zonda-warning') hud.alert.setCountdown(this.warningSeconds());
    const ins = hud.inspect;
    if (ins.visible && this.openInspectId) {
      if (!this.currentInspect || this.currentInspect.id !== this.openInspectId) { ins.hide(); this.openInspectId = null; }
      else ins.updateLive(this.currentInspect.live?.() ?? null);
    }
  }

  private updateVisuals(dt: number): void {
    const w = this.world, s = this.snap, running = this.phase !== 'build';
    // Zonda en el ambiente
    let zTarget = 0;
    const zw = this.weatherSchedule.zondaWindow();
    if (zw && running) {
      if (this.weather === 'zonda-warning') zTarget = 0.35 * (this.hour - zw.warnFrom) / (zw.stormFrom - zw.warnFrom);
      else if (this.weather === 'zonda-storm') zTarget = 1;
      else if (this.weather === 'zonda-over') zTarget = Math.max(0, 1 - (this.hour - zw.stormTo) / 0.35);
    }
    this.zondaFx += (zTarget - this.zondaFx) * Math.min(1, dt * 2.5);
    this.d.env.update(dt, this.hour, { zonda: this.zondaFx, clouds: this.weatherSchedule.cloudinessAt(this.hour), follow: this.player.position });
    const night = this.d.env.nightFactor();
    const lit = running && !!s && !s.blackout;
    w.city.setLit(lit ? night : 0);
    w.setRoomLight(lit ? night : 0);
    if (!running || !s) {
      w.inverter.setScreen('STANDBY', '#8fa7a1');
      return;
    }
    // Paneles, baterías, bomba, inversor
    w.rows.forEach((row, r) => {
      const open = w.rowOpen(r);
      for (const m of row) m.setGlow(open ? 0 : 0.28 * s.irradiance);
    });
    for (const b of w.batteries) b.setCharge(s.socPct);
    const pumpOn = !!w.pump && lit && this.level.loads.some((l) => /bomba/i.test(l.label) && blockActive(l, s.hour));
    w.pump?.setRunning(pumpOn);
    const openRow = w.rows.findIndex((_, r) => w.panelsInRow(r) > 0 && w.rowOpen(r));
    if (s.blackout) w.inverter.setScreen('SIN CARGA', '#ff5a4d');
    else if (openRow >= 0 && s.irradiance > 0.05) w.inverter.setScreen(`F${openRow + 1}: 0 V`, '#ffb547');
    else if (s.genKw > s.loadKw) w.inverter.setScreen(`ON ${fmt1(s.genKw)} kW`, '#5fe3f5');
    else w.inverter.setScreen(`BAT ${fmt1(s.loadKw)} kW`, '#ffd27a');
    // Flujos de energía
    const fl = this.flows, gen = s.genKw > 0.05 && this.phase === 'running';
    fl.rows.forEach((f, r) => { if (f) f.on = gen && w.panelsInRow(r) > 0 && !w.rowOpen(r); });
    if (fl.orange) fl.orange.on = gen;
    if (fl.link) fl.link.on = gen;
    if (fl.blue) {
      const full = s.netKw > 0 && s.socPct >= 0.999;
      fl.blue.on = this.phase === 'running' && Math.abs(s.netKw) > 0.05 && !full;
      fl.blue.dir = s.netKw > 0 ? -1 : 1;
    }
    const delivering = lit && this.phase === 'running';
    if (fl.violet) fl.violet.on = delivering;
    if (fl.grid) fl.grid.on = delivering;
    if (fl.pump) fl.pump.on = pumpOn;
  }

  /* ================================================================ depuración */

  availableActions(): WorldAction[] { return this.interaction.available(this.hands.hands); }
  get currentActionLabel(): string | null { return this.currentAction?.label ?? null; }
  get gameHour(): number { return this.hour; }
  get lostPanels(): number { return this.panelsLost; }
  get cosmetics(): { helmet?: number; vest?: number } { return { ...this.d.cosmetics }; }
  get shedLoads(): string[] { return [...this.shed]; }
  forceInteractionUpdate(): void { this.updateInteraction(); }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.d.audio.setWind(false);
    this.camRig.dispose();
    this.hands.clear();
    this.world.dispose();
    this.d.ui.toast.hide();
    this.d.hud.reset();
  }
}
