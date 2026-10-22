import {
  PROTOCOL_VERSION,
  type BridgeEvent, type ClientMsg, type InputState, type NativeRemoteBridge, type ServerMsg, type TapCounters,
} from './protocol';

/**
 * Puente en memoria que imita a `window.RemoteBridge` (app Java del tele).
 * Sirve para tests y para probar el modo TV en un navegador común sin tablets reales.
 *
 *   const bridge = new FakeBridge();
 *   const host = new RemoteHost(bridge);
 *   const ana = bridge.connect();      // abre un "WebSocket"
 *   ana.hello('Ana');
 *   host.update();                      // el host procesa
 *   ana.last('welcome')?.slot           // → 0
 */
export class FakeBridge implements NativeRemoteBridge {
  private queue: BridgeEvent[] = [];
  private nextId = 1;
  readonly clients = new Map<number, FakeClient>();

  constructor(private readonly url = 'http://192.168.0.23:8765/', private readonly tvName = 'Tele del living') {}

  getControllerUrl(): string { return this.url; }
  getTvName(): string { return this.tvName; }

  poll(): string {
    const out = JSON.stringify(this.queue);
    this.queue = [];
    return out;
  }

  send(connId: number, json: string): void {
    const c = this.clients.get(connId);
    if (!c || c.closed) return;
    c.receive(JSON.parse(json) as ServerMsg);
  }

  close(connId: number, reason: string): void {
    const c = this.clients.get(connId);
    if (!c || c.closed) return;
    c.closed = true;
    c.closeReason = reason;
    // Igual que el servidor real: el cierre también se informa como evento.
    this.queue.push({ e: 'close', id: connId });
  }

  /** Abre una conexión nueva (como si una tablet abriera el WebSocket). */
  connect(addr = '192.168.0.50'): FakeClient {
    const id = this.nextId++;
    const c = new FakeClient(this, id);
    this.clients.set(id, c);
    this.queue.push({ e: 'open', id, addr });
    return c;
  }

  /** Inyecta un evento crudo (para probar entradas inválidas). */
  pushEvent(ev: unknown): void { this.queue.push(ev as BridgeEvent); }

  /** Uso interno de FakeClient. */
  enqueueMsg(id: number, data: string): void { this.queue.push({ e: 'msg', id, data }); }
  enqueueClose(id: number): void { this.queue.push({ e: 'close', id }); }
}

export type TapName = keyof TapCounters;

/** Una tablet simulada. Lleva su propio `seq` y contadores de toques, como la página real. */
export class FakeClient {
  readonly received: ServerMsg[] = [];
  closed = false;
  closeReason = '';
  private seq = 0;
  private readonly state: InputState = { seq: 0, x: 0, y: 0, held: 0, taps: { action: 0, inspect: 0, tool: 0, pause: 0 } };
  onMessage?: (m: ServerMsg) => void;

  constructor(private readonly bridge: FakeBridge, readonly id: number) {}

  receive(m: ServerMsg): void { this.received.push(m); this.onMessage?.(m); }

  send(msg: ClientMsg): void { this.sendRaw(JSON.stringify(msg)); }
  sendRaw(data: string): void { if (!this.closed) this.bridge.enqueueMsg(this.id, data); }

  hello(name: string, token?: string, device: 'browser' | 'app' = 'browser', v = PROTOCOL_VERSION): void {
    this.send({ t: 'hello', v, name, token, device });
  }

  /** Cambia el joystick/botones mantenidos y manda el estado (o no, si `lost`). */
  input(p: { x?: number; y?: number; held?: number } = {}, lost = false): void {
    if (p.x !== undefined) this.state.x = p.x;
    if (p.y !== undefined) this.state.y = p.y;
    if (p.held !== undefined) this.state.held = p.held;
    this.flush(lost);
  }

  /** Toque de un botón. Con `lost` el mensaje "se pierde" pero el contador avanza igual. */
  tap(name: TapName, lost = false): void {
    this.state.taps[name]++;
    this.flush(lost);
  }

  /** Reinicia los contadores (como si la página se recargara). */
  resetCounters(): void {
    this.seq = 0;
    this.state.taps = { action: 0, inspect: 0, tool: 0, pause: 0 };
  }

  /** Misma página que reconecta: sigue con los contadores de otra conexión (seq vuelve a 0). */
  continueFrom(other: FakeClient): void { this.state.taps = { ...other.state.taps }; }

  ping(at: number, rtt?: number): void { this.send({ t: 'ping', at, rtt }); }
  bye(): void { this.send({ t: 'bye' }); }

  /** Corte de red: el servidor detecta el cierre del socket. */
  drop(): void {
    if (this.closed) return;
    this.closed = true;
    this.closeReason = 'network';
    this.bridge.enqueueClose(this.id);
  }

  last<T extends ServerMsg['t']>(t: T): Extract<ServerMsg, { t: T }> | undefined {
    for (let i = this.received.length - 1; i >= 0; i--) {
      const m = this.received[i];
      if (m.t === t) return m as Extract<ServerMsg, { t: T }>;
    }
    return undefined;
  }

  count(t: ServerMsg['t']): number { return this.received.filter((m) => m.t === t).length; }

  private flush(lost: boolean): void {
    this.state.seq = ++this.seq;
    if (!lost) this.send({ t: 'input', s: { ...this.state, taps: { ...this.state.taps } } });
  }
}
