/**
 * InteractionSystem: junta las acciones de todas las estrategias para el estado de manos actual
 * y elige la más cercana al jugador (y la ficha de "Revisar" más cercana).
 */
import type * as THREE from 'three';
import type { ActionProvider, Hands, InspectEntry, InspectProvider, WorldAction } from './types';

export interface InteractionPick { action: WorldAction | null; inspect: InspectEntry | null; }

export class InteractionSystem {
  private actions: WorldAction[] = [];

  constructor(
    private readonly providers: ActionProvider[],
    private readonly inspectors: InspectProvider[],
    private readonly actionRadius = 2.1,
    private readonly inspectRadius = 3.0,
  ) {}

  /** Todas las acciones disponibles ahora (para depuración y pruebas). */
  available(hands: Hands): WorldAction[] {
    const out: WorldAction[] = [];
    for (const p of this.providers) p.collect(hands, out);
    return out;
  }

  update(hands: Hands, at: THREE.Vector3): InteractionPick {
    this.actions = this.available(hands);
    const action = nearest(this.actions, at, this.actionRadius);
    const ins: InspectEntry[] = [];
    for (const p of this.inspectors) p.inspectables(ins);
    return { action, inspect: nearest(ins, at, this.inspectRadius) };
  }
}

function nearest<T extends { pos: THREE.Vector3 }>(list: T[], at: THREE.Vector3, r: number): T | null {
  let best: T | null = null, bd = r;
  for (const a of list) {
    const d = Math.hypot(a.pos.x - at.x, a.pos.z - at.z);
    if (d < bd) { bd = d; best = a; }
  }
  return best;
}
