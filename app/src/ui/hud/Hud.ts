import { el } from '../dom';
import { ActionButtons, type ActionButtonsCallbacks } from './ActionButtons';
import { AlertBanner } from './AlertBanner';
import { BoosterBar } from './BoosterBar';
import { InspectCard } from './InspectCard';
import { Joystick, type JoystickVector } from './Joystick';
import { LoadSheddingPanel } from './LoadSheddingPanel';
import { MeterView } from './MeterView';
import { MissionPanel } from './MissionPanel';
import { StatsPanel } from './StatsPanel';
import { WorldPrompt } from './WorldPrompt';

export interface HudCallbacks extends ActionButtonsCallbacks {
  onJoystick?(v: JoystickVector): void;
  onUseBooster(boosterId: string): void;
  onToggleLoad(label: string, on: boolean): void;
  onInspectClose?(): void;
}

/**
 * HUD completo de partida. Compone los componentes y define las zonas para que no se pisen:
 * arriba-izq misión, arriba-der estadísticas + pausa, carril superior central (alertas),
 * abajo-izq joystick + boosters, abajo-der botonera, carril inferior central (multímetro, ficha, cargas).
 */
export class Hud {
  readonly root: HTMLDivElement;
  readonly joystick: Joystick;
  readonly actions: ActionButtons;
  readonly mission: MissionPanel;
  readonly stats: StatsPanel;
  readonly alert: AlertBanner;
  readonly prompt: WorldPrompt;
  readonly meter: MeterView;
  readonly inspect: InspectCard;
  readonly shedding: LoadSheddingPanel;
  readonly boosters: BoosterBar;

  constructor(host: HTMLElement, cb: HudCallbacks) {
    this.root = el('div', 'hud');
    const topLane = el('div', 'hud-lane-top');
    const bottomLane = el('div', 'hud-lane-bottom');
    host.appendChild(this.root);
    this.prompt = new WorldPrompt(this.root);
    this.mission = new MissionPanel(this.root);
    this.stats = new StatsPanel(this.root);
    this.root.append(topLane, bottomLane);
    const uiRoot = host.closest<HTMLElement>('.ui-root') ?? document.documentElement;
    this.alert = new AlertBanner(topLane, (h) => uiRoot.style.setProperty('--alert-h', `${h ? h + 8 : 0}px`));
    this.shedding = new LoadSheddingPanel(bottomLane, (label, on) => cb.onToggleLoad(label, on));
    this.inspect = new InspectCard(bottomLane, cb.onInspectClose);
    this.meter = new MeterView(bottomLane);
    this.joystick = new Joystick(this.root, cb.onJoystick);
    this.boosters = new BoosterBar(this.root, (id) => cb.onUseBooster(id));
    this.actions = new ActionButtons(this.root, cb);
  }

  /** Reinicia el HUD al empezar un nivel. */
  reset(): void {
    this.joystick.reset();
    this.alert.hide();
    this.prompt.hide();
    this.meter.hide();
    this.inspect.hide();
    this.shedding.hide();
    this.stats.setVisible(false);
    this.actions.setMeterOn(false);
    this.actions.setAction('Acercate a algo', 'idle');
    this.mission.setCollapsed(false);
  }
}
