/**
 * npm run balance — verifica que cada nivel sea ganable, no trivial, que los errores típicos castiguen
 * y que la dificultad suba del nivel 1 al 5. Sale con código ≠ 0 si algo falla.
 */
import type { LevelDefinition, Purchase } from '../src/contracts';
import { LEVELS } from '../src/levels/levels';
import { LevelCatalog } from '../src/levels/LevelCatalog';
import { PERFECT, affordablePurchases, bestPurchase, play, type Strategy } from './support/autoplay';

const catalog = new LevelCatalog(LEVELS);
const problems: string[] = [];
const fmtOut = (o: ReturnType<typeof play>) =>
  o.result.won ? `${'★'.repeat(o.result.stars)}${'☆'.repeat(3 - o.result.stars)} ${Math.round(o.result.finalSocPct * 100)}%` : `APAGÓN ${hhmm(o.blackoutHour ?? 0)}`;
function hhmm(h: number): string { const x = ((h % 24) + 24) % 24; return `${Math.floor(x)}:${String(Math.floor((x % 1) * 60)).padStart(2, '0')}`; }
const pad = (s: string, n: number) => (s.length >= n ? s : s + ' '.repeat(n - s.length));

console.log(pad('nivel', 9) + pad('mejor compra', 25) + pad('perfecto', 13) + pad('-1 batería', 13) + pad('conector', 13) + pad('polvo', 13) + pad('sin defensa', 13) + pad('mín. paneles', 14) + pad('más barata', 13) + 'compras ≥2★');
let prevRate = Infinity;
for (const level of catalog.all()) {
  const best = bestPurchase(level);
  if (!best || !best.outcome.result.won) { problems.push(`${level.id}: IMPOSIBLE (ninguna compra gana con juego perfecto)`); console.log(pad(level.id, 9) + 'IMPOSIBLE'); continue; }
  const { buy } = best;
  const perfect = best.outcome;
  if (perfect.result.stars < 3) problems.push(`${level.id}: el juego perfecto no llega a 3 estrellas (${perfect.result.stars})`);

  const errors: Record<string, { buy: Purchase; s: Strategy } | null> = {
    '-1 batería': { buy: { ...buy, batteries: buy.batteries - 1 }, s: PERFECT },
    conector: level.events.looseConnector ? { buy, s: { ...PERFECT, repairConnector: false } } : null,
    polvo: level.events.zondaAtHour !== null ? { buy, s: { ...PERFECT, cleanAfterZonda: false } } : null,
    'sin defensa': level.events.zondaAtHour !== null ? { buy: { ...buy, kitZonda: false }, s: { ...PERFECT, zonda: 'none' } } : null,
    'mín. paneles': { buy: { ...buy, panels: level.minPanels }, s: PERFECT },
  };
  const cells: string[] = [];
  for (const [name, e] of Object.entries(errors)) {
    if (!e) { cells.push(pad('—', name === 'mín. paneles' ? 14 : 13)); continue; }
    const o = play(level, e.buy, e.s);
    if (o.result.won && o.result.stars >= perfect.result.stars) problems.push(`${level.id}: el error "${name}" no castiga (${fmtOut(o)})`);
    cells.push(pad(fmtOut(o), name === 'mín. paneles' ? 14 : 13));
  }
  const cheapest = play(level, { panels: level.minPanels, batteries: 1, kitZonda: false });
  if (cheapest.result.won) problems.push(`${level.id}: TRIVIAL (la compra más barata gana)`);
  const all = affordablePurchases(level);
  const rate = all.filter((b) => play(level, b).result.stars >= 2).length / all.length;
  if (rate > prevRate + 0.05) problems.push(`${level.id}: más fácil que el nivel anterior (compras de ≥2★ ${Math.round(rate * 100)}% > ${Math.round(prevRate * 100)}%)`);
  prevRate = rate;
  const buyTxt = `${buy.panels}p ${buy.batteries}b${buy.kitZonda ? ' kit' : ''} $${catalog.cost(level, buy)}/${level.budget}`;
  console.log(pad(level.id, 9) + pad(buyTxt, 25) + pad(fmtOut(perfect), 13) + cells.join('') + pad(fmtOut(cheapest), 13) + `${Math.round(rate * 100)}% (${all.length})`);
}

if (problems.length) {
  console.log('\nPROBLEMAS DE BALANCE:');
  problems.forEach((p) => console.log(' - ' + p));
  process.exit(1);
}
console.log('\nBalance OK.');
