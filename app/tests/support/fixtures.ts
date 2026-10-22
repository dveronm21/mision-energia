import type { LevelDefinition, PlantState } from '../../src/contracts';
import { SaveStore } from '../../src/core/SaveStore';

/** SaveStore solo en memoria (sin localStorage). */
export const memStore = () => new SaveStore(null);

export function plantFor(level: LevelDefinition, over: Partial<PlantState> = {}): PlantState {
  const n = level.rows;
  return {
    panelsPerRow: new Array(n).fill(level.panelsPerRow),
    rowOpen: new Array(n).fill(false), rowDirty: new Array(n).fill(false), rowDefense: new Array(n).fill(false),
    batteries: level.batterySlots, protectionInstalled: true, cablesOk: true, shedLoads: [],
    ...over,
  };
}
