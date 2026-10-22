// Integración del servidor remoto GDScript: Godot headless (RemoteServer + RemoteHost, escena
// res://scenes/remote/RemoteTestServer.tscn) contra clientes reales: Node `ws`, sockets crudos,
// UDP (dgram) y Chromium (Playwright) con la página de control real (res://controller/).
// Adaptado de android/remote-test/test.mjs (servidor Java de referencia).
//
// Uso: ./run.sh   (o: NODE_PATH=$(npm root -g) PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node test.mjs)
// Variables: GODOT (binario, por defecto "godot"), FPS (tope de frames del tele, por defecto 60),
//            SHOTS (carpeta para capturas de las tablets).
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import dgram from 'node:dgram';
import net from 'node:net';
import path from 'node:path';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import WebSocket from 'ws';

const here = path.dirname(fileURLToPath(import.meta.url));
const PROJECT = path.resolve(here, '../..');
const HTTP = 18765, UDP = 18766;
const FPS = process.env.FPS || '60';
const BASE = `http://127.0.0.1:${HTTP}`;
const WSURL = `ws://127.0.0.1:${HTTP}/ws`;
const SHOTS = process.env.SHOTS || path.join(here, 'out');
mkdirSync(SHOTS, { recursive: true });
const results = [];
let failed = 0;

function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  if (!ok) failed++;
  console.log(`${ok ? 'OK   ' : 'FALLA'} ${name}${detail ? ' — ' + detail : ''}`);
}
async function test(name, fn) {
  try { const d = await fn(); record(name, true, d || ''); }
  catch (e) { record(name, false, e && e.message ? e.message : String(e)); }
}
function assert(c, msg) { if (!c) throw new Error(msg); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
function withTimeout(p, ms, what) {
  return Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error('timeout: ' + what)), ms))]);
}
async function until(fn, what, timeout = 8000) {
  const end = Date.now() + timeout;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error('timeout esperando: ' + what);
    await sleep(40);
  }
}

/* ---------- Godot headless ---------- */
const server = spawn(process.env.GODOT || 'godot', ['--headless', '--path', PROJECT, 'res://scenes/remote/RemoteTestServer.tscn',
  '--', '--http', String(HTTP), '--udp', String(UDP), '--bind', '127.0.0.1', '--fps', FPS],
  { stdio: ['ignore', 'pipe', 'pipe'] });
let out = '';
const serverEvents = [];
const stderrLines = [];
server.stdout.on('data', (d) => {
  out += d.toString();
  let i;
  while ((i = out.indexOf('\n')) >= 0) { serverEvents.push(out.slice(0, i)); out = out.slice(i + 1); }
});
server.stderr.on('data', (d) => stderrLines.push(...d.toString().split('\n').filter(Boolean)));
await withTimeout((async () => { while (!serverEvents.some((l) => l.startsWith('READY'))) await sleep(20); })(), 20000, 'arranque de Godot');
console.log(serverEvents.find((l) => l.startsWith('READY')), `(tope ${FPS} fps)`);

/* ---------- helpers ---------- */
function open(opts, first) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(WSURL, opts);
    ws.once('open', () => { if (first) ws.send(first); resolve(ws); });
    ws.once('error', reject);
    ws.once('unexpected-response', (_req, res) => reject(new Error('HTTP ' + res.statusCode)));
  });
}
const openEcho = (opts) => open(opts, '__echo__');
function closed(ws) { return new Promise((r) => ws.once('close', (code, reason) => r({ code, reason: reason.toString() }))); }
function raw(request, { readMs = 1500 } = {}) {
  return new Promise((resolve) => {
    const s = net.connect(HTTP, '127.0.0.1');
    const chunks = [];
    s.on('data', (d) => chunks.push(d));
    s.on('error', () => {});
    s.on('close', () => resolve(Buffer.concat(chunks)));
    s.write(request);
    setTimeout(() => s.destroy(), readMs);
  });
}
function maskedFrame(opcode, payload, { fin = true, mask = true } = {}) {
  const p = Buffer.from(payload);
  const len = p.length;
  const head = [(fin ? 0x80 : 0) | opcode];
  if (len < 126) head.push((mask ? 0x80 : 0) | len);
  else if (len < 65536) head.push((mask ? 0x80 : 0) | 126, len >> 8, len & 255);
  else head.push((mask ? 0x80 : 0) | 127, 0, 0, 0, 0, (len >>> 24) & 255, (len >>> 16) & 255, (len >>> 8) & 255, len & 255);
  if (!mask) return Buffer.concat([Buffer.from(head), p]);
  const key = Buffer.from([1, 2, 3, 4]);
  return Buffer.concat([Buffer.from(head), key, Buffer.from(p.map((b, i) => b ^ key[i & 3]))]);
}
const UPGRADE = (extra = '') => 'GET /ws HTTP/1.1\r\nHost: 127.0.0.1:' + HTTP + '\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
  + 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n' + extra + '\r\n';

let admin = null;
const adminQueue = [];
async function adminCmd(cmd) {
  if (!admin) {
    admin = await open(undefined, '__admin__');
    admin.on('message', (d) => { const r = adminQueue.shift(); if (r) r(d.toString()); });
  }
  return new Promise((resolve) => { adminQueue.push(resolve); admin.send(cmd); });
}
const tvState = async () => JSON.parse(await adminCmd('state'));
const quantiles = (arr) => {
  const a = [...arr].sort((x, y) => x - y);
  const q = (f) => a[Math.min(a.length - 1, Math.floor(a.length * f))];
  return { median: q(0.5), p95: q(0.95), p99: q(0.99), max: a[a.length - 1] };
};
const fmt = (l) => `mediana ${l.median.toFixed(2)} ms, p95 ${l.p95.toFixed(2)} ms, p99 ${l.p99.toFixed(2)} ms, máx ${l.max.toFixed(2)} ms`;

/* ---------- HTTP ---------- */
await test('HTTP GET / sirve la página de control (res://controller/index.html) con no-store', async () => {
  const r = await fetch(BASE + '/');
  const body = await r.text();
  assert(r.status === 200, 'status ' + r.status);
  assert(r.headers.get('content-type') === 'text/html; charset=utf-8', r.headers.get('content-type'));
  assert(r.headers.get('cache-control') === 'no-store', 'cache-control');
  assert(r.headers.get('x-content-type-options') === 'nosniff', 'nosniff');
  assert(body.includes('Misión Energía · Control') && body.includes('controller.js'), 'contenido');
});
await test('HTTP MIME de js/woff2, HEAD y 404', async () => {
  const js = await fetch(BASE + '/controller.js');
  const font = await fetch(BASE + '/fonts/fredoka-latin-700-normal.woff2');
  const head = await fetch(BASE + '/controller.js', { method: 'HEAD' });
  const nf = await fetch(BASE + '/nada.png');
  assert(js.headers.get('content-type').startsWith('text/javascript'), 'js');
  const buf = Buffer.from(await font.arrayBuffer());
  assert(font.headers.get('content-type') === 'font/woff2' && buf.subarray(0, 4).toString() === 'wOF2', 'woff2');
  assert(head.status === 200 && Number(head.headers.get('content-length')) === (await js.text()).length, 'HEAD');
  assert(nf.status === 404, '404 ' + nf.status);
  return `controller.js ${head.headers.get('content-length')} B, fuente ${buf.length} B`;
});
await test('HTTP keep-alive: 3 peticiones en el mismo socket', async () => {
  const r = (await raw('GET /api/info HTTP/1.1\r\nHost: x\r\n\r\nGET /index.html HTTP/1.1\r\nHost: x\r\n\r\nGET /nada HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n')).toString();
  const st = [...r.matchAll(/HTTP\/1\.1 (\d{3}) /g)].map((m) => m[1]);
  assert(st.join() === '200,200,404', st.join());
});
await test('HTTP sin path traversal (raw ../ y %2e%2e)', async () => {
  for (const p of ['/../project.godot', '/fonts/../../project.godot', '/%2e%2e/project.godot', '/..%2fproject.godot', '/.hidden', '/fonts/..%5c..%5cproject.godot', '//etc/passwd']) {
    const r = (await raw(`GET ${p} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n`)).toString();
    assert(/^HTTP\/1\.1 (400|404)/.test(r), p + ' → ' + r.split('\r\n')[0]);
    assert(!r.includes('config_version'), p + ' filtró project.godot');
  }
  return '7 rutas rechazadas';
});
await test('HTTP POST → 405, cabecera enorme → 431', async () => {
  const a = (await raw('POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n')).toString();
  assert(a.startsWith('HTTP/1.1 405'), a.split('\r\n')[0]);
  const b = (await raw('GET / HTTP/1.1\r\nX: ' + 'a'.repeat(10000) + '\r\n\r\n')).toString();
  assert(b.startsWith('HTTP/1.1 431'), b.split('\r\n')[0]);
});
await test('HTTP /api/info devuelve DiscoveryReply con CORS', async () => {
  const r = await fetch(BASE + '/api/info');
  const j = await r.json();
  assert(r.headers.get('access-control-allow-origin') === '*', 'CORS');
  assert(j.app === 'mision-energia-tv' && j.port === HTTP && j.max === 2 && j.ip === '127.0.0.1' && j.v === 1, JSON.stringify(j));
  return JSON.stringify(j);
});

/* ---------- WebSocket ---------- */
await test('WS handshake (101 + Accept del RFC) y evento open', async () => {
  const r = (await raw(UPGRADE(), { readMs: 300 })).toString();
  assert(r.startsWith('HTTP/1.1 101'), r.split('\r\n')[0]);
  assert(r.includes('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo='), 'accept');
  const ws = await openEcho();
  await sleep(100);
  assert(serverEvents.some((l) => /^EVT open \d+ 127\.0\.0\.1$/.test(l)), 'sin EVT open');
  ws.close(); await closed(ws);
});
await test('WS frames pegados al handshake (mismo paquete TCP) no se pierden', async () => {
  const r = await raw(Buffer.concat([Buffer.from(UPGRADE()), maskedFrame(1, '__echo__'), maskedFrame(1, 'pegado')]), { readMs: 600 });
  const i = r.indexOf('\r\n\r\n') + 4;
  const f = r.subarray(i);
  assert(f[0] === 0x81 && f.subarray(2, 2 + f[1]).toString() === 'pegado', 'eco: ' + f.toString('hex'));
});
await test('WS handshake inválido: versión 8 → 426, clave mala → 400, Origin ajeno → 403', async () => {
  const v = (await raw(UPGRADE().replace('Version: 13', 'Version: 8'))).toString();
  assert(v.startsWith('HTTP/1.1 426') && v.includes('Sec-WebSocket-Version: 13'), v.split('\r\n')[0]);
  const k = (await raw(UPGRADE().replace('dGhlIHNhbXBsZSBub25jZQ==', 'corta'))).toString();
  assert(k.startsWith('HTTP/1.1 400'), k.split('\r\n')[0]);
  let err = '';
  try { await open({ origin: 'http://evil.example' }); } catch (e) { err = e.message; }
  assert(err === 'HTTP 403', 'origin ajeno: ' + err);
  const same = await openEcho({ origin: `http://127.0.0.1:${HTTP}` });
  same.close(); await closed(same);
});
await test('WS eco y orden de 1000 mensajes', async () => {
  const ws = await openEcho();
  const got = [];
  const done = new Promise((r) => ws.on('message', (d) => { got.push(JSON.parse(d.toString()).i); if (got.length === 1000) r(); }));
  for (let i = 0; i < 1000; i++) ws.send(JSON.stringify({ t: 'input', i, s: { seq: i, x: 0.5, y: -0.25, held: 0 } }));
  await withTimeout(done, 15000, 'eco');
  for (let i = 0; i < 1000; i++) assert(got[i] === i, 'desorden en ' + i);
  ws.close(); await closed(ws);
  return '1000/1000 en orden';
});
await test('WS 2 clientes simultáneos sin mezclar mensajes', async () => {
  const [a, b] = await Promise.all([openEcho(), openEcho()]);
  const ga = [], gb = [];
  a.on('message', (d) => ga.push(d.toString()));
  b.on('message', (d) => gb.push(d.toString()));
  for (let i = 0; i < 300; i++) { a.send('A' + i); b.send('B' + i); }
  await withTimeout((async () => { while (ga.length < 300 || gb.length < 300) await sleep(10); })(), 10000, '2 clientes');
  assert(ga.every((m, i) => m === 'A' + i) && gb.every((m, i) => m === 'B' + i), 'mezcla u orden');
  a.close(); b.close(); await Promise.all([closed(a), closed(b)]);
  return '300+300';
});
await test('WS mensaje fragmentado (3 frames) se reensambla', async () => {
  const ws = await openEcho();
  const p = new Promise((r) => ws.once('message', (d) => r(d.toString())));
  ws.send('{"t":"ping",', { fin: false });
  ws.send('"at":123,', { fin: false });
  ws.send('"x":"ñandú"}', { fin: true });
  const m = await withTimeout(p, 3000, 'fragmentado');
  assert(m === '{"t":"ping","at":123,"x":"ñandú"}', m);
  ws.close(); await closed(ws);
});
await test('WS ping de control → pong', async () => {
  const ws = await openEcho();
  const p = new Promise((r) => ws.once('pong', (d) => r(d.toString())));
  ws.ping('hola');
  assert((await withTimeout(p, 2000, 'pong')) === 'hola', 'payload pong');
  ws.close(); await closed(ws);
});
await test('WS mensaje de 63 KB aceptado; 70 KB rechazado con 1009', async () => {
  const ws = await openEcho();
  const ok = new Promise((r) => ws.once('message', (d) => r(d.length)));
  ws.send('x'.repeat(63 * 1024));
  assert((await withTimeout(ok, 5000, '63KB')) === 63 * 1024, 'eco 63KB');
  const c = closed(ws);
  ws.send('y'.repeat(70 * 1024));
  const { code } = await withTimeout(c, 4000, 'cierre 1009');
  assert(code === 1009, 'código ' + code);
  return 'close ' + code;
});
await test('WS frame sin máscara → 1002; binario → 1003; UTF-8 inválido → 1007', async () => {
  const codes = [];
  for (const frame of [maskedFrame(1, 'hola', { mask: false }), maskedFrame(2, 'bin'), maskedFrame(1, Buffer.from([0xc3, 0x28]))]) {
    const r = await raw(Buffer.concat([Buffer.from(UPGRADE()), maskedFrame(1, '__echo__'), frame]), { readMs: 2000 });
    const i = r.indexOf('\r\n\r\n') + 4;
    const f = r.subarray(i);
    assert(f[0] === 0x88, 'no llegó close: ' + f.toString('hex'));
    codes.push((f[2] << 8) | f[3]);
  }
  assert(codes.join() === '1002,1003,1007', codes.join());
  return codes.join(', ');
});
await test('WS cierre limpio iniciado por el cliente y por el juego (un close por conexión)', async () => {
  const lastOpenId = () => Number([...serverEvents].reverse().find((l) => l.startsWith('EVT open')).split(' ')[2]);
  const ws = await openEcho();
  await sleep(100);
  const id1 = lastOpenId();
  ws.close(1000, 'chau');
  const r1 = await withTimeout(closed(ws), 3000, 'cierre cliente');
  assert(r1.code === 1000, 'cliente: ' + r1.code);
  const ws2 = await openEcho();
  await sleep(100);
  const id2 = lastOpenId();
  const c2 = closed(ws2);
  ws2.send('__close__');
  const r2 = await withTimeout(c2, 3000, 'cierre servidor');
  assert(r2.code === 1000 && r2.reason === 'cerrado por el juego', JSON.stringify(r2));
  await sleep(200);
  for (const id of [id1, id2]) {
    const n = serverEvents.filter((l) => l === 'EVT close ' + id).length;
    assert(n === 1, `conexión ${id}: ${n} eventos close`);
  }
  return 'cliente 1000, juego 1000 "' + r2.reason + '"';
});
await test('Latencia ida y vuelta: eco de transporte (500 mensajes secuenciales)', async () => {
  const ws = await openEcho();
  const rtts = [];
  for (let i = 0; i < 500; i++) {
    const t = process.hrtime.bigint();
    const p = new Promise((r) => ws.once('message', r));
    ws.send(JSON.stringify({ t: 'ping', at: i }));
    await p;
    rtts.push(Number(process.hrtime.bigint() - t) / 1e6);
  }
  ws.close(); await closed(ws);
  globalThis.latencyEcho = quantiles(rtts);
  return fmt(globalThis.latencyEcho) + ` (tele a ${FPS} fps: se responde en el frame siguiente)`;
});
await test('Latencia del protocolo real: hello → welcome y ping → pong por RemoteHost', async () => {
  const ws = await open();
  const msgs = [];
  let waiter = null;
  ws.on('message', (d) => { const m = JSON.parse(d.toString()); msgs.push(m); if (waiter && m.t === waiter.t) { m.used = true; const w = waiter; waiter = null; w.r(m); } });
  const next = (t) => new Promise((r) => { const found = msgs.find((m) => m.t === t && !m.used); if (found) { found.used = true; r(found); } else waiter = { t, r }; });
  ws.send(JSON.stringify({ t: 'hello', v: 1, name: 'Nodo', device: 'app' }));
  const w = await withTimeout(next('welcome'), 3000, 'welcome');
  assert(w.slot === 0 && w.color === '#F28C28' && w.tvName === 'Tele de prueba' && w.resumed === false, JSON.stringify(w));
  const rtts = [];
  for (let i = 0; i < 100; i++) {
    const t = process.hrtime.bigint();
    const p = next('pong');
    ws.send(JSON.stringify({ t: 'ping', at: i + 0.5 }));
    const m = await withTimeout(p, 2000, 'pong');
    assert(m.at === i + 0.5, 'at ' + m.at);
    rtts.push(Number(process.hrtime.bigint() - t) / 1e6);
    await sleep(12); // ≤ ráfaga del host (60/s sostenido)
  }
  ws.send(JSON.stringify({ t: 'bye' }));
  await withTimeout(closed(ws), 3000, 'bye cierra');
  await until(() => serverEvents.includes('HOST leave 0 bye'), 'leave bye', 3000);
  globalThis.latencyProto = quantiles(rtts);
  return fmt(globalThis.latencyProto);
});

/* ---------- UDP ---------- */
function udpQuery(target, payload = 'MISION-ENERGIA-DISCOVER-1', ms = 800) {
  return new Promise((resolve) => {
    const s = dgram.createSocket('udp4');
    const replies = [];
    s.on('message', (m, rinfo) => replies.push({ m: m.toString(), from: rinfo.address }));
    s.bind(0, () => {
      s.setBroadcast(true);
      s.send(payload, UDP, target, (err) => { if (err) replies.push({ err: err.message }); });
      setTimeout(() => { s.close(); resolve(replies); }, ms);
    });
  });
}
await test('UDP descubrimiento directo a 127.0.0.1', async () => {
  const r = await udpQuery('127.0.0.1');
  assert(r.length === 1 && !r[0].err, JSON.stringify(r));
  const j = JSON.parse(r[0].m);
  assert(j.app === 'mision-energia-tv' && j.ip === '127.0.0.1' && j.port === HTTP && j.v === 1, r[0].m);
  return r[0].m;
});
await test('UDP descubrimiento por broadcast 127.255.255.255', async () => {
  const r = await udpQuery('127.255.255.255');
  assert(r.length >= 1 && !r[0].err && JSON.parse(r[0].m).port === HTTP, JSON.stringify(r));
  return 'respondió ' + r[0].from;
});
await test('UDP consulta ajena o larga se ignora', async () => {
  const a = await udpQuery('127.0.0.1', 'HOLA');
  const b = await udpQuery('127.0.0.1', 'MISION-ENERGIA-DISCOVER-1' + ' '.repeat(80));
  assert(a.length === 0 && b.length === 0, JSON.stringify([a, b]));
});

/* ---------- Navegador real: página de control servida por Godot ---------- */
await test('Playwright: 2 tablets táctiles, joystick, acción, reconexión con token y tercero "full"', async () => {
  const require = createRequire(import.meta.url);
  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  const errors = [];
  const steps = [];
  try {
    async function tablet(name, viewport) {
      const ctx = await browser.newContext({ viewport, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
      await ctx.addInitScript(() => {
        window.__vib = [];
        Object.defineProperty(Navigator.prototype, 'vibrate', { configurable: true, value(p) { window.__vib.push(p); return true; } });
      });
      const page = await ctx.newPage();
      page.on('pageerror', (e) => errors.push(`${name} pageerror: ${e.message}`));
      page.on('console', (m) => { if (m.type() === 'error' && !/WebSocket|ERR_|net::/.test(m.text())) errors.push(`${name}: ${m.text()}`); });
      await page.goto(BASE + '/');
      await page.evaluate(() => document.fonts.ready);
      return { name, page, ctx, cdp: await ctx.newCDPSession(page) };
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
      await sleep(50);
      await touch(t, 'touchEnd', []);
    }
    const step = (s) => steps.push(s);

    const A = await tablet('Ana', { width: 1280, height: 800 });
    await enter(A, 'Ana');
    await until(async () => (await screenOf(A)) === 'lobby', 'Ana en sala de espera');
    let st = await until(async () => { const s = await tvState(); return s.players[0]?.name === 'Ana' && s.players[0].connected && s; }, 'Ana en el tele');
    assert(st.players[0].color === '#F28C28' && st.players[0].device === 'browser', 'Ana lugar 1 naranja');
    const B = await tablet('Beto', { width: 1024, height: 600 });
    await enter(B, 'Beto');
    st = await until(async () => { const s = await tvState(); return s.players[1]?.name === 'Beto' && s; }, 'Beto en el tele');
    assert(st.players[1].colorName === 'Azul', 'Beto lugar 2 azul');
    step('asientos 0/1 con color');
    st = await until(async () => { const s = await tvState(); return s.players.every((p) => p && p.latencyMs !== null) && s; }, 'latencias medidas', 6000);
    globalThis.browserLatency = st.players.map((p) => p.latencyMs);
    step(`latencia informada por las tablets ${globalThis.browserLatency.join('/')} ms`);
    await A.page.screenshot({ path: path.join(SHOTS, 'tablet-lobby-1280.png') });

    await adminCmd('start');
    await until(async () => (await screenOf(A)) === 'play' && (await screenOf(B)) === 'play', 'tablets en modo juego');
    await until(async () => (await A.page.textContent('.c-act'))?.includes('Tomar panel'), 'texto de contexto');
    step('ctx: pantalla de juego y "Tomar panel"');

    // Joystick flotante + acción a la vez (multitouch).
    const z = await A.page.locator('.c-zone').boundingBox();
    const sx = Math.round(z.x + z.width * 0.4), sy = Math.round(z.y + z.height * 0.6);
    await touch(A, 'touchStart', [{ x: sx, y: sy, id: 0 }]);
    for (let i = 1; i <= 6; i++) { await touch(A, 'touchMove', [{ x: sx + i * 18, y: sy - i * 6, id: 0 }]); await sleep(30); }
    st = await until(async () => { const s = await tvState(); return s.stats.maxX[0] > 0.5 && s; }, 'joystick en el tele');
    assert(st.stats.minY[0] < 0, 'y negativa');
    const act = await center(A, '.c-act');
    await touch(A, 'touchStart', [{ x: sx + 108, y: sy - 36, id: 0 }, { x: act.x, y: act.y, id: 1 }]);
    await sleep(80);
    await A.page.screenshot({ path: path.join(SHOTS, 'tablet-play-1280.png') });
    await touch(A, 'touchMove', [{ x: sx + 110, y: sy - 36, id: 0 }]);
    st = await until(async () => { const s = await tvState(); return s.stats.actions[0] === 1 && s; }, 'acción recibida');
    assert(st.stats.last[0].x > 0.3 && st.stats.last[0].connected, 'joystick activo mientras se aprieta acción');
    await until(async () => (await A.page.evaluate(() => window.__vib)).some((p) => JSON.stringify(p) === '[30,40,30]'), 'vibración');
    await touch(A, 'touchEnd', []);
    await until(async () => (await tvState()).stats.last[0].x === 0, 'joystick suelto vuelve a 0');
    step(`joystick x=${st.stats.maxX[0]} y=${st.stats.minY[0]}, acción 1, haptic [30,40,30]`);

    await tapTouch(B, '.c-col .c-round:nth-child(2)');
    await tapTouch(B, '.c-col .c-round:nth-child(1)');
    st = await until(async () => { const s = await tvState(); return s.stats.inspects[1] === 1 && s.stats.tools[1] === 1 && s; }, 'Revisar y Multímetro en asiento 1');
    step('Beto (asiento 1): revisar + multímetro');

    // Corte de red de Ana: el tele la marca desconectada, guarda el lugar; la página reconecta sola con su token.
    await adminCmd('drop Ana');
    st = await until(async () => { const s = await tvState(); return s.players[0] && !s.players[0].connected && s; }, 'Ana desconectada');
    assert(st.players[0].reservedUntil !== null, 'asiento reservado');
    st = await until(async () => { const s = await tvState(); return s.players[0]?.connected && s.stats.resumes >= 1 && s; }, 'Ana reconectada', 12000);
    assert(st.players[0].name === 'Ana' && serverEvents.includes('HOST resume 0 Ana'), 'mismo asiento con el mismo token');
    await until(async () => (await screenOf(A)) === 'play', 'Ana vuelve al juego');
    await tapTouch(A, '.c-act');
    st = await until(async () => { const s = await tvState(); return s.stats.actions[0] === 2 && s; }, 'acción tras reconectar');
    step('reconexión: resume asiento 0 con el mismo token, toques sin duplicar');

    const C = await tablet('Caro', { width: 1024, height: 600 });
    await enter(C, 'Caro');
    await until(async () => (await screenOf(C)) === 'full', 'Caro ve "tele lleno"');
    st = await tvState();
    assert(st.players.filter(Boolean).length === 2 && !st.players.some((p) => p?.name === 'Caro'), 'tercero rechazado');
    await C.page.screenshot({ path: path.join(SHOTS, 'tablet-full-1024.png') });
    step('tercer cliente: full');
    assert(errors.length === 0, 'errores de página: ' + errors.join(' | '));
    await adminCmd('lobby');
    return steps.join('; ');
  } finally { await browser.close(); }
});

/* ---------- Apagado ---------- */
await test('Apagado limpio: clientes reciben 1001 y poll() entrega los close', async () => {
  const ws = await openEcho();
  const c = closed(ws);
  await sleep(100);
  admin.send('quit');
  const r = await withTimeout(c, 5000, 'close al apagar');
  assert(r.code === 1001, 'código ' + r.code);
  const code = await withTimeout(new Promise((res) => server.once('exit', res)), 8000, 'salida de Godot');
  const line = serverEvents.find((l) => l.startsWith('STOPPED'));
  const fin = serverEvents.find((l) => l.startsWith('FINAL'));
  assert(code === 0 && /conns=0 running=false/.test(line), line);
  assert(/"e":"close"/.test(fin), 'poll() tras stop sin close: ' + fin);
  return line;
});

const godotErrors = stderrLines.filter((l) => /ERROR|SCRIPT ERROR/.test(l));
await test('Godot sin errores en stderr', async () => { assert(godotErrors.length === 0, godotErrors.slice(0, 6).join(' | ')); });

console.log(`\n${results.length - failed}/${results.length} pruebas OK`);
if (globalThis.latencyEcho) console.log('LATENCIA eco (Node ws):', fmt(globalThis.latencyEcho));
if (globalThis.latencyProto) console.log('LATENCIA protocolo (ping→pong por RemoteHost):', fmt(globalThis.latencyProto));
if (globalThis.browserLatency) console.log('LATENCIA Chromium (informada por la página, ms):', globalThis.browserLatency.join(', '));
if (server.exitCode === null) server.kill();
process.exit(failed ? 1 : 0);
