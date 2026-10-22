import test from 'node:test';
import assert from 'node:assert/strict';
import { Scoring } from '../src/sim/Scoring';
import { LEVELS } from '../src/levels/levels';

const finca = LEVELS[2];
const base = { won: true, finalSocPct: 0.5, spent: 11000, panelsLost: 0, blackoutHour: null, durationSec: 80, hadOpenRowAtEnd: false, hadDirtyRowAtEnd: false, batteries: 2, panels: 5 };
const sc = new Scoring();

test('Scoring: estrellas según reglas del nivel', () => {
  assert.equal(sc.evaluate(finca, base).stars, 3);
  assert.equal(sc.evaluate(finca, { ...base, panelsLost: 1 }).stars, 2);
  assert.equal(sc.evaluate(finca, { ...base, spent: finca.budget }).stars, 2);
  assert.equal(sc.evaluate(finca, { ...base, finalSocPct: finca.twoStarSoc - 0.01 }).stars, 1);
  const lost = sc.evaluate(finca, { ...base, won: false, finalSocPct: 0, blackoutHour: 26 });
  assert.equal(lost.stars, 0);
  assert.equal(lost.score, (26 - finca.startHour) * 25);
  assert.ok(sc.evaluate(finca, base).score > 1000);
});

test('Scoring: tips didácticos según qué falló', () => {
  const r = sc.evaluate(finca, { ...base, won: false, finalSocPct: 0, blackoutHour: 27, hadOpenRowAtEnd: true, hadDirtyRowAtEnd: true });
  assert.match(r.tips[0], /conector flojo/);
  assert.match(r.tips[1], /polvo/);
  const bats = sc.evaluate(finca, { ...base, won: false, finalSocPct: 0, blackoutHour: 27, batteries: 1 });
  assert.ok(bats.tips.some((t) => /batería/.test(t)));
  const panels = sc.evaluate(finca, { ...base, won: false, finalSocPct: 0, blackoutHour: 27, panels: 4 });
  assert.ok(panels.tips.some((t) => /pocos paneles/.test(t)));
  const loads = sc.evaluate(finca, { ...base, won: false, finalSocPct: 0, blackoutHour: 27, nonEssentialOn: true });
  assert.ok(loads.tips.some((t) => /no son esenciales/.test(t)));
  const wind = sc.evaluate(finca, { ...base, panelsLost: 2 });
  assert.ok(wind.tips.some((t) => /defensa/.test(t)));
  assert.ok(sc.evaluate(finca, base).tips.length >= 1);
  assert.ok(r.tips.length <= 3);
});
