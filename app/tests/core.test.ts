import test from 'node:test';
import assert from 'node:assert/strict';
import { SaveStore, type KeyValueStorage } from '../src/core/SaveStore';
import { EventBus } from '../src/core/EventBus';
import { SynthAudio } from '../src/core/Audio';

class FakeStorage implements KeyValueStorage {
  map = new Map<string, string>();
  get length() { return this.map.size; }
  key(i: number) { return Array.from(this.map.keys())[i] ?? null; }
  getItem(k: string) { return this.map.get(k) ?? null; }
  setItem(k: string, v: string) { this.map.set(k, v); }
  removeItem(k: string) { this.map.delete(k); }
}
class BrokenStorage extends FakeStorage {
  override getItem(): string | null { throw new Error('denied'); }
  override setItem(): void { throw new Error('quota'); }
}

test('SaveStore: en memoria cuando no hay localStorage (node)', () => {
  const s = new SaveStore(null);
  assert.deepEqual(s.load('x', { a: 1 }), { a: 1 });
  s.save('x', { a: 2 });
  assert.deepEqual(s.load('x', { a: 1 }), { a: 2 });
  s.clearAll();
  assert.deepEqual(s.load('x', null), null);
});

test('SaveStore: prefijo me.v1., JSON y clearAll solo borra lo propio', () => {
  const fs = new FakeStorage();
  fs.setItem('otra.app', 'x');
  const s = new SaveStore(fs);
  s.save('wallet', { balance: 5 });
  assert.equal(fs.getItem('me.v1.wallet'), '{"balance":5}');
  assert.deepEqual(new SaveStore(fs).load('wallet', null), { balance: 5 });
  s.clearAll();
  assert.equal(fs.getItem('me.v1.wallet'), null);
  assert.equal(fs.getItem('otra.app'), 'x');
});

test('SaveStore: si localStorage tira error, sigue andando en memoria; JSON corrupto → fallback', () => {
  const s = new SaveStore(new BrokenStorage());
  s.save('k', [1, 2]);
  assert.deepEqual(s.load('k', []), [1, 2]);
  const fs = new FakeStorage(); fs.setItem('me.v1.bad', '{no json');
  assert.equal(new SaveStore(fs).load('bad', 7), 7);
});

test('EventBus: suscribe, filtra por tipo, desuscribe y aísla errores', () => {
  const errors: unknown[] = [];
  const bus = new EventBus((e) => errors.push(e));
  const got: number[] = [];
  bus.on('wallet-changed', () => { throw new Error('boom'); });
  const off = bus.on('wallet-changed', (e) => got.push(e.balance));
  bus.on('toast', () => got.push(-1));
  bus.emit({ type: 'wallet-changed', balance: 3 });
  off();
  bus.emit({ type: 'wallet-changed', balance: 4 });
  assert.deepEqual(got, [3]);
  assert.equal(errors.length, 2);
});

test('SynthAudio: sin AudioContext no hace nada y recuerda el mute', () => {
  const store = new SaveStore(null);
  const a = new SynthAudio(() => null, store);
  a.unlock(); a.play('coin'); a.setWind(true); a.setWind(false);
  a.setMuted(true);
  assert.equal(new SynthAudio(() => null, store).muted(), true);
});
