import test from 'node:test';
import assert from 'node:assert/strict';
import { RemoteHost, CTX_MIN_INTERVAL_MS, HELLO_TIMEOUT_MS, defaultContext } from '../src/remote/RemoteHost';
import { FakeBridge } from '../src/remote/FakeBridge';
import { shapeStick } from '../src/remote/RemoteInputSource';
import { parseClientMsg, parseServerMsg, sanitizeName } from '../src/remote/validate';
import { PLAYER_TIMEOUT_MS, RESUME_WINDOW_MS, type ControllerContext } from '../src/remote/protocol';

function setup() {
  let t = 1000;
  let n = 0;
  const bridge = new FakeBridge();
  const host = new RemoteHost(bridge, { now: () => t, makeToken: () => `tok${++n}` });
  const events: string[] = [];
  host.onJoin((p) => events.push(`join${p.slot}:${p.name}`));
  host.onLeave((s, r) => events.push(`leave${s}:${r}`));
  host.onResume((p) => events.push(`resume${p.slot}`));
  host.onDrop((s, r) => events.push(`drop${s}:${r}`));
  return { bridge, host, events, advance: (ms: number) => { t += ms; }, get now() { return t; } };
}

const ctx = (label: string, screen: ControllerContext['screen'] = 'playing'): ControllerContext => ({
  action: { label, style: 'normal', enabled: true }, inspectEnabled: true, toolOn: false, toolEnabled: true,
  objective: 'Colocá los paneles', screen,
});

test('RemoteHost: sin puente queda inactivo y no rompe', () => {
  const host = RemoteHost.fromWindow();
  assert.equal(host.active, false);
  host.update();
  host.setContext(0, ctx('x'));
  host.haptic(1, [20]);
  host.toast(0, 'hola');
  assert.deepEqual(host.players(), [null, null]);
  assert.equal(host.input(0).read().connected, false);
});

test('RemoteHost: asigna asientos 0 y 1, colores y token; el tercero recibe full', () => {
  const { bridge, host, events } = setup();
  const a = bridge.connect(); a.hello('Ana');
  const b = bridge.connect(); b.hello('Beto', undefined, 'app');
  host.update();
  const wa = a.last('welcome'), wb = b.last('welcome');
  assert.equal(wa?.slot, 0); assert.equal(wa?.color, '#F28C28'); assert.equal(wa?.token, 'tok1');
  assert.equal(wb?.slot, 1); assert.equal(wb?.colorName, 'Azul'); assert.equal(wb?.resumed, false);
  // El contexto inicial (lobby) llega enseguida del welcome.
  assert.equal(a.received[1]?.t, 'ctx');
  assert.equal(a.last('ctx')?.c.screen, 'lobby');
  const c = bridge.connect(); c.hello('Caro');
  host.update();
  assert.equal(c.last('full')?.t, 'full');
  assert.equal(c.closed, true);
  assert.equal(c.count('welcome'), 0);
  assert.deepEqual(events, ['join0:Ana', 'join1:Beto']);
  const ps = host.players();
  assert.equal(ps[0]?.name, 'Ana'); assert.equal(ps[1]?.device, 'app'); assert.equal(host.connectedCount(), 2);
});

test('RemoteHost: reconexión con token dentro de la ventana recupera el asiento', () => {
  const { bridge, host, events, advance } = setup();
  const a = bridge.connect(); a.hello('Ana');
  const b = bridge.connect(); b.hello('Beto');
  host.update();
  const token = a.last('welcome')!.token;
  a.drop();
  host.update();
  assert.equal(host.players()[0]?.connected, false);
  assert.equal(host.input(0).read().connected, false);
  // Mientras está reservado, un desconocido no puede quitarle el lugar.
  const x = bridge.connect(); x.hello('Intruso');
  host.update();
  assert.equal(x.last('full')?.t, 'full');
  for (let i = 0; i < RESUME_WINDOW_MS / 1000 - 1; i++) { advance(1000); b.ping(i); host.update(); }
  const a2 = bridge.connect(); a2.hello('Ana', token);
  host.update();
  const w = a2.last('welcome');
  assert.equal(w?.slot, 0); assert.equal(w?.token, token); assert.equal(w?.resumed, true);
  assert.equal(host.players()[0]?.connected, true);
  assert.deepEqual(events, ['join0:Ana', 'join1:Beto', 'drop0:closed', 'resume0']);
});

test('RemoteHost: fuera de la ventana el asiento se libera y el token ya no sirve', () => {
  const { bridge, host, events, advance } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  const token = a.last('welcome')!.token;
  a.drop();
  host.update();
  advance(RESUME_WINDOW_MS + 1);
  host.update();
  assert.equal(host.players()[0], null);
  assert.ok(events.includes('leave0:expired'));
  const a2 = bridge.connect(); a2.hello('Ana', token);
  host.update();
  const w = a2.last('welcome');
  assert.equal(w?.slot, 0);
  assert.notEqual(w?.token, token);
  assert.equal(w?.resumed, false);
});

test('RemoteHost: token de una conexión viva reemplaza a la vieja (tablet que se reconecta rápido)', () => {
  const { bridge, host, events } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  const a2 = bridge.connect(); a2.hello('Ana', a.last('welcome')!.token);
  host.update();
  assert.equal(a.closed, true);
  assert.equal(a2.last('welcome')?.slot, 0);
  assert.equal(host.playerCount(), 1);
  host.update(); // el cierre de la vieja no debe soltar el asiento nuevo
  assert.equal(host.players()[0]?.connected, true);
  assert.deepEqual(events, ['join0:Ana', 'resume0']);
});

test('RemoteHost: timeout sin mensajes marca desconectado y cierra; hello que no llega también', () => {
  const { bridge, host, events, advance } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  a.input({ x: 1, y: 0 });
  host.update();
  assert.ok(host.input(0).read().x > 0.9);
  advance(PLAYER_TIMEOUT_MS - 100);
  a.ping(1);                // cualquier mensaje válido renueva
  host.update();
  advance(PLAYER_TIMEOUT_MS - 100);
  host.update();
  assert.equal(host.players()[0]?.connected, true);
  advance(200);
  host.update();
  assert.equal(host.players()[0]?.connected, false);
  assert.equal(a.closed, true);
  const i = host.input(0).read();
  assert.equal(i.connected, false); assert.equal(i.x, 0);
  assert.ok(events.includes('drop0:timeout'));
  assert.equal(events.filter((e) => e.startsWith('drop')).length, 1);

  const mute = bridge.connect();
  host.update();
  advance(HELLO_TIMEOUT_MS + 1);
  host.update();
  assert.equal(mute.closed, true);
});

test('RemoteHost: bye libera el asiento al instante; kick avisa y libera', () => {
  const { bridge, host, events } = setup();
  const a = bridge.connect(); a.hello('Ana');
  const b = bridge.connect(); b.hello('Beto');
  host.update();
  a.bye();
  host.update();
  assert.equal(host.players()[0], null);
  host.kick(1, 'Fin de la demo');
  assert.equal(b.last('kick')?.reason, 'Fin de la demo');
  assert.equal(b.closed, true);
  assert.deepEqual(events, ['join0:Ana', 'join1:Beto', 'leave0:bye', 'leave1:kick']);
});

test('RemoteInputSource: flancos de toques sin perder pulsaciones aunque falten mensajes', () => {
  const { bridge, host } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  const src = host.input(0);
  a.tap('action');
  host.update();
  assert.equal(src.read().action, true);
  assert.equal(src.read().action, false, 'un flanco por toque');
  // Se pierden 2 mensajes y llega el tercero: 3 pulsaciones en 3 frames.
  a.tap('action', true); a.tap('action', true); a.tap('action');
  a.tap('pause');
  host.update();
  const f1 = src.read(), f2 = src.read(), f3 = src.read(), f4 = src.read();
  assert.deepEqual([f1.action, f2.action, f3.action, f4.action], [true, true, true, false]);
  assert.deepEqual([f1.pause, f2.pause], [true, false]);
  // Keepalive repetido (mismo contador) no genera flancos.
  a.input({}); a.input({});
  host.update();
  assert.equal(src.read().action, false);
  // Mensaje viejo (seq menor) se ignora.
  a.sendRaw(JSON.stringify({ t: 'input', s: { seq: 1, x: 0, y: 0, held: 0, taps: { action: 99, inspect: 0, tool: 0, pause: 0 } } }));
  host.update();
  assert.equal(src.read().action, false);
});

test('RemoteInputSource: reconexión conserva contadores; página recargada (contador menor) no inventa toques', () => {
  const { bridge, host } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  const token = a.last('welcome')!.token;
  const src = host.input(0);
  a.tap('tool'); a.tap('tool');
  host.update();
  src.read(); src.read();
  a.drop(); host.update();
  // Misma página, nueva conexión: sigue en 2 y hace 1 toque más → 1 flanco.
  const a2 = bridge.connect(); a2.hello('Ana', token);
  host.update();
  a2.continueFrom(a);
  a2.tap('tool');
  host.update();
  assert.equal(src.read().tool, true);
  assert.equal(src.read().tool, false);
  // Página recargada: contadores en 0 y 1 toque → 1 flanco.
  a2.drop(); host.update();
  const a3 = bridge.connect(); a3.hello('Ana', token);
  host.update();
  a3.input({});
  host.update();
  assert.equal(src.read().tool, false);
  a3.tap('tool');
  host.update();
  assert.equal(src.read().tool, true);
  assert.equal(src.read().tool, false);
});

test('RemoteInputSource: zona muerta, curva y RUN', () => {
  assert.deepEqual(shapeStick(0.1, 0.05, 0.15, 1.5), [0, 0]);
  const [x, y] = shapeStick(1, 0, 0.15, 1.5);
  assert.equal(x, 1); assert.equal(y, 0);
  const [hx] = shapeStick(0.575, 0, 0.15, 1.5);
  assert.ok(hx > 0.3 && hx < 0.4, `mitad del recorrido → ${hx}`);
  const [dx, dy] = shapeStick(2, 2, 0.15, 1.5);
  assert.ok(Math.abs(Math.hypot(dx, dy) - 1) < 0.01 && Math.abs(dx - dy) < 1e-9, 'satura conservando dirección');
  const { bridge, host } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  a.input({ x: 0.05, y: -0.05, held: 1 });
  host.update();
  const i = host.input(0).read();
  assert.equal(i.x, 0); assert.equal(i.y, 0); assert.equal(i.run, true);
});

test('RemoteHost: setContext solo si cambió y a lo sumo 10 por segundo', () => {
  const { bridge, host, advance } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  const base = a.count('ctx');
  advance(CTX_MIN_INTERVAL_MS);
  host.setContext(0, ctx('Tomar panel'));
  assert.equal(a.count('ctx'), base + 1);
  host.setContext(0, ctx('Tomar panel'));     // igual → nada
  host.update();
  assert.equal(a.count('ctx'), base + 1);
  // 20 cambios en 1 segundo, actualizando cada 16 ms.
  for (let f = 0; f < 60; f++) {
    host.setContext(0, ctx(`Paso ${Math.floor(f / 3)}`));
    advance(1000 / 60);
    host.update();
  }
  const sent = a.count('ctx') - base - 1;
  assert.ok(sent <= 10 && sent >= 8, `enviados ${sent}`);
  advance(CTX_MIN_INTERVAL_MS);
  host.update();
  assert.equal(a.last('ctx')?.c.action.label, 'Paso 19', 'el último estado siempre termina llegando');
  // Otro asiento no recibe nada si no tiene tablet; al unirse recibe lo último.
  host.setContext(1, ctx('Conectar cable'));
  const b = bridge.connect(); b.hello('Beto');
  host.update();
  assert.equal(b.last('ctx')?.c.action.label, 'Conectar cable');
  assert.equal(host.getContext(1).action.label, 'Conectar cable');
  assert.deepEqual(defaultContext().screen, 'lobby');
});

test('RemoteHost: ping→pong, latencia, haptic y toast saneados', () => {
  const { bridge, host } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  a.ping(1234.5, 37);
  host.update();
  assert.equal(a.last('pong')?.at, 1234.5);
  assert.equal(host.players()[0]?.latencyMs, 37);
  host.haptic(0, [40, 99999, -5]);
  assert.deepEqual(a.last('haptic')?.pattern, [40, 2000, 0]);
  host.haptic(0, []);
  assert.equal(a.count('haptic'), 1);
  host.toast(0, 'x'.repeat(200), 'good');
  assert.equal(a.last('toast')?.text.length, 80);
});

test('RemoteHost: mensajes inválidos se ignoran sin romper', () => {
  const { bridge, host } = setup();
  const a = bridge.connect();
  // Antes del hello nada cuenta.
  a.input({ x: 1 });
  a.sendRaw('{malformado');
  a.sendRaw(JSON.stringify({ t: 'hello', v: 1, name: 42 }));
  a.sendRaw('x'.repeat(5000));
  host.update();
  assert.equal(a.count('welcome'), 0);
  a.hello('  Ana\u0000\u202e la   del   fondo azul  ');
  host.update();
  assert.equal(host.players()[0]?.name, 'Ana la del fon');
  const src = host.input(0);
  a.sendRaw(JSON.stringify({ t: 'input', s: { seq: 5, x: 'a', y: 0, held: 0, taps: { action: 0, inspect: 0, tool: 0, pause: 0 } } }));
  a.sendRaw(JSON.stringify({ t: 'input', s: { seq: 6, x: NaN, y: 0, held: 0, taps: { action: 1 } } }));
  a.sendRaw(JSON.stringify({ t: 'input', s: { seq: 7, x: 0, y: 0, held: 0, taps: { action: -3, inspect: 0, tool: 0, pause: 0 } } }));
  a.sendRaw(JSON.stringify({ t: 'nada' }));
  a.sendRaw(JSON.stringify([1, 2, 3]));
  host.update();
  assert.equal(src.read().action, false);
  // Valores fuera de rango se acotan; un contador gigante no genera una ráfaga infinita.
  a.sendRaw(JSON.stringify({ t: 'input', s: { seq: 8, x: 50, y: -50, held: 0, taps: { action: 1e9, inspect: 0, tool: 0, pause: 0 } } }));
  host.update();
  const r = src.raw();
  assert.equal(r.x, 1); assert.equal(r.y, -1);
  let edges = 0;
  for (let i = 0; i < 20; i++) if (src.read().action) edges++;
  assert.equal(edges, 4);
  // Eventos del puente mal formados.
  bridge.pushEvent({ e: 'msg', id: -1, data: 'x' });
  bridge.pushEvent({ e: 'boom' });
  bridge.pushEvent(null);
  host.update();
  // Versión incompatible → kick.
  const old = bridge.connect(); old.hello('Viejo', undefined, 'app', 99);
  host.update();
  assert.match(old.last('kick')?.reason ?? '', /Versión/);
  assert.equal(host.playerCount(), 1);
});

test('RemoteHost: limita ráfagas de mensajes por conexión', () => {
  const { bridge, host } = setup();
  const a = bridge.connect(); a.hello('Ana');
  host.update();
  for (let i = 0; i < 500; i++) a.ping(i);
  host.update();
  const pongs = a.count('pong');
  assert.ok(pongs >= 100 && pongs <= 120, `pongs ${pongs}`);
});

test('validate: nombres y mensajes del tele', () => {
  assert.equal(sanitizeName('\u200bLu\tna\n'), 'Lu na');
  assert.equal(parseClientMsg(JSON.stringify({ t: 'hello', v: 1, name: 'A', token: 'bad token!' })), null);
  const m = parseServerMsg(JSON.stringify({ t: 'ctx', c: { action: { label: 'Tomar', style: 'raro' }, screen: 'otra', objective: 5 } }));
  assert.equal(m?.t, 'ctx');
  if (m?.t === 'ctx') { assert.equal(m.c.action.style, 'normal'); assert.equal(m.c.screen, 'playing'); assert.equal(m.c.objective, ''); }
  assert.equal(parseServerMsg(JSON.stringify({ t: 'welcome', slot: 3, token: 'x' })), null);
});
