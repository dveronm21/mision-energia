// Captura la escena de muestra con Playwright (chromium + SwiftShader).
// Uso: npx esbuild dev/showcase.ts --bundle --outfile=dev/out/showcase.js && NODE_PATH=$(npm root -g) node dev/shot.mjs [filtro]
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { writeFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
// ESM ignora NODE_PATH: resolvemos playwright con require (NODE_PATH=$(npm root -g)).
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const html = pathToFileURL(join(here, 'showcase.html')).href;
const filter = process.argv[2] || '';

const shots = [
  { name: 'day-game-high', q: 'high', view: 'game', hour: 10.5 },
  { name: 'day-overview-high', q: 'high', view: 'overview', hour: 11 },
  { name: 'day-closeup-high', q: 'high', view: 'closeup', hour: 10 },
  { name: 'day-equip-high', q: 'high', view: 'equip', hour: 10.5 },
  { name: 'day-field-high', q: 'high', view: 'field', hour: 10.5, extra: 'dirty=0' },
  { name: 'dusk-game-high', q: 'high', view: 'game', hour: 19.4, extra: 'clouds=0.5' },
  { name: 'night-city-high', q: 'high', view: 'city', hour: 22 },
  { name: 'night-game-high', q: 'high', view: 'game', hour: 23.5 },
  { name: 'zonda-game-high', q: 'high', view: 'game', hour: 15, extra: 'zonda=0.85&defense=1' },
  { name: 'day-overview-low', q: 'low', view: 'overview', hour: 11 },
  { name: 'day-game-low', q: 'low', view: 'game', hour: 10.5 },
  { name: 'typical-game-high', q: 'high', view: 'game', hour: 10.5, extra: 'typical=1' },
  { name: 'typical-overview-high', q: 'high', view: 'overview', hour: 10.5, extra: 'typical=1' },
  { name: 'typical-overview-low', q: 'low', view: 'overview', hour: 10.5, extra: 'typical=1' },
  { name: 'day-game-medium', q: 'medium', view: 'game', hour: 10.5 },
  { name: 'webgl1-game-high', q: 'high', view: 'game', hour: 10.5, extra: 'gl=1', dpr: 1 },
  { name: 'webgl1-night-low', q: 'low', view: 'game', hour: 23, extra: 'gl=1', dpr: 1 },
];

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--allow-file-access-from-files'] });
const results = [];
for (const s of shots) {
  if (filter && !s.name.includes(filter)) continue;
  const page = await browser.newPage({ viewport: { width: 915, height: 412 }, deviceScaleFactor: s.dpr ?? 2 });
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log(`[${s.name}] ${m.type()}: ${m.text()}`); });
  page.on('pageerror', (e) => console.log(`[${s.name}] pageerror: ${e.message}`));
  const url = `${html}?q=${s.q}&view=${s.view}&hour=${s.hour}${s.extra ? '&' + s.extra : ''}`;
  await page.goto(url);
  try {
    await page.waitForFunction(() => window.__ready || window.__error, null, { timeout: 120000 });
  } catch (e) { console.log(`[${s.name}] timeout`); }
  const err = await page.evaluate(() => window.__error);
  if (err) console.log(`[${s.name}] ERROR ${err}`);
  await page.waitForTimeout(300);
  const stats = await page.evaluate(() => window.__stats);
  const out = join(here, 'out', `${s.name}.png`);
  await page.screenshot({ path: out, timeout: 120000 });
  console.log(s.name, JSON.stringify(stats));
  results.push({ ...s, stats });
  await page.close();
}
writeFileSync(join(here, 'out', 'stats.json'), JSON.stringify(results, null, 2));
await browser.close();
