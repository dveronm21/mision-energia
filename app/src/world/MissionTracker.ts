/**
 * MissionTracker: arma la lista de objetivos del MissionPanel según el estado de la partida
 * y calcula el "próximo paso" para la Pista (booster boost_hint).
 */
import type * as THREE from 'three';
import type { LevelDefinition, Purchase, WeatherPhase } from '../contracts';
import type { MissionObjective } from '../ui';
import type { HandsController } from './HandsController';
import type { PlantWorld } from './PlantWorld';
import type { SessionPhase } from './interaction/SessionPort';

export interface MissionFacts {
  readonly level: LevelDefinition;
  readonly purchase: Purchase;
  readonly world: PlantWorld;
  readonly hands: HandsController;
  readonly phase: SessionPhase;
  readonly weather: WeatherPhase;
  readonly connector: { measured: boolean; rowFound: boolean; fixed: boolean };
  readonly won: boolean;
}

type Step = 'panels' | 'protection' | 'batteries' | 'kit' | 'orange' | 'blue' | 'violet' | 'connector' | 'activate' | 'lost' | 'zonda' | 'night';
interface Item { step: Step; text: string; ok: boolean; alert?: boolean; }

export class MissionTracker {
  constructor(private readonly f: MissionFacts) {}

  private items(): Item[] {
    const { level: lv, purchase: buy, world: w, phase, weather } = this.f;
    const running = phase !== 'build';
    const n = w.panelsInstalled(), nb = w.batteriesInstalled();
    const c = this.f.connector;
    const L: Item[] = [
      { step: 'panels', text: `Instalá los paneles (${n}/${buy.panels})`, ok: n >= buy.panels || (running && n >= lv.minPanels) },
      { step: 'protection', text: 'Instalá la protección junto al inversor', ok: w.protection.installed },
      { step: 'batteries', text: `Instalá ${buy.batteries === 1 ? 'la batería' : 'las baterías'} (${nb}/${buy.batteries})`, ok: nb >= buy.batteries },
    ];
    if (buy.kitZonda) L.push({ step: 'kit', text: 'Poné las trabas anti-Zonda en un poste de fila', ok: w.kitInstalled });
    L.push(
      { step: 'orange', text: 'Conectá paneles → protección (naranja)', ok: w.cables.isConnected('orange') },
      { step: 'blue', text: 'Conectá baterías → inversor (azul)', ok: w.cables.isConnected('blue') },
      { step: 'violet', text: 'Conectá tablero → inversor (violeta)', ok: w.cables.isConnected('violet') },
    );
    if (lv.events.looseConnector) {
      const text = c.fixed ? 'Reparaste el conector flojo' : c.rowFound ? 'Medí panel por panel la fila que marca 0 V y reconectá' : 'Medí las filas con el multímetro en la caja de conexión';
      L.push({ step: 'connector', text, ok: c.fixed, alert: c.rowFound && !c.fixed });
    }
    L.push({ step: 'activate', text: 'Activá la planta en la consola', ok: running });
    if (running && w.pickups.some((p) => p.kind === 'panel')) L.push({ step: 'lost', text: 'Volvé a colocar el panel que voló', ok: false, alert: true });
    if (running && weather !== 'calm') {
      const dirty = w.rows.some((_, r) => w.rowDirty(r));
      if (weather === 'zonda-over') L.push({ step: 'zonda', text: dirty ? 'Limpiá el polvo en el poste de cada fila' : 'Pasó el Zonda: paneles limpios', ok: !dirty, alert: dirty });
      else L.push({ step: 'zonda', text: w.kitInstalled ? 'Zonda: las trabas sostienen los paneles' : 'Zonda: poné cada fila en defensa (poste de la fila)', ok: w.kitInstalled || w.posts.every((p) => p.inDefense || w.panelsInRow(p.row) === 0), alert: !w.kitInstalled });
    }
    L.push({ step: 'night', text: 'Mantené la ciudad con luz toda la noche', ok: phase === 'finished' && this.f.won });
    return L;
  }

  objectives(): MissionObjective[] {
    let nowSet = false;
    return this.items().map((it) => {
      let state: MissionObjective['state'];
      if (it.ok) state = 'ok';
      else if (it.alert) state = 'alert';
      else if (!nowSet) { state = 'now'; nowSet = true; }
      else state = 'todo';
      return { id: it.step, text: it.text, state };
    });
  }

  /** Dónde está el próximo paso (o null). */
  hintTarget(): THREE.Vector3 | null {
    const { world: w, hands } = this.f;
    const h = hands.hands;
    if (h.kind === 'carry') {
      switch (h.item.kind) {
        case 'panel': return w.mounts.find((m) => !m.filled)?.approach ?? null;
        case 'protection': return w.protection.approach;
        case 'battery': return w.batteries.find((b) => !b.installed)?.approach ?? null;
        case 'kit': return w.posts[0]?.approach ?? null;
      }
    }
    if (h.kind === 'cable') return h.color === 'orange' ? w.protection.approach : w.inverter.approach;
    const next = this.items().find((it) => !it.ok && (it.alert || it.step !== 'night'));
    if (!next) return null;
    const crate = (k: string) => w.pickups.find((p) => p.kind === k)?.approach ?? null;
    switch (next.step) {
      case 'panels': return crate('panel') ?? (w.pallet.remaining > 0 ? w.pallet.approach : null);
      case 'lost': return crate('panel');
      case 'protection': return crate('protection');
      case 'batteries': return crate('battery');
      case 'kit': return crate('kit');
      case 'orange': return w.junction.approach;
      case 'blue': return w.batteries.find((b) => b.installed)?.approach ?? null;
      case 'violet': return w.switchboard.approach;
      case 'connector': {
        if (!this.f.connector.rowFound) return w.junction.approach;
        return w.mounts.find((m) => m.filled && m.faulty)?.approach ?? null;
      }
      case 'activate': return w.console.approach;
      case 'zonda': {
        const post = w.posts.find((p) => (this.f.weather === 'zonda-over' ? w.rowDirty(p.row) : !p.inDefense && w.panelsInRow(p.row) > 0));
        return post?.approach ?? null;
      }
      default: return null;
    }
  }
}
