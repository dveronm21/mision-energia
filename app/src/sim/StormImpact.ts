import type { PlantState } from '../contracts';

/**
 * Regla del golpe de Zonda (pura): al entrar en 'zonda-storm', toda fila con paneles queda con polvo;
 * cada fila que NO está en defensa pierde su último panel, salvo que se haya instalado el kit anti-Zonda.
 * El mundo 3D la aplica una vez al comenzar la tormenta y anima los paneles volados.
 */
export class StormImpact {
  apply(plant: PlantState, kitInstalled: boolean): { plant: PlantState; panelsLost: number; lostPerRow: number[] } {
    const lostPerRow = plant.panelsPerRow.map((n, r): number => (n > 0 && !kitInstalled && !plant.rowDefense[r] ? 1 : 0));
    const panelsLost = lostPerRow.reduce((a, b) => a + b, 0);
    return {
      panelsLost,
      lostPerRow,
      plant: {
        ...plant,
        panelsPerRow: plant.panelsPerRow.map((n, r) => n - lostPerRow[r]),
        rowDirty: plant.panelsPerRow.map((n, r) => plant.rowDirty[r] || n > 0),
      },
    };
  }
}
