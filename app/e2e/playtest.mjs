// Playtest automático de punta a punta (Playwright + chromium SwiftShader, sin red).
// Uso: npm run build && NODE_PATH=$(npm root -g) node e2e/playtest.mjs
// Juega: Splash → menú → mapa → nivel 1 (casa) → resultado → desbloqueo del 2 → tienda (control parental)
// → desbloqueo del 3 con Soles → finca con Zonda (defensa + limpieza) → escuela con conector flojo (multímetro)
// → mide draw calls del parque (nivel 5). Falla si hay errores de consola o de página.
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync, existsSync } from 'node:fs';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const here = dirname(fileURLToPath(import.meta.url));
const APP = join(here, '..');
const OUT = join(here, 'out');
mkdirSync(OUT, { recursive: true });
const html = join(APP, 'dist', 'index.html');
if (!existsSync(html)) { console.error('Falta dist/: corré npm run build'); process.exit(2); }

const errors = [];
const steps = [];
const t0 = Date.now();
const log = (m) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
function ok(name, detail = '') { steps.push({ name, ok: true, detail }); log(`OK   ${name}${detail ? ' — ' + detail : ''}`); }
function fail(name, detail) { steps.push({ name, ok: false, detail }); log(`FAIL ${name} — ${detail}`); throw new Error(`${name}: ${detail}`); }
function check(cond, name, detail = '') { if (cond) ok(name, detail); else fail(name, detail || 'condición falsa'); }

const browser = await chromium.launch({
  executablePath: undefined,
  args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--allow-file-access-from-files'],
});
const context = await browser.newContext({ offline: true, isMobile: true, hasTouch: true, viewport: { width: 915, height: 412 }, deviceScaleFactor: 1, reducedMotion: 'reduce' });
// Calidad "Baja" para que SwiftShader (CPU) ande a ~3 fps; el nivel 5 se juega en "Media" (cambiada desde Ajustes).
await context.addInitScript(() => {
  window.ME_DEBUG = true;
  if (!sessionStorage.getItem('me-e2e')) { sessionStorage.setItem('me-e2e', '1'); localStorage.clear(); localStorage.setItem('me.v1.settings.quality', '"low"'); }
});
const page = await context.newPage();
page.on('console', (m) => { if (m.type() === 'error') { errors.push(`console: ${m.text()}`); log(`console.error: ${m.text()}`); } });
page.on('pageerror', (e) => { errors.push(`pageerror: ${e.message}`); log(`pageerror: ${e.message}`); });

const sleep = (ms) => page.waitForTimeout(ms);
const shot = async (name) => { await sleep(250); await page.screenshot({ path: join(OUT, `${name}.png`) }); log(`captura ${name}.png`); };
const me = (fn, arg) => page.evaluate(fn, arg);
const state = () => me(() => window.__me.state());
const tapText = async (text, scope = 'body') => { await page.locator(scope).getByRole('button', { name: text, exact: false }).first().click(); await sleep(200); };

/** Lleva al técnico a la acción, verifica el botón grande y lo toca (como un jugador). */
async function act(q, expectLabel) {
  const label = await me((x) => window.__me.goTo(x), q);
  if (!label) fail(`acción "${q}"`, `no disponible. Hay: ${JSON.stringify((await me(() => window.__me.actions())).map((a) => a.label))}`);
  await sleep(90);
  const btn = page.locator('.hud-act');
  const txt = (await btn.innerText()).trim();
  if (expectLabel && !txt.startsWith(expectLabel)) fail(`botón "${q}"`, `dice "${txt}"`);
  await btn.click({ force: true });
  await sleep(110);
  return txt;
}
const hasAction = async (q) => (await me(() => window.__me.actions())).some((a) => a.label.startsWith(q) || a.id === q);
async function waitFor(pred, what, timeout = 90000, every = 150) {
  const end = Date.now() + timeout;
  for (;;) {
    const s = await state();
    if (pred(s)) return s;
    if (Date.now() > end) fail(`esperar ${what}`, `timeout. Estado: ${JSON.stringify({ phase: s.phase, weather: s.weather, hour: s.hour, screen: s.screen })}`);
    await sleep(every);
  }
}

/** Construye todo lo comprado con las acciones del mundo. */
async function buildPlant({ screenshotAt = -1, wrongCable = false } = {}) {
  let n = 0;
  while (await hasAction('Tomar panel')) {
    await act('Tomar panel', 'Tomar panel');
    await act('Colocar panel', 'Colocar panel');
    n++;
    if (n === screenshotAt) await shot('03-construccion');
  }
  ok('paneles instalados', `${(await state()).panels}`);
  await act('Tomar protección', 'Tomar protección');
  await act('Instalar protección', 'Instalar protección');
  while (await hasAction('Tomar batería')) { await act('Tomar batería'); await act('Instalar batería', 'Instalar batería'); }
  if (await hasAction('Tomar kit')) { await act('Tomar kit'); await act('Instalar trabas', 'Instalar trabas'); }
  const s = await state();
  check(s.batteries > 0, 'baterías instaladas', `${s.batteries}`);
  await act('Tomar cable naranja', 'Tomar cable naranja');
  if (wrongCable) {
    await act('Conectar al inversor', 'Conectar al inversor');
    const toast = await page.locator('.ui-toast').innerText();
    check(/protección/.test(toast) && (await state()).hands === 'cable', 'pista por cable equivocado', toast.slice(0, 60));
  }
  await act('Conectar a la protección', 'Conectar a la protección');
  await act('Tomar cable azul', 'Tomar cable azul');
  await act('Conectar al inversor', 'Conectar al inversor');
  await act('Tomar cable violeta', 'Tomar cable violeta');
  await act('Conectar al inversor', 'Conectar al inversor');
  ok('tres cables conectados');
}

async function activate() {
  await act('Activar planta', 'Activar planta');
  const s = await waitFor((x) => x.phase === 'running', 'planta activa', 5000);
  ok('planta activada', `hora ${s.hour.toFixed(2)}`);
}

async function workshopBuy(panels, batteries, kit = false) {
  await page.waitForSelector('.pg-workshop');
  const out = page.locator('.ws-out');
  const setTo = async (idx, target, plus, minus) => {
    for (let i = 0; i < 20; i++) {
      const v = Number(await out.nth(idx).innerText());
      if (v === target) return;
      await page.locator(`button[aria-label="${v < target ? plus : minus}"]`).click();
      await sleep(40);
    }
  };
  await setTo(0, panels, 'Agregar panel', 'Quitar panel');
  await setTo(1, batteries, 'Agregar batería', 'Quitar batería');
  if (kit) await page.locator('button[aria-label="Agregar kit"]').click();
}

async function resultScreen(name) {
  await page.waitForSelector('.rs', { timeout: 120000 });
  await sleep(1300);
  await shot(name);
  const won = await page.locator('.rs.is-won').count();
  const soles = await page.locator('.rs-kpi').filter({ hasText: 'Soles ganados' }).locator('b').innerText();
  const title = await page.locator('.rs-title').innerText();
  return { won: won > 0, soles: Number(soles.replace(/[^\d]/g, '')), title };
}

async function clockUntil(pred, mult, what, timeout) {
  await me((m) => window.__me.clock(m), mult);
  return waitFor(pred, what, timeout);
}

try {
  /* ---------------------------------------------------------------- arranque y menú */
  await page.goto(pathToFileURL(html).href);
  await page.waitForSelector('.splash-tap');
  await shot('00-splash');
  await page.locator('.splash-tap').click();
  await page.waitForSelector('.pg-menu');
  await sleep(700);
  const bal0 = (await state()).balance;
  check(bal0 === 50, 'regalo de bienvenida', `${bal0} Soles`);
  await tapText('Reclamar');
  await sleep(300);
  check((await state()).balance === 70, 'bono diario', `${(await state()).balance} Soles`);
  await shot('01-menu');

  /* ---------------------------------------------------------------- nivel 1: casa */
  await tapText('Jugar');
  await page.waitForSelector('.pg-map');
  await page.locator('.lm-bubble').nth(0).click();
  await workshopBuy(3, 1);
  await shot('02-taller');
  await tapText('Construir');
  await waitFor((s) => s.phase === 'build', 'partida nivel 1', 30000);
  ok('nivel 1 iniciado');
  await sleep(600);
  await shot('02b-inicio-partida');
  // Revisar: abrir la ficha cerca del pallet
  await me(() => window.__me.goTo('Tomar panel'));
  await sleep(150);
  await page.locator('button[aria-label="Revisar lo que tenés cerca"]').click();
  await sleep(200);
  check(await page.locator('.hud-inspect').isVisible(), 'ficha Revisar', await page.locator('#ins-title').innerText());
  await page.locator('button[aria-label="Cerrar ficha"]').click();
  await buildPlant({ screenshotAt: 2, wrongCable: true });
  await activate();
  await shot('04-activada');
  await clockUntil((s) => s.hour >= 22.5 || s.phase === 'finished', 25, 'noche', 120000);
  await me(() => window.__me.clock(0.0001));
  await me(() => window.__me.teleport(12.5, -2.5));
  await me(() => window.__me.camera(-0.42, 0.36, 16));
  await sleep(500);
  await shot('05-noche-ciudad');
  const sNight = await state();
  check(sNight.snap && sNight.snap.isNight && !sNight.snap.blackout, 'de noche con luz', `bat ${(sNight.snap.socPct * 100).toFixed(0)}%`);
  await clockUntil((s) => s.phase === 'finished', 40, 'fin nivel 1', 120000);
  const r1 = await resultScreen('06-resultado-casa');
  check(r1.won && r1.soles > 0, 'nivel 1 ganado con Soles', `${r1.title} · +${r1.soles} Soles`);

  /* ---------------------------------------------------------------- mapa: nivel 2 desbloqueado */
  await page.locator('.rs').getByRole('button', { name: 'Mapa' }).click();
  await page.waitForSelector('.pg-map');
  await sleep(300);
  const n2locked = await page.locator('.lm-node').nth(1).evaluate((n) => n.classList.contains('is-locked'));
  check(!n2locked, 'nivel 2 desbloqueado');

  /* ---------------------------------------------------------------- tienda con control parental */
  const balBefore = (await state()).balance;
  await page.locator('.pg-map .wallet-chip.is-btn').click();
  await page.waitForSelector('.pg-shop');
  await shot('07-tienda');
  await page.locator('.shop-card.is-token-pack').first().getByRole('button').first().click();
  await page.waitForSelector('.pgm-q');
  const q = await page.locator('.pgm-q').innerText();
  const m = q.match(/(\d)\s*×\s*(\d)/);
  const ans = String(Number(m[1]) * Number(m[2]));
  await shot('08-control-parental');
  for (const d of ans) await page.locator('.pgm-key', { hasText: new RegExp(`^${d}$`) }).click();
  await page.locator('.pgm-key.is-ok').click();
  await page.waitForSelector('.sheet-card.is-good', { timeout: 10000 });
  await shot('09-compra-ok');
  const balAfter = (await state()).balance;
  check(balAfter === balBefore + 120, 'pack de Soles acreditado (demo)', `${balBefore} → ${balAfter}`);
  await page.locator('.sheet-card').getByRole('button', { name: 'Listo' }).click();
  await page.locator('.pg-shop button[aria-label="Volver"]').click();
  await page.waitForSelector('.pg-map');

  /* ---------------------------------------------------------------- desbloquear nivel 3 con Soles */
  await page.locator('.lm-bubble').nth(2).click();
  await page.waitForSelector('.lm-card');
  await page.locator('.lm-card').getByRole('button', { name: /Desbloquear por/ }).click();
  await page.locator('.lm-card').getByRole('button', { name: 'Sí, desbloquear' }).click();
  await sleep(300);
  const n3locked = await page.locator('.lm-node').nth(2).evaluate((n) => n.classList.contains('is-locked'));
  check(!n3locked && (await state()).balance === balAfter - 180, 'nivel 3 desbloqueado con Soles', `saldo ${(await state()).balance}`);

  /* ---------------------------------------------------------------- nivel 3: finca con Zonda */
  await page.locator('.lm-bubble').nth(2).click();
  await workshopBuy(5, 2);
  await tapText('Construir');
  await waitFor((s) => s.phase === 'build' && s.level === 'finca', 'partida finca', 30000);
  await buildPlant();
  await activate();
  await clockUntil((s) => s.hour >= 12.75, 8, 'antes del Zonda', 60000);
  await clockUntil((s) => s.weather === 'zonda-warning', 2, 'aviso de Zonda', 60000);
  check(await page.locator('.hud-alert').isVisible(), 'alerta de Zonda con cuenta regresiva', await page.locator('.al-count').innerText());
  await me(() => window.__me.clock(0.5));
  await act('defense:0', 'Fila 1: defensa');
  await act('defense:1', 'Fila 2: defensa');
  check((await state()).defense.every(Boolean), 'filas en defensa');
  await shot('10-zonda-aviso');
  await clockUntil((s) => s.weather === 'zonda-storm', 6, 'tormenta', 60000);
  await me(() => window.__me.clock(0.3));
  await me(() => window.__me.camera(0.5, 0.45, 12));
  await sleep(1200);
  await shot('11-zonda-tormenta');
  const sStorm = await state();
  check(sStorm.lost === 0 && sStorm.rowsDirty.every(Boolean), 'Zonda: sin paneles perdidos, filas con polvo');
  await clockUntil((s) => s.weather === 'zonda-over', 6, 'fin del Zonda', 60000);
  await me(() => window.__me.clock(0.3));
  await act('clean:0', 'Limpiar fila 1');
  await act('clean:1', 'Limpiar fila 2');
  check((await state()).rowsDirty.every((d) => !d), 'filas limpias');
  await clockUntil((s) => s.phase === 'finished', 40, 'fin finca', 150000);
  const r3 = await resultScreen('12-resultado-finca');
  check(r3.won, 'finca ganada', `${r3.title} · +${r3.soles} Soles`);

  /* ---------------------------------------------------------------- vestuario: casco azul */
  await page.locator('.rs').getByRole('button', { name: 'Mapa' }).click();
  await page.waitForSelector('.pg-map');
  await page.locator('.pg-map button[aria-label="Volver"]').click();
  await page.waitForSelector('.pg-menu');
  await tapText('Tienda');
  await page.waitForSelector('.pg-shop');
  await page.locator('.tab', { hasText: 'Vestuario' }).click();
  await page.locator('button[aria-label^="Comprar Casco azul"]').click();
  await page.locator('.shop-card .sc-btns').getByRole('button', { name: 'Comprar' }).click();
  await page.waitForSelector('.sheet-card.is-good');
  await page.locator('.sheet-card').getByRole('button', { name: 'Ponérmelo' }).click();
  await page.locator('.pg-shop button[aria-label="Volver"]').click();
  await tapText('Vestuario');
  await page.waitForSelector('.pg-wardrobe');
  await shot('12b-vestuario');
  await page.locator('.pg-wardrobe button[aria-label="Volver"]').click();
  await tapText('Jugar');

  /* ---------------------------------------------------------------- nivel 2: escuela con conector flojo */
  await page.waitForSelector('.pg-map');
  await page.locator('.lm-bubble').nth(1).click();
  await workshopBuy(4, 2);
  await tapText('Construir');
  const sEsc = await waitFor((s) => s.phase === 'build' && s.level === 'escuela', 'partida escuela', 30000);
  check(sEsc.cosmetics.helmet === 0x2f7be0, 'vestuario aplicado al técnico (casco azul)');
  await buildPlant();
  await page.locator('button[aria-label="Sacar o guardar el multímetro"]').click();
  await sleep(150);
  await act('Medir filas', 'Medir filas');
  await shot('13-multimetro-filas');
  let s2 = await state();
  check(s2.connector.rowFound, 'multímetro: fila en 0 V', await page.locator('.mt-value').innerText());
  const ids = (await me(() => window.__me.actions())).filter((a) => a.label === 'Medir panel').map((a) => a.id);
  let repaired = false;
  for (const id of ids) {
    await act(id, 'Medir panel');
    if (await hasAction('Reconectar conector')) {
      check((await page.locator('.mt-value').innerText()).includes('OL'), 'panel con conector abierto (OL)');
      await shot('14-multimetro-OL');
      await act('Reconectar conector', 'Reconectar conector');
      repaired = true;
      break;
    }
  }
  s2 = await state();
  check(repaired && s2.connector.fixed && s2.rowsOpen.every((o) => !o), 'conector reparado');
  await page.locator('button[aria-label="Sacar o guardar el multímetro"]').click();
  await activate();
  await clockUntil((s) => s.phase === 'finished', 40, 'fin escuela', 150000);
  const r2 = await resultScreen('15-resultado-escuela');
  check(r2.won, 'escuela ganada', `${r2.title}`);

  /* ---------------------------------------------------------------- ajustes: calidad media */
  await page.locator('.rs').getByRole('button', { name: 'Mapa' }).click();
  await page.waitForSelector('.pg-map');
  await page.locator('.pg-map button[aria-label="Volver"]').click();
  await page.waitForSelector('.pg-menu');
  await tapText('Ajustes');
  await page.waitForSelector('.pg-settings');
  await page.locator('.seg-btn', { hasText: 'Media' }).click();
  const qSaved = await me(() => localStorage.getItem('me.v1.settings.quality'));
  check(qSaved === '"medium"', 'calidad guardada', qSaved);
  await shot('15b-ajustes');
  await page.locator('.pg-settings button[aria-label="Volver"]').click();

  /* ---------------------------------------------------------------- nivel 5: draw calls */
  await me(() => window.__me.app.startLevel({ levelId: 'parque', purchase: { panels: 10, batteries: 4, kitZonda: true }, boosters: ['boost_hint', 'boost_drone', 'boost_battery'] }));
  await waitFor((s) => s.phase === 'build' && s.level === 'parque', 'partida parque', 30000);
  await buildPlant();
  await activate();
  check((await state()).snap.capKwh === 32, 'batería de emergencia (+4 kWh)', `${(await state()).snap.capKwh} kWh`);
  await sleep(600);
  const dcDay = await me(() => window.__me.drawCalls());
  await me(() => window.__me.camera(0.18, 0.6, 11.5));
  await shot('16-parque-dia');
  await clockUntil((s) => s.hour >= 22 || s.phase === 'finished', 30, 'noche parque', 150000);
  await me(() => window.__me.clock(0.0001));
  const sPq = await waitFor((s) => !s.drone, 'dron de vuelta', 120000);
  check(sPq.rowsDirty.every((d) => !d), 'dron limpió las filas después del Zonda');
  const dcNight = await me(() => window.__me.drawCalls());
  await shot('17-parque-noche');
  ok('draw calls parque', `día: ${JSON.stringify(dcDay)} · noche: ${JSON.stringify(dcNight)}`);

  /* ---------------------------------------------------------------- botón atrás de Android */
  const backRes = await me(() => window.meHandleBack());
  check(backRes === true && (await state()).paused === true, 'atrás en partida abre Pausa');
  await shot('18-pausa');
} catch (e) {
  log(`ERROR: ${e.message}`);
  try { await page.screenshot({ path: join(OUT, 'zz-error.png') }); } catch { /* nada */ }
  steps.push({ name: 'excepción', ok: false, detail: e.message });
}

await browser.close();
const failed = steps.filter((s) => !s.ok);
console.log(`\nPasos OK: ${steps.length - failed.length}/${steps.length}`);
if (errors.length) { console.log('Errores de consola/página:'); errors.forEach((e) => console.log(' - ' + e)); }
if (failed.length || errors.length) process.exit(1);
console.log('PLAYTEST OK');
