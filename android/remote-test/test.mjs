// Pruebas de integración del núcleo de red Java (RemoteServer) contra clientes reales:
// Node `ws`, sockets crudos, UDP (dgram) y Chromium (Playwright).
// Uso: node test.mjs <classesDir>     (lo llama run-tests.sh)
import { spawn, execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import dgram from 'node:dgram';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import WebSocket from 'ws';

const here = path.dirname(fileURLToPath(import.meta.url));
const classes = process.argv[2] || path.join(here, 'build/classes');
const HTTP = 18765, UDP = 18766;
const BASE = `http://127.0.0.1:${HTTP}`;
const WSURL = `ws://127.0.0.1:${HTTP}/ws`;
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

/* ---------- servidor Java ---------- */
const server = spawn('java', ['-cp', classes, 'ar.com.inkfusion.misionenergia.remote.test.TestServerMain',
  path.join(here, 'www'), String(HTTP), String(UDP)], { stdio: ['pipe', 'pipe', 'inherit'],
  env: { ...process.env, JAVA_TOOL_OPTIONS: '' } });
let out = '';
const serverEvents = [];
server.stdout.on('data', (d) => {
  out += d.toString();
  let i;
  while ((i = out.indexOf('\n')) >= 0) {
    const line = out.slice(0, i); out = out.slice(i + 1);
    serverEvents.push(line);
  }
});
await withTimeout((async () => { while (!serverEvents.some((l) => l.startsWith('READY'))) await sleep(20); })(), 10000, 'arranque');
console.log(serverEvents.find((l) => l.startsWith('READY')));

/* ---------- helpers ---------- */
function open(opts) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(WSURL, opts);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
    ws.once('unexpected-response', (_req, res) => reject(new Error('HTTP ' + res.statusCode)));
  });
}
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
  const head = [ (fin ? 0x80 : 0) | opcode ];
  if (len < 126) head.push((mask ? 0x80 : 0) | len);
  else if (len < 65536) head.push((mask ? 0x80 : 0) | 126, len >> 8, len & 255);
  else { head.push((mask ? 0x80 : 0) | 127, 0, 0, 0, 0, (len >>> 24) & 255, (len >>> 16) & 255, (len >>> 8) & 255, len & 255); }
  if (!mask) return Buffer.concat([Buffer.from(head), p]);
  const key = Buffer.from([1, 2, 3, 4]);
  const m = Buffer.from(p.map((b, i) => b ^ key[i & 3]));
  return Buffer.concat([Buffer.from(head), key, m]);
}
const UPGRADE = (extra = '') => 'GET /ws HTTP/1.1\r\nHost: 127.0.0.1:' + HTTP + '\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
  + 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n' + extra + '\r\n';

/* ---------- HTTP ---------- */
await test('HTTP GET / sirve index.html con no-store', async () => {
  const r = await fetch(BASE + '/');
  const body = await r.text();
  assert(r.status === 200, 'status ' + r.status);
  assert(r.headers.get('content-type') === 'text/html; charset=utf-8', r.headers.get('content-type'));
  assert(r.headers.get('cache-control') === 'no-store', 'cache-control');
  assert(body.includes('Prueba de WebSocket'), 'contenido');
});
await test('HTTP MIME de js/css y 404', async () => {
  const js = await fetch(BASE + '/sub/test.js');
  const css = await fetch(BASE + '/sub/style.css');
  const nf = await fetch(BASE + '/nada.png');
  assert(js.headers.get('content-type').startsWith('text/javascript'), 'js');
  assert(css.headers.get('content-type').startsWith('text/css'), 'css');
  assert(nf.status === 404, '404 ' + nf.status);
});
await test('HTTP sin path traversal (raw ../ y %2e%2e)', async () => {
  for (const p of ['/../TestServerMain.java', '/sub/../../package.json', '/%2e%2e/package.json', '/..%2fpackage.json', '/.hidden']) {
    const r = (await raw(`GET ${p} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n`)).toString();
    assert(/^HTTP\/1\.1 (400|404)/.test(r), p + ' → ' + r.split('\r\n')[0]);
  }
  return '5 rutas rechazadas';
});
await test('HTTP POST → 405, cabecera enorme → 431', async () => {
  const a = (await raw('POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n')).toString();
  assert(a.startsWith('HTTP/1.1 405'), a.split('\r\n')[0]);
  const b = (await raw('GET / HTTP/1.1\r\nX: ' + 'a'.repeat(10000) + '\r\n\r\n')).toString();
  assert(b.startsWith('HTTP/1.1 431'), b.split('\r\n')[0]);
});
await test('HTTP /api/info devuelve DiscoveryReply', async () => {
  const j = await (await fetch(BASE + '/api/info')).json();
  assert(j.app === 'mision-energia-tv' && j.port === HTTP && j.max === 2 && j.ip === '127.0.0.1', JSON.stringify(j));
  return JSON.stringify(j);
});

/* ---------- WebSocket ---------- */
await test('WS handshake (101 + Accept del RFC) y evento open', async () => {
  const r = (await raw(UPGRADE(), { readMs: 300 })).toString();
  assert(r.startsWith('HTTP/1.1 101'), r.split('\r\n')[0]);
  assert(r.includes('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo='), 'accept');
  const ws = await open();
  await sleep(50);
  assert(serverEvents.some((l) => /^EVT open \d+ 127\.0\.0\.1$/.test(l)), 'sin EVT open');
  ws.close(); await closed(ws);
});
await test('WS handshake inválido: versión 8 → 426, clave mala → 400, Origin ajeno → 403', async () => {
  const v = (await raw(UPGRADE().replace('Version: 13', 'Version: 8'))).toString();
  assert(v.startsWith('HTTP/1.1 426') && v.includes('Sec-WebSocket-Version: 13'), v.split('\r\n')[0]);
  const k = (await raw(UPGRADE().replace('dGhlIHNhbXBsZSBub25jZQ==', 'corta'))).toString();
  assert(k.startsWith('HTTP/1.1 400'), k.split('\r\n')[0]);
  let err = '';
  try { await open({ origin: 'http://evil.example' }); } catch (e) { err = e.message; }
  assert(err === 'HTTP 403', 'origin ajeno: ' + err);
  const same = await open({ origin: `http://127.0.0.1:${HTTP}` });
  same.close(); await closed(same);
});
await test('WS eco y orden de 1000 mensajes', async () => {
  const ws = await open();
  const got = [];
  const done = new Promise((r) => ws.on('message', (d) => { got.push(JSON.parse(d.toString()).i); if (got.length === 1000) r(); }));
  for (let i = 0; i < 1000; i++) ws.send(JSON.stringify({ t: 'input', i, s: { seq: i, x: 0.5, y: -0.25, held: 0 } }));
  await withTimeout(done, 10000, 'eco');
  for (let i = 0; i < 1000; i++) assert(got[i] === i, 'desorden en ' + i);
  ws.close(); await closed(ws);
  return '1000/1000 en orden';
});
await test('WS 2 clientes simultáneos sin mezclar mensajes', async () => {
  const [a, b] = await Promise.all([open(), open()]);
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
  const ws = await open();
  const p = new Promise((r) => ws.once('message', (d) => r(d.toString())));
  ws.send('{"t":"ping",', { fin: false });
  ws.send('"at":123,', { fin: false });
  ws.send('"x":"ñandú"}', { fin: true });
  const m = await withTimeout(p, 3000, 'fragmentado');
  assert(m === '{"t":"ping","at":123,"x":"ñandú"}', m);
  ws.close(); await closed(ws);
});
await test('WS ping de control → pong', async () => {
  const ws = await open();
  const p = new Promise((r) => ws.once('pong', (d) => r(d.toString())));
  ws.ping('hola');
  assert((await withTimeout(p, 2000, 'pong')) === 'hola', 'payload pong');
  ws.close(); await closed(ws);
});
await test('WS mensaje de 63 KB aceptado; 70 KB rechazado con 1009', async () => {
  const ws = await open();
  const ok = new Promise((r) => ws.once('message', (d) => r(d.length)));
  ws.send('x'.repeat(63 * 1024));
  assert((await withTimeout(ok, 3000, '63KB')) === 63 * 1024, 'eco 63KB');
  const c = closed(ws);
  ws.send('y'.repeat(70 * 1024));
  const { code } = await withTimeout(c, 4000, 'cierre 1009');
  assert(code === 1009, 'código ' + code);
  return 'close ' + code;
});
await test('WS frame sin máscara → 1002; binario → 1003; UTF-8 inválido → 1007', async () => {
  const codes = [];
  for (const frame of [maskedFrame(1, 'hola', { mask: false }), maskedFrame(2, 'bin'), maskedFrame(1, Buffer.from([0xc3, 0x28]))]) {
    const r = await raw(Buffer.concat([Buffer.from(UPGRADE()), frame]), { readMs: 2500 });
    const i = r.indexOf('\r\n\r\n') + 4;
    const f = r.subarray(i);
    assert(f[0] === 0x88, 'no llegó close: ' + f.toString('hex'));
    codes.push((f[2] << 8) | f[3]);
  }
  assert(codes.join() === '1002,1003,1007', codes.join());
  return codes.join(', ');
});
await test('WS cierre limpio iniciado por el cliente y por el juego', async () => {
  const lastOpenId = () => Number([...serverEvents].reverse().find((l) => l.startsWith('EVT open')).split(' ')[2]);
  const ws = await open();
  await sleep(50);
  const id1 = lastOpenId();
  ws.close(1000, 'chau');
  const r1 = await withTimeout(closed(ws), 3000, 'cierre cliente');
  assert(r1.code === 1000, 'cliente: ' + r1.code);
  const ws2 = await open();
  await sleep(50);
  const id2 = lastOpenId();
  const c2 = closed(ws2);
  ws2.send('__close__');
  const r2 = await withTimeout(c2, 3000, 'cierre servidor');
  assert(r2.code === 1000 && r2.reason === 'cerrado por el juego', JSON.stringify(r2));
  await sleep(100);
  for (const id of [id1, id2]) {
    const n = serverEvents.filter((l) => l === 'EVT close ' + id).length;
    assert(n === 1, `conexión ${id}: ${n} eventos close`);
  }
  return 'cliente 1000, juego 1000 "' + r2.reason + '"';
});
await test('WS latencia ida y vuelta local (1000 pings secuenciales)', async () => {
  const ws = await open();
  const rtts = [];
  for (let i = 0; i < 1000; i++) {
    const t = process.hrtime.bigint();
    const p = new Promise((r) => ws.once('message', r));
    ws.send(JSON.stringify({ t: 'ping', at: i }));
    await p;
    rtts.push(Number(process.hrtime.bigint() - t) / 1e6);
  }
  ws.close(); await closed(ws);
  rtts.sort((a, b) => a - b);
  const q = (f) => rtts[Math.floor(rtts.length * f)].toFixed(3);
  globalThis.latency = { median: q(0.5), p95: q(0.95), p99: q(0.99), max: rtts[rtts.length - 1].toFixed(3) };
  return `mediana ${q(0.5)} ms, p95 ${q(0.95)} ms, p99 ${q(0.99)} ms, máx ${globalThis.latency.max} ms (el "juego" de prueba sondea poll() cada 0,2 ms)`;
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
await test('UDP consulta ajena se ignora', async () => {
  const r = await udpQuery('127.0.0.1', 'HOLA');
  assert(r.length === 0, JSON.stringify(r));
});
await test('DiscoveryClient Java (código de la app Control): scan, probe UDP y probe HTTP', async () => {
  const o = execFileSync('java', ['-cp', classes, 'ar.com.inkfusion.misionenergia.remote.test.DiscoveryClientMain', String(UDP), String(HTTP)],
    { env: { ...process.env, JAVA_TOOL_OPTIONS: '' } }).toString();
  const scan = o.match(/^SCAN (.*) ms=/m)[1];
  assert(JSON.parse(scan).some((t) => t.port === HTTP), 'scan: ' + scan);
  assert(/^PROBE \{.*"port":18765/m.test(o), 'probe UDP');
  assert(/^PROBEHTTP \{.*"port":18765/m.test(o), 'probe HTTP');
  return o.trim().split('\n').map((l) => l.slice(0, 40)).join(' | ');
});

/* ---------- Navegador real ---------- */
await test('Chromium (Playwright): página servida por HTTP abre WebSocket y mide RTT', async () => {
  const require = createRequire(import.meta.url);
  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(BASE + '/');
    await page.waitForFunction(() => window.result !== null, null, { timeout: 15000 });
    const r = await page.evaluate(() => window.result);
    assert(r.ok && r.n === 200, JSON.stringify(r));
    assert(r.cssLoaded === 'rgb(14, 36, 32)', 'css no cargó: ' + r.cssLoaded);
    globalThis.browserLatency = r;
    return `200 pings: mediana ${r.median.toFixed(3)} ms, p95 ${r.p95.toFixed(3)} ms, máx ${r.max.toFixed(3)} ms`;
  } finally { await browser.close(); }
});

/* ---------- Apagado ---------- */
await test('Apagado limpio: clientes reciben 1001, sin hilos colgados', async () => {
  const ws = await open();
  const c = closed(ws);
  await sleep(50);
  server.stdin.write('quit\n');
  const r = await withTimeout(c, 5000, 'close al apagar');
  assert(r.code === 1001, 'código ' + r.code);
  const code = await withTimeout(new Promise((res) => server.once('exit', res)), 8000, 'salida java');
  const line = serverEvents.find((l) => l.startsWith('STOPPED'));
  const fin = serverEvents.find((l) => l.startsWith('FINAL'));
  assert(code === 0 && /leakedThreads=0/.test(line), line);
  assert(/"e":"close"/.test(fin), 'poll() tras stop sin evento close: ' + fin);
  return line;
});

console.log(`\n${results.length - failed}/${results.length} pruebas OK`);
if (globalThis.latency) console.log('LATENCIA Node ws:', JSON.stringify(globalThis.latency));
if (globalThis.browserLatency) console.log('LATENCIA Chromium:', JSON.stringify(globalThis.browserLatency));
if (server.exitCode === null) server.kill();
process.exit(failed ? 1 : 0);
