import type { LevelDefinition, SfxName, WeatherPhase } from '../../contracts';
import type { ToastKind } from '../../ui';
import type { HandsController } from '../HandsController';
import type { PlantWorld } from '../PlantWorld';
import type { Mount } from '../entities/Mount';
import type { Pickup } from '../entities/Pickups';
import type { CableColor, TerminalId } from './types';

export type SessionPhase = 'build' | 'running' | 'finished';

/**
 * Lo que las estrategias de interacción pueden ver y pedir de la partida.
 * GameSession lo implementa; las reglas del juego viven ahí, no en las estrategias.
 */
export interface SessionPort {
  readonly level: LevelDefinition;
  readonly world: PlantWorld;
  readonly hands: HandsController;
  readonly phase: SessionPhase;
  readonly weather: WeatherPhase;
  readonly isNight: boolean;

  toast(text: string, kind?: ToastKind): void;
  sfx(name: SfxName): void;

  takeFromPallet(): void;
  takePickup(p: Pickup): void;
  installPanel(m: Mount): void;
  installProtection(): void;
  installBattery(slot: number): void;
  installKit(row: number): void;
  takeCable(color: CableColor, from: TerminalId, point: import('three').Vector3): void;
  connectCable(to: TerminalId): void;
  measureRows(): void;
  measurePanel(m: Mount): void;
  repairPanel(m: Mount): void;
  setDefense(row: number): void;
  cleanRow(row: number): void;
  tryActivate(): void;
}
