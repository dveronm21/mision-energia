import test from 'node:test';
import assert from 'node:assert/strict';
import { InputModel } from '../src/controller/InputModel';
import { Connection, type ConnState, type WsLike } from '../src/controller/Connection';
import type { ServerMsg } from '../src/remote/protocol';

test('InputModel: manda al cambiar y como keepalive; contadores sobreviven a reconexiones', () => {
  const m = new InputModel(100);
  assert.equal(m.shouldSend(0), true);
  const s1 = m.take(0);
  assert.equal(s1.seq, 1);
  assert.equal(m.shouldSend(50), false);
  m.setStick(0.333, -0.5);
  assert.equal(m.shouldSend(50), true);
  assert.deepEqual(m.take(50).x, 0.33);
  m.setStick(0.331, -0.5); // mismo valor cuantizado → nada nuevo
  assert.equal(m.shouldSend(60), false);
  assert.equal(m.shouldSend(150), true, 'keepalive');
  m.tap('action'); m.tap('action');
  const s = m.take(160);
  assert.equal(s.taps.action, 2);
  m.newConnection();
  const r = m.take(170);
  assert.equal(r.seq, 1);
  assert.equal(r.taps.action, 2);
});

class FakeWs implements WsLike {
  static all: FakeWs[] = [];
  readyState = 0;
  sent: string[] = [];
  onopen: ((ev: unknown) => void) | null = null;
  onmessage: ((ev: { data: unknown }) => void) | null = null;
  onclose: ((ev: unknown) => void) | null = null;
  onerror: ((ev: unknown) => void) | null = null;
  constructor() { FakeWs.all.push(this); }
  open(): void { this.readyState = 1; this.onopen?.({}); }
  recv(m: ServerMsg): void { this.onmessage?.({ data: JSON.stringify(m) }); }
  send(d: string): void { this.sent.push(d); }
  close(): void { if (this.readyState === 3) return; this.readyState = 3; this.onclose?.({}); }
  hello(): { token?: string; name: string } { return JSON.parse(this.sent[0]) as { token?: string; name: string }; }
}

const stateOf = (c: Connection): string => c.current.k;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

test('Connection: hello con token, reconexión automática con el mismo token y estado full', async () => {
  FakeWs.all = [];
  const states: ConnState['k'][] = [];
  let saved = '';
  const c = new Connection({
    url: 'ws://tv/ws', name: 'Ana', device: 'browser', token: null,
    onToken: (t) => { saved = t; }, onMessage: () => {}, onState: (s) => states.push(s.k),
    wsFactory: () => new FakeWs(),
  });
  c.start();
  const w1 = FakeWs.all[0];
  w1.open();
  assert.equal(w1.hello().name, 'Ana');
  assert.equal(w1.hello().token, undefined);
  w1.recv({ t: 'welcome', v: 1, slot: 0, token: 'abc', color: '#F28C28', colorName: 'Naranja', tvName: 'Tele' });
  assert.equal(c.isOpen, true);
  assert.equal(saved, 'abc');
  assert.ok(c.sendInput({ seq: 1, x: 0, y: 0, held: 0, taps: { action: 0, inspect: 0, tool: 0, pause: 0 } }));
  w1.close();
  assert.equal(stateOf(c), 'retrying');
  await sleep(400);
  const w2 = FakeWs.all[1];
  assert.ok(w2, 'reintentó solo');
  w2.open();
  assert.equal(w2.hello().token, 'abc', 'mismo token → mismo asiento');
  // Tele lleno: muestra full y vuelve a probar más tarde (no en bucle rápido).
  w2.recv({ t: 'full', reason: 'Ya hay 2' });
  w2.close();
  assert.equal(stateOf(c), 'full');
  await sleep(300);
  assert.equal(FakeWs.all.length, 2);
  c.stop();
  assert.equal(stateOf(c), 'idle');
  assert.ok(states.includes('connecting') && states.includes('open') && states.includes('retrying'));
});

test('Connection: kick no reconecta y olvida el token', () => {
  FakeWs.all = [];
  const c = new Connection({
    url: 'ws://tv/ws', name: 'Ana', device: 'app', token: 'old',
    onToken: () => {}, onMessage: () => {}, onState: () => {}, wsFactory: () => new FakeWs(),
  });
  c.start();
  const w = FakeWs.all[0];
  w.open();
  assert.equal(w.hello().token, 'old');
  w.recv({ t: 'kick', reason: 'Fin' });
  w.close();
  assert.equal(stateOf(c), 'kicked');
  c.stop();
});
