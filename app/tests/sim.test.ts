import test from 'node:test';
import assert from 'node:assert/strict';
import { EnergySimulator } from '../src/sim/EnergySimulator';
import { WeatherSchedule } from '../src/sim/WeatherSchedule';
import { StormImpact } from '../src/sim/StormImpact';
import { sunFactor, loadKw } from '../src/sim/solar';
import { LEVELS } from '../src/levels/levels';
import type { LevelDefinition, SimSnapshot } from '../src/contracts';
import { plantFor } from './support/fixtures';
import { play, PERFECT } from './support/autoplay';

const casa = LEVELS[0];
const escuela = LEVELS[1];
const calmLevel: LevelDefinition = { ...escuela, events: { looseConnector: false, zondaAtHour: null, clouds: [] } };

function run(level: LevelDefinition, dt: number, plant = plantFor(level)): SimSnapshot[] {
  const sim = new EnergySimulator();
  sim.start(level, plant);
  const out: SimSnapshot[] = [];
  let s = sim.snapshot();
  while (!s.finished) { s = sim.step(dt, plant, 'calm'); out.push(s); }
  return out;
}

test('simulador: determinista (misma entrada → misma salida)', () => {
  assert.deepEqual(run(casa, 0.1), run(casa, 0.1));
});

test('simulador: casi independiente del frame rate (subpasos internos)', () => {
  const a = run(casa, 0.05).pop()!, b = run(casa, 0.5).pop()!;
  assert.equal(a.won, b.won);
  assert.ok(Math.abs(a.socKwh - b.socKwh) < 0.05, `${a.socKwh} vs ${b.socKwh}`);
});

test('simulador: sin generación de noche', () => {
  const night = run(casa, 0.1).filter((s) => s.isNight);
  assert.ok(night.length > 50);
  night.forEach((s) => { assert.equal(s.genKw, 0); assert.equal(s.irradiance, 0); });
  assert.equal(sunFactor(2), 0); assert.equal(sunFactor(26), 0);
  assert.ok(sunFactor(13) > 0.99);
});

test('simulador: fila abierta no genera; polvo −35%; defensa ×0.55', () => {
  const sim = new EnergySimulator();
  const base = plantFor(calmLevel);
  sim.start(calmLevel, base);
  const full = sim.effectivePanels(base);
  assert.equal(full, 6);
  assert.equal(sim.effectivePanels({ ...base, rowOpen: [true, false] }), 3);
  assert.ok(Math.abs(sim.effectivePanels({ ...base, rowDirty: [true, true] }) - 6 * 0.65) < 1e-9);
  assert.ok(Math.abs(sim.effectivePanels({ ...base, rowDefense: [true, false] }) - (3 * 0.55 + 3)) < 1e-9);
  assert.equal(sim.effectivePanels({ ...base, cablesOk: false }), 0);
  const g1 = sim.step(0.05, base, 'calm').genKw;
  const sim2 = new EnergySimulator(); sim2.start(calmLevel, base);
  const g2 = sim2.step(0.05, { ...base, rowOpen: [true, false] }, 'calm').genKw;
  assert.ok(Math.abs(g2 - g1 / 2) < 1e-9);
});

test('simulador: tormenta de Zonda deja 25% de irradiancia', () => {
  const p = plantFor(calmLevel);
  const a = new EnergySimulator(); a.start(calmLevel, p);
  const b = new EnergySimulator(); b.start(calmLevel, p);
  const ca = a.step(0.05, p, 'calm'), sb = b.step(0.05, p, 'zonda-storm');
  assert.ok(Math.abs(sb.irradiance - ca.irradiance * 0.25) < 1e-9);
});

test('simulador: apagón cuando la batería se vacía con déficit', () => {
  const s = run(casa, 0.1, plantFor(casa, { panelsPerRow: [1] })).pop()!;
  assert.equal(s.blackout, true); assert.equal(s.won, false); assert.equal(s.finished, true);
  assert.equal(s.socKwh, 0);
  assert.ok(s.hour > 19 && s.hour < 31);
});

test('simulador: gana al llegar a endHour y no pasa de la capacidad', () => {
  const all = run(casa, 0.1);
  const last = all[all.length - 1];
  assert.equal(last.won, true); assert.equal(last.hour, casa.endHour);
  all.forEach((s) => assert.ok(s.socKwh <= s.capKwh + 1e-9));
});

test('simulador: bonusKwh (batería de emergencia) suma capacidad cargada', () => {
  const sim = new EnergySimulator();
  sim.start(casa, plantFor(casa, { bonusKwh: 4 }));
  const s = sim.snapshot();
  assert.equal(s.capKwh, casa.batteryKwh + 4);
  assert.ok(Math.abs(s.socKwh - (casa.batteryKwh * casa.startSoc + 4)) < 1e-9);
});

test('simulador: cargas apagadas no consumen', () => {
  assert.equal(loadKw(casa.loads, 20, []), 0.2 + 0.9);
  assert.equal(loadKw(casa.loads, 20, ['Luces y TV']), 0.2);
  assert.equal(loadKw(escuela.loads, 26, []), 0.2 + 0.3); // franja que cruza medianoche
});

test('WeatherSchedule: aviso ~0.7 h, tormenta ~0.3 h', () => {
  const w = new WeatherSchedule({ looseConnector: false, zondaAtHour: 13, clouds: [{ from: 10, to: 12, factor: 0.4 }] });
  assert.equal(w.phaseAt(12.9), 'calm');
  assert.equal(w.phaseAt(13.0), 'zonda-warning');
  assert.equal(w.phaseAt(13.69), 'zonda-warning');
  assert.equal(w.phaseAt(13.75), 'zonda-storm');
  assert.equal(w.phaseAt(14.01), 'zonda-over');
  assert.ok(Math.abs(w.warningRemaining(13.2) - 0.5) < 1e-9);
  assert.ok(Math.abs(w.cloudinessAt(11) - 0.6) < 1e-9);
  assert.equal(new WeatherSchedule(casa.events).phaseAt(15), 'calm');
});

test('StormImpact: ensucia todo; sin defensa ni kit vuela un panel por fila', () => {
  const p = plantFor(calmLevel, { rowDefense: [true, false] });
  const r = new StormImpact().apply(p, false);
  assert.equal(r.panelsLost, 1);
  assert.deepEqual(r.plant.panelsPerRow, [3, 2]);
  assert.deepEqual(r.plant.rowDirty, [true, true]);
  assert.equal(new StormImpact().apply(plantFor(calmLevel), true).panelsLost, 0);
});

test('autoplay: conector sin reparar + batería de emergencia sigue perdiendo (el booster no reemplaza aprender)', () => {
  const o = play(escuela, { panels: 4, batteries: 2, kitZonda: false }, { ...PERFECT, repairConnector: false, bonusKwh: 4 });
  assert.equal(o.result.won, false);
});
