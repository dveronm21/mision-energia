/**
 * Tipos del sistema de interacción (patrón estrategia):
 * cada ActionProvider aporta acciones según lo que el jugador tiene en las manos,
 * y el InteractionSystem elige la más cercana.
 */
import type * as THREE from 'three';

export type CarryKind = 'panel' | 'battery' | 'protection' | 'kit';
export type CableColor = 'orange' | 'blue' | 'violet';
export type TerminalId = 'junction' | 'protection' | 'inverter' | 'battery' | 'switchboard';

export interface CarriedItem { kind: CarryKind; faulty: boolean; }

/** Estado de las manos del técnico. */
export type Hands =
  | { kind: 'free' }
  | { kind: 'carry'; item: CarriedItem }
  | { kind: 'cable'; color: CableColor; from: TerminalId; fromPoint: THREE.Vector3 }
  | { kind: 'meter' };

/** Acción contextual en el mundo. `pos` es el punto de acceso en el piso (fuera de los colisionadores). */
export interface WorldAction {
  id: string;
  label: string;
  pos: THREE.Vector3;
  run(): void;
}

/** Ficha de "Revisar". */
export interface InspectEntry {
  id: string;
  pos: THREE.Vector3;
  title: string;
  body: string;
  live?: () => string | null;
}

/** Estrategia: aporta acciones para el estado de manos actual. */
export interface ActionProvider {
  collect(hands: Hands, out: WorldAction[]): void;
}

/** Aporta fichas para "Revisar". */
export interface InspectProvider {
  inspectables(out: InspectEntry[]): void;
}
