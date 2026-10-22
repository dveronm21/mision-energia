// e2e del modo TV: servidor Node que hace de "tele" (igual que el servidor Java: HTTP + WebSocket),
// una página tele de prueba con RemoteHost + LobbyView (puente por WebSocket de relay) y tablets
// simuladas con Playwright (hasTouch). Sin red externa.
//
// Uso: npm run build && NODE_PATH=$(npm root -g) node e2e/remote-e2e.mjs
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join, extname, normalize } from 'node:path';
import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import { build } from 'esbuild';
import { WebSocketServer } from 'ws';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const here = dirname(fileURLToPath(import.meta.url));
const APP = join(here, '..');
const OUT = join(here, 'out');
const TV_DIR = join(OUT, '.tv');
const CTRL_DIR = join(APP, 'dist', 'controller');
mkdirSync(TV_DIR, { recursive: true });
if (!existsSync(join(CTRL_DIR, 'index.html'))) { console.error('Falta dist/controller: corré npm run build'); process.exit(2); }

const t0 = Date.now();
const log = (m) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
let passed = 0;
function check(cond, name, detail = '') {
  if (!cond) { log(`FAIL ${name}${detail ? ' — ' + detail : ''}`); throw new Error(name); }
  passed++; log(`OK   ${name}${detail ? ' — ' + detail : ''}`);
}

/* ---------------- Página tele de prueba ---------------- */
await build({
  entryPoints: [join(APP, 'src/remote/dev/TvHarness.ts')], bundle: true, format: 'iife', target: ['es2019'],
  outfile: join(TV_DIR, 'harness.js'), logLevel: 'warning',
});
writeFileSync(join(TV_DIR, 'index.html'), '<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tele de prueba</title></head><body><script src="harness.js"></script></body></html>');

/* ---------------- Servidor (hace de app Java del tele) ---------------- */
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.woff2': 'font/woff2', '.css': 'text/css' };
function serve(res, root, rel) {
  const p = normalize(join(root, rel));
  if (!p.startsWith(root) || !existsSync(p)) { res.writeHead(404); res.end('404'); return; }
  res.writeHead(200, { 'content-type': MIME[extname(p)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(readFileSync(p));
}
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  let path = decodeURIComponent(url.pathname);
  if (path.startsWith('/tv/fonts/')) return serve(res, join(APP, 'dist', 'fonts'), path.slice('/tv/fonts/'.length));
  if (path.startsWith('/tv/')) return serve(res, TV_DIR, path.slice(4) || 'index.html');
  if (path === '/') path = '/index.html';
  return serve(res, CTRL_DIR, path.slice(1));
});

const wssClients = new WebSocketServer({ noServer: true, maxPayload: 4096 });
const wssRelay = new WebSocketServer({ noServer: true });
const net = { nextId: 1, clients: new Map(), names: new Map(), relay: null, pending: [], blocked: false };
const toRelay = (ev) => { const s = JSON.stringify(ev); if (net.relay?.readyState === 1) net.relay.send(s); else net.pending.push(s); };

server.on('upgrade', (req, socket, head) => {
  const path = new URL(req.url, 'http://x').pathname;
  if (path === '/bridge') { wssRelay.handleUpgrade(req, socket, head, (ws) => wssRelay.emit('connection', ws)); return; }
  if (path === '/ws') {
    if (net.blocked) { socket.destroy(); return; }
    wssClients.handleUpgrade(req, socket, head, (ws) => wssClients.emit('connection', ws, req));
    return;
  }
  socket.destroy();
});
wssClients.on('connection', (ws, req) => {
  const id = net.nextId++;
  net.clients.set(id, ws);
  toRelay({ e: 'open', id, addr: req.socket.remoteAddress ?? '' });
  ws.on('message', (data) => {
    const s = data.toString();
    try { const m = JSON.parse(s); if (m.t === 'hello') net.names.set(m.name, id); } catch { /* */ }
    toRelay({ e: 'msg', id, data: s });
  });
  ws.on('close', () => { net.clients.delete(id); toRelay({ e: 'close', id }); });
  ws.on('error', () => {});
});
wssRelay.on('connection', (ws) => {
  net.relay = ws;
  for (const s of net.pending.splice(0)) ws.send(s);
  ws.on('message', (data) => {
    let m; try { m = JSON.parse(data.toString()); } catch { return; }
    const c = net.clients.get(m.id);
    if (!c) return;
    if (m.cmd === 'send') c.send(m.json);
    else if (m.cmd === 'close') c.close(1000, String(m.reason).slice(0, 60));
  });
});
/** Corte de red "duro" de una tablet (el socket muere sin cierre limpio). */
function dropClient(name) { const id = net.names.get(name); const ws = net.clients.get(id); ws?.terminate(); return id; }

const PORT = await new Promise((resolve) => {
  server.once('error', () => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
  server.listen(8765, '127.0.0.1', () => resolve(8765));
});
const BASE = `http://127.0.0.1:${PORT}`;
log(`servidor en ${BASE}`);

/* ---------------- Navegador ---------------- */
const browser = await chromium.launch({ args: ['--use-gl=swiftshader'] });
const errors = [];
const watch = (page, who) => {
  page.on('pageerror', (e) => errors.push(`${who} pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    const t = m.text();
    if (/WebSocket connection to .* failed|ERR_CONNECTION|net::/.test(t)) return; // cortes provocados por la prueba
    errors.push(`${who} console: ${t}`);
  });
};
const shot = (page, name) => page.screenshot({ path: join(OUT, `remote-${name}.png`) });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, what, timeout = 8000) {
  const end = Date.now() + timeout;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`timeout esperando: ${what}`);
    await wait(60);
  }
}

// Tele
const tvCtx = await browser.newContext({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
const tv = await tvCtx.newPage();
watch(tv, 'tele');
await tv.goto(`${BASE}/tv/?relay=${encodeURIComponent(`ws://127.0.0.1:${PORT}/bridge`)}&url=${encodeURIComponent(`http://192.168.0.23:${PORT}/`)}&tv=${encodeURIComponent('Tele del living')}`);
await tv.waitForFunction(() => !!window.__tv);
await tv.evaluate(() => document.fonts.ready);
const tvState = () => tv.evaluate(() => {
  const { host, stats } = window.__tv;
  return { players: host.players(), stats: JSON.parse(JSON.stringify(stats)) };
});
check(await tv.locator('.rl-qr svg path').count() === 1, 'lobby: QR dibujado');
check(await tv.locator('.rl-btn-primary').isDisabled(), 'lobby: "Empezar" deshabilitado sin jugadores');
await wait(300);
await shot(tv, 'lobby-empty-1080');

// Tablets
async function tablet(name, viewport) {
  const ctx = await browser.newContext({ viewport, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  await ctx.addInitScript(() => {
    window.__vib = [];
    Object.defineProperty(Navigator.prototype, 'vibrate', { configurable: true, value(p) { window.__vib.push(p); return true; } });
  });
  const page = await ctx.newPage();
  watch(page, name);
  await page.goto(`${BASE}/`);
  await page.evaluate(() => document.fonts.ready);
  const cdp = await ctx.newCDPSession(page);
  return { name, page, ctx, cdp };
}
const screenOf = (t) => t.page.evaluate(() => document.querySelector('.c-app')?.dataset.screen);
async function enter(t, name) {
  await t.page.waitForSelector('.c-name input');
  await t.page.fill('.c-name input', name);
  await t.page.tap('.c-name button');
}
async function center(t, sel) {
  const b = await t.page.locator(sel).first().boundingBox();
  return { x: Math.round(b.x + b.width / 2), y: Math.round(b.y + b.height / 2) };
}
const touch = (t, type, points) => t.cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points });
async function tapTouch(t, sel) {
  const p = await center(t, sel);
  await touch(t, 'touchStart', [{ x: p.x, y: p.y, id: 7 }]);
  await wait(50);
  await touch(t, 'touchEnd', []);
}

const A = await tablet('Ana', { width: 1280, height: 800 });
await A.page.waitForSelector('.c-name input');
await shot(A.page, 'ctrl-name-1280');
await enter(A, 'Ana');
await until(async () => (await screenOf(A)) === 'lobby', 'Ana en sala de espera');
let st = await until(async () => { const s = await tvState(); return s.players[0]?.name === 'Ana' && s.players[0].connected && s; }, 'Ana en el tele');
check(st.players[0].color === '#F28C28', 'Ana ocupa el lugar 1 (naranja)');

const B = await tablet('Beto', { width: 1024, height: 600 });
await enter(B, 'Beto');
await until(async () => (await screenOf(B)) === 'lobby', 'Beto en sala de espera');
st = await until(async () => { const s = await tvState(); return s.players[1]?.name === 'Beto' && s; }, 'Beto en el tele');
check(st.players[1].colorName === 'Azul', 'Beto ocupa el lugar 2 (azul)');
await until(async () => { const s = await tvState(); return s.players.every((p) => p && p.latencyMs !== null); }, 'latencias medidas', 5000);
await shot(A.page, 'ctrl-lobby-1280');
await tv.evaluate(() => window.__tv.lobby.refresh());
await wait(300);
await shot(tv, 'lobby-1080');
await tv.setViewportSize({ width: 1280, height: 720 });
await wait(300);
await shot(tv, 'lobby-720');
await tv.setViewportSize({ width: 1920, height: 1080 });

// D-pad: el foco arranca en "Empezar"; arriba va a un "Quitar"; abajo vuelve; OK empieza.
const focused = () => tv.evaluate(() => document.activeElement?.textContent?.trim() ?? '');
check((await focused()) === 'Empezar', 'D-pad: foco inicial en Empezar', await focused());
await tv.keyboard.press('ArrowUp');
check(/Quitar/.test(await focused()), 'D-pad: flecha arriba → Quitar', await focused());
await tv.keyboard.press('ArrowDown');
if ((await focused()) !== 'Empezar') await tv.keyboard.press('ArrowLeft');
check((await focused()) === 'Empezar', 'D-pad: flecha abajo → Empezar');
await tv.keyboard.press('Enter');
await until(async () => (await tvState()).stats.started, 'partida empezada');
await until(async () => (await screenOf(A)) === 'play' && (await screenOf(B)) === 'play', 'tablets en modo juego');
await until(async () => (await A.page.textContent('.c-act'))?.includes('Tomar panel'), 'botón de acción con texto de contexto');
check(true, 'contexto: "Tomar panel" en la tablet');

// Joystick flotante + acción a la vez (multitouch).
const z = await A.page.locator('.c-zone').boundingBox();
const sx = Math.round(z.x + z.width * 0.4), sy = Math.round(z.y + z.height * 0.6);
await touch(A, 'touchStart', [{ x: sx, y: sy, id: 0 }]);
for (let i = 1; i <= 6; i++) { await touch(A, 'touchMove', [{ x: sx + i * 18, y: sy - i * 6, id: 0 }]); await wait(30); }
st = await until(async () => { const s = await tvState(); return s.stats.maxX[0] > 0.5 && s; }, 'joystick hacia la derecha en el tele');
check(st.stats.maxX[0] > 0.5 && st.stats.minY[0] < 0, 'joystick: x/y llegan al tele', `x=${st.stats.maxX[0]} y=${st.stats.minY[0]}`);
const act = await center(A, '.c-act');
await touch(A, 'touchStart', [{ x: sx + 108, y: sy - 36, id: 0 }, { x: act.x, y: act.y, id: 1 }]);
await wait(80);
await shot(A.page, 'ctrl-play-1280');
// Levanta solo el dedo de la acción: la lista de puntos activos ya no incluye el id 1.
await touch(A, 'touchMove', [{ x: sx + 110, y: sy - 36, id: 0 }]);
st = await until(async () => { const s = await tvState(); return s.stats.actions[0] === 1 && s; }, 'acción recibida');
check(st.stats.last[0].x > 0.3 && st.stats.last[0].connected, 'multitouch: joystick sigue activo mientras se aprieta acción', `x=${st.stats.last[0].x}`);
const vib = await until(async () => { const v = await A.page.evaluate(() => window.__vib); return v.some((p) => JSON.stringify(p) === '[30,40,30]') && v; }, 'vibración del tele');
check(true, 'vibración: patrón [30,40,30] del tele llegó a navigator.vibrate', JSON.stringify(vib));
await until(async () => (await A.page.textContent('.c-act'))?.includes('Colocar panel'), 'contexto actualizado tras la acción');
// Correr: el dedo sale del aro.
await touch(A, 'touchMove', [{ x: sx + 260, y: sy, id: 0 }]);
st = await until(async () => { const s = await tvState(); return s.stats.last[0]?.run && s; }, 'correr');
check(st.stats.last[0].run, 'joystick: fuera del aro = correr');
await wait(60);
await shot(A.page, 'ctrl-run-1280');
await touch(A, 'touchEnd', []);
st = await until(async () => { const s = await tvState(); return s.stats.last[0].x === 0 && s; }, 'joystick suelto vuelve a 0');
check(st.stats.last[0].x === 0, 'joystick: al soltar vuelve a 0');

// Tablet B: Revisar + Multímetro.
await tapTouch(B, '.c-col .c-round:nth-child(2)');
await tapTouch(B, '.c-col .c-round:nth-child(1)');
st = await until(async () => { const s = await tvState(); return s.stats.inspects[1] === 1 && s.stats.tools[1] === 1 && s; }, 'Revisar y Multímetro');
check(st.stats.toolOn[1], 'Multímetro encendido en el tele');
await until(async () => (await B.page.textContent('.c-onoff')) === 'ON', 'estado ON en la tablet');
await wait(200);
await shot(B.page, 'ctrl-play-1024');

// Corte de red de Ana: el tele la marca desconectada y guarda su lugar; la tablet reintenta.
net.blocked = true;
dropClient('Ana');
st = await until(async () => { const s = await tvState(); return s.players[0] && !s.players[0].connected && s; }, 'Ana desconectada en el tele');
check(st.players[0].reservedUntil !== null, 'asiento de Ana reservado');
await until(async () => (await screenOf(A)) === 'retrying', 'tablet muestra reconectando');
await wait(400);
await shot(A.page, 'ctrl-reconnecting-1280');
// El tele vuelve a la sala: se ve el lugar guardado.
await tv.keyboard.press('Escape');
await wait(400);
await shot(tv, 'lobby-reconnecting-1080');
await tv.evaluate(() => window.__tv.start());
net.blocked = false;
await A.page.evaluate(() => document.querySelector('.c-over .c-btn-primary')?.click());
st = await until(async () => { const s = await tvState(); return s.players[0]?.connected && s; }, 'Ana reconectada', 10000);
check(st.players[0].name === 'Ana' && st.stats.resumes >= 1, 'reconexión: mismo asiento (lugar 1) con el mismo token', `resumes=${st.stats.resumes}`);
await until(async () => (await screenOf(A)) === 'play', 'Ana vuelve al juego');
check((await A.page.textContent('.c-me-sub'))?.includes('Jugador 1'), 'tablet de Ana sigue siendo Jugador 1');
await tapTouch(A, '.c-act');
st = await until(async () => { const s = await tvState(); return s.stats.actions[0] === 2 && s; }, 'acción tras reconectar');
check(st.stats.actions[0] === 2, 'toques siguen contando tras reconectar (sin duplicados)');

// Tercer cliente: rechazado con "lleno".
const C = await tablet('Caro', { width: 1024, height: 600 });
await enter(C, 'Caro');
await until(async () => (await screenOf(C)) === 'full', 'Caro ve "tele lleno"');
st = await tvState();
check(st.players.filter(Boolean).length === 2 && !st.players.some((p) => p?.name === 'Caro'), 'tercer cliente rechazado (full)');
await wait(200);
await shot(C.page, 'ctrl-full-1024');

// Pausa desde la tablet.
await tapTouch(A, '.c-pause');
await until(async () => (await tvState()).stats.paused, 'pausa en el tele');
await until(async () => (await screenOf(A)) === 'paused' && (await screenOf(B)) === 'paused', 'tablets en pausa');
check(true, 'pausa: el tele pausa y ambas tablets lo muestran');
await wait(200);
await shot(A.page, 'ctrl-paused-1280');
await A.page.tap('.c-over .c-btn-primary');
await until(async () => !(await tvState()).stats.paused && (await screenOf(A)) === 'play', 'seguir');
check(true, 'pausa: "Seguir" reanuda');

// Toast + tablet en vertical.
await tapTouch(B, '.c-col .c-round:nth-child(2)');
await B.page.waitForSelector('.c-toast');
await shot(B.page, 'ctrl-toast-1024');
await A.page.setViewportSize({ width: 800, height: 1280 });
await wait(200);
check(await A.page.locator('.c-rotate').isVisible(), 'vertical: aviso para girar la tablet');
await shot(A.page, 'ctrl-portrait');

// Sin scroll ni zoom: el documento no desborda.
const overflow = await B.page.evaluate(() => [document.documentElement.scrollWidth - innerWidth, document.documentElement.scrollHeight - innerHeight]);
check(overflow[0] <= 0 && overflow[1] <= 0, 'sin desborde (sin scroll)', JSON.stringify(overflow));

check(errors.length === 0, 'sin errores de consola/página', errors.join(' | '));
await browser.close();
server.close();
log(`TODO OK — ${passed} verificaciones`);
process.exit(0);
