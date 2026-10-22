/**
 * Exporta resultados "golden" de la versión web para verificar que el port a Godot sea equivalente.
 * Uso (desde app/):  npx tsx tests/export-golden.ts
 * Escribe ../godot/tests/fixtures/golden.json con:
 *  - scenarios: autoplay por nivel y escenario (snapshots cada N pasos, final, resultado, tips).
 *  - simRuns: corridas directas del simulador (dt distintos, planta débil, bonus).
 *  - scoring: casos sueltos de Scoring.evaluate.
 *  - affordable: todas las compras posibles por nivel con costo, estrellas y puntaje.
 *  - balanceTable: salida exacta de `npm run balance`.
 */
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { LevelDefinition, PlantState, Purchase, SimSnapshot, WeatherPhase } from '../src/contracts';
import { EnergySimulator } from '../src/sim/EnergySimulator';
import { Scoring } from '../src/sim/Scoring';
import { LEVELS } from '../src/levels/levels';
import { LevelCatalog } from '../src/levels/LevelCatalog';
import { PERFECT, affordablePurchases, bestPurchase, play, type Strategy } from './support/autoplay';
import { plantFor } from './support/fixtures';

const SNAPSHOT_EVERY = 10;
const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../godot/tests/fixtures/golden.json');

/* Grabación de pasos: se envuelve EnergySimulator.step sin tocar el autoplay. */
let recording: SimSnapshot[] | null = null;
const origStep = EnergySimulator.prototype.step;
EnergySimulator.prototype.step = function (this: EnergySimulator, dt: number, plant: PlantState, w: WeatherPhase): SimSnapshot {
  const s = origStep.call(this, dt, plant, w);
  if (recording) recording.push(s);
  return s;
};

function sample(steps: SimSnapshot[]): { step: number; snap: SimSnapshot }[] {
  const res: { step: number; snap: SimSnapshot }[] = [];
  steps.forEach((s, i) => { if ((i + 1) % SNAPSHOT_EVERY === 0) res.push({ step: i + 1, snap: s }); });
  return res;
}

const catalog = new LevelCatalog(LEVELS);
const scenarios: unknown[] = [];
const affordable: Record<string, unknown[]> = {};

function scenario(level: LevelDefinition, name: string, buy: Purchase, s: Strategy): void {
  recording = [];
  const o = play(level, buy, s);
  const steps = recording;
  recording = null;
  scenarios.push({
    level: level.id, name, buy, strategy: s, dt: 0.05, cost: catalog.cost(level, buy),
    stepCount: steps.length, snapshots: sample(steps), final: steps[steps.length - 1],
    blackoutHour: o.blackoutHour, minSocPct: o.minSocPct, result: o.result,
  });
}

for (const level of catalog.all()) {
  const best = bestPurchase(level)!;
  const buy = best.buy;
  scenario(level, 'optima', buy, PERFECT);
  scenario(level, 'menos_bateria', { ...buy, batteries: buy.batteries - 1 }, PERFECT);
  scenario(level, 'conector_sin_reparar', buy, { ...PERFECT, repairConnector: false });
  scenario(level, 'polvo_sin_limpiar', buy, { ...PERFECT, cleanAfterZonda: false });
  scenario(level, 'sin_defensa', { ...buy, kitZonda: false }, { ...PERFECT, zonda: 'none' });
  scenario(level, 'min_paneles', { ...buy, panels: level.minPanels }, PERFECT);
  scenario(level, 'mas_barata', { panels: level.minPanels, batteries: 1, kitZonda: false }, PERFECT);
  scenario(level, 'bateria_emergencia', buy, { ...PERFECT, bonusKwh: 4 });
  scenario(level, 'apaga_no_esenciales', buy, { ...PERFECT, shedNonEssentialAtNight: true });
  affordable[level.id] = affordablePurchases(level).map((b) => {
    const o = play(level, b);
    return { buy: b, cost: catalog.cost(level, b), won: o.result.won, stars: o.result.stars, score: o.result.score, finalSocPct: o.result.finalSocPct };
  });
}

/* Corridas directas del simulador (como sim.test.ts). */
const simRuns: unknown[] = [];
function simRun(name: string, level: LevelDefinition, dt: number, over: Partial<PlantState>, weather: WeatherPhase = 'calm'): void {
  const sim = new EnergySimulator();
  const plant = plantFor(level, over);
  sim.start(level, plant);
  const start = sim.snapshot();
  const steps: SimSnapshot[] = [];
  let s = start;
  while (!s.finished) { s = origStep.call(sim, dt, plant, weather); steps.push(s); }
  simRuns.push({ name, level: level.id, dt, plant, weather, start, stepCount: steps.length, snapshots: sample(steps), final: s, effectivePanels: sim.effectivePanels(plant) });
}
simRun('casa_dt01', LEVELS[0], 0.1, {});
simRun('casa_dt05', LEVELS[0], 0.5, {});
simRun('casa_1panel', LEVELS[0], 0.1, { panelsPerRow: [1] });
simRun('casa_bonus', LEVELS[0], 0.05, { bonusKwh: 4 });
simRun('escuela_sucia_defensa', LEVELS[1], 0.07, { rowDirty: [true, false], rowDefense: [false, true] });
simRun('pueblo_tormenta', LEVELS[3], 0.2, { shedLoads: ['Comercios'] }, 'zonda-storm');
simRun('parque_abierta', LEVELS[4], 0.13, { rowOpen: [true, false, false, false], batteries: 3 });

/* Casos de Scoring (como scoring.test.ts). */
const scoringCases: unknown[] = [];
const sc = new Scoring();
const base = { won: true, finalSocPct: 0.5, spent: 11000, panelsLost: 0, blackoutHour: null as number | null, durationSec: 80, hadOpenRowAtEnd: false, hadDirtyRowAtEnd: false, batteries: 2, panels: 5 as number | undefined, nonEssentialOn: false };
const variants: Record<string, Partial<typeof base>> = {
  base: {}, perdio_panel: { panelsLost: 1 }, gasto_todo: { spent: 13500 }, soc_bajo: { finalSocPct: 0.29 },
  perdio: { won: false, finalSocPct: 0, blackoutHour: 26 },
  perdio_todo_mal: { won: false, finalSocPct: 0, blackoutHour: 27.35, hadOpenRowAtEnd: true, hadDirtyRowAtEnd: true, batteries: 1, panels: 2, nonEssentialOn: true },
  una_bateria: { won: false, finalSocPct: 0, blackoutHour: 27, batteries: 1 },
  cero_baterias: { won: false, finalSocPct: 0, blackoutHour: 19, batteries: 0 },
  pocos_paneles: { won: false, finalSocPct: 0, blackoutHour: 27, panels: 4 },
  sin_panels: { won: false, finalSocPct: 0, blackoutHour: 27, panels: undefined },
  dos_paneles_volados: { panelsLost: 2 }, muchos_volados: { panelsLost: 40 },
  soc_fuera: { finalSocPct: 1.7 }, gasto_justo: { spent: 12150 },
};
for (const level of LEVELS) {
  for (const [name, v] of Object.entries(variants)) {
    const input = { ...base, ...v };
    scoringCases.push({ level: level.id, name, input: { ...input, panels: input.panels ?? null }, result: sc.evaluate(level, input) });
  }
}

/* Tabla de balance exacta. */
const balance = execFileSync(process.execPath, ['--import', 'tsx', resolve(here, 'balance.ts')], { cwd: resolve(here, '..'), encoding: 'utf8' });

const golden = {
  generatedBy: 'app/tests/export-golden.ts', snapshotEvery: SNAPSHOT_EVERY,
  best: Object.fromEntries(catalog.all().map((l) => [l.id, bestPurchase(l)!.buy])),
  scenarios, simRuns, scoring: scoringCases, affordable,
  balanceTable: balance.replace(/\n+$/, '').split('\n'),
};
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(golden, null, 1));
console.log(`golden.json: ${scenarios.length} escenarios, ${simRuns.length} corridas, ${scoringCases.length} casos de puntaje, ` +
  `${Object.values(affordable).reduce((a, b) => a + b.length, 0)} compras → ${out}`);
