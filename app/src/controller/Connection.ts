import { PROTOCOL_VERSION, type ClientMsg, type InputState, type ServerMsg } from '../remote/protocol';
import { parseServerMsg } from '../remote/validate';

export type ConnState =
  | { k: 'idle' }
  | { k: 'connecting'; attempt: number }
  | { k: 'open' }
  | { k: 'retrying'; attempt: number; at: number; hadSeat: boolean }
  | { k: 'full'; reason: string; at: number }
  | { k: 'kicked'; reason: string };

export interface WsLike {
  readyState: number;
  send(data: string): void;
  close(code?: number, reason?: string): void;
  onopen: ((ev: unknown) => void) | null;
  onmessage: ((ev: { data: unknown }) => void) | null;
  onclose: ((ev: unknown) => void) | null;
  onerror: ((ev: unknown) => void) | null;
}

export interface ConnectionOptions {
  url: string;
  name: string;
  device: 'browser' | 'app';
  token: string | null;
  onToken(token: string): void;
  onMessage(m: ServerMsg): void;
  onState(s: ConnState): void;
  wsFactory?: (url: string) => WsLike;
  now?: () => number;
}

const OPEN = 1;
const PING_EVERY_MS = 1000;
/** Sin noticias del tele en este tiempo → la conexión se considera muerta y se reintenta. */
const DEAD_AFTER_MS = 3500;
const WELCOME_TIMEOUT_MS = 4000;
const FULL_RETRY_MS = 4000;
const BACKOFF = [250, 500, 1000, 2000, 3000, 4000];

/**
 * WebSocket con el tele: hello con token, reconexión automática con backoff (mismo token =
 * mismo asiento), ping/pong para la latencia y vigilancia de conexión muerta.
 */
export class Connection {
  private ws: WsLike | null = null;
  private state: ConnState = { k: 'idle' };
  private attempt = 0;
  private hadSeat = false;
  private lastRxAt = 0;
  private timers: ReturnType<typeof setTimeout>[] = [];
  private pingTimer: ReturnType<typeof setInterval> | null = null;
  private retryTimer: ReturnType<typeof setTimeout> | null = null;
  private welcomeTimer: ReturnType<typeof setTimeout> | null = null;
  private stopped = true;
  private fullReason: string | null = null;
  private kickedReason: string | null = null;
  latencyMs: number | null = null;
  private readonly now: () => number;

  constructor(private readonly o: ConnectionOptions) {
    this.now = o.now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
  }

  get current(): ConnState { return this.state; }
  get isOpen(): boolean { return this.state.k === 'open'; }

  setName(name: string): void { this.o.name = name; }

  start(): void {
    this.stopped = false;
    this.kickedReason = null;
    this.connect();
  }

  /** Reintenta ya (botón "Reintentar ahora"). */
  retryNow(): void {
    if (this.stopped) return;
    this.clearRetry();
    if (this.state.k === 'open' || this.state.k === 'connecting') return;
    this.connect();
  }

  /** Sale del juego: avisa al tele (libera el asiento) y no reconecta. */
  leave(): void {
    this.send({ t: 'bye' });
    this.stop();
    this.o.token = null;
  }

  stop(): void {
    this.stopped = true;
    this.clearRetry();
    this.stopTimers();
    const ws = this.ws;
    this.ws = null;
    if (ws) { ws.onclose = null; ws.onmessage = null; try { ws.close(1000, 'bye'); } catch { /* */ } }
    this.setState({ k: 'idle' });
  }

  sendInput(s: InputState): boolean { return this.send({ t: 'input', s }); }

  send(m: ClientMsg): boolean {
    const ws = this.ws;
    if (!ws || ws.readyState !== OPEN) return false;
    try { ws.send(JSON.stringify(m)); return true; } catch { return false; }
  }

  private connect(): void {
    this.stopTimers();
    this.fullReason = null;
    this.attempt++;
    this.setState({ k: 'connecting', attempt: this.attempt });
    let ws: WsLike;
    try {
      ws = this.o.wsFactory ? this.o.wsFactory(this.o.url) : (new WebSocket(this.o.url) as unknown as WsLike);
    } catch {
      this.scheduleRetry();
      return;
    }
    this.ws = ws;
    ws.onopen = () => {
      if (this.ws !== ws) return;
      this.lastRxAt = this.now();
      this.send({ t: 'hello', v: PROTOCOL_VERSION, name: this.o.name, token: this.o.token ?? undefined, device: this.o.device });
      this.welcomeTimer = setTimeout(() => { if (this.ws === ws && this.state.k !== 'open') this.kill(ws); }, WELCOME_TIMEOUT_MS);
    };
    ws.onmessage = (ev) => {
      if (this.ws !== ws) return;
      this.lastRxAt = this.now();
      const m = parseServerMsg(typeof ev.data === 'string' ? ev.data : '');
      if (m) this.onServer(m);
    };
    ws.onerror = () => { /* llega onclose */ };
    ws.onclose = () => {
      if (this.ws !== ws) return;
      this.ws = null;
      this.stopTimers();
      if (this.stopped) return;
      if (this.kickedReason !== null) { this.setState({ k: 'kicked', reason: this.kickedReason }); return; }
      if (this.fullReason !== null) {
        const at = this.now() + FULL_RETRY_MS;
        this.setState({ k: 'full', reason: this.fullReason, at });
        this.retryTimer = setTimeout(() => this.connect(), FULL_RETRY_MS);
        return;
      }
      this.scheduleRetry();
    };
  }

  private onServer(m: ServerMsg): void {
    switch (m.t) {
      case 'welcome':
        if (this.welcomeTimer) { clearTimeout(this.welcomeTimer); this.welcomeTimer = null; }
        this.o.token = m.token;
        this.o.onToken(m.token);
        this.attempt = 0;
        this.hadSeat = true;
        this.setState({ k: 'open' });
        this.startPing();
        break;
      case 'pong': {
        const rtt = this.now() - m.at;
        if (rtt >= 0 && rtt < 10000) this.latencyMs = Math.round(this.latencyMs === null ? rtt : this.latencyMs * 0.6 + rtt * 0.4);
        break;
      }
      case 'full': this.fullReason = m.reason || 'El tele ya tiene 2 jugadores'; break;
      case 'kick': this.kickedReason = m.reason || 'El tele cerró tu lugar'; this.o.token = null; this.hadSeat = false; break;
    }
    this.o.onMessage(m);
  }

  private startPing(): void {
    if (this.pingTimer) clearInterval(this.pingTimer);
    const ping = (): void => {
      const ws = this.ws;
      if (!ws) return;
      if (this.now() - this.lastRxAt > DEAD_AFTER_MS) { this.kill(ws); return; }
      this.send({ t: 'ping', at: this.now(), rtt: this.latencyMs ?? undefined });
    };
    ping();
    this.pingTimer = setInterval(ping, PING_EVERY_MS);
  }

  private kill(ws: WsLike): void {
    try { ws.close(4000, 'dead'); } catch { /* */ }
    // Algunos navegadores tardan en disparar onclose de un socket colgado: forzamos.
    const onclose = ws.onclose;
    if (onclose) this.timers.push(setTimeout(() => { if (this.ws === ws) onclose({}); }, 300));
  }

  private scheduleRetry(): void {
    const base = BACKOFF[Math.max(0, Math.min(this.attempt - 1, BACKOFF.length - 1))];
    const delay = Math.round(base * (0.85 + Math.random() * 0.3));
    this.setState({ k: 'retrying', attempt: this.attempt, at: this.now() + delay, hadSeat: this.hadSeat });
    this.clearRetry();
    this.retryTimer = setTimeout(() => this.connect(), delay);
  }

  private clearRetry(): void {
    if (this.retryTimer) { clearTimeout(this.retryTimer); this.retryTimer = null; }
  }

  private stopTimers(): void {
    if (this.pingTimer) { clearInterval(this.pingTimer); this.pingTimer = null; }
    if (this.welcomeTimer) { clearTimeout(this.welcomeTimer); this.welcomeTimer = null; }
    this.timers.forEach(clearTimeout);
    this.timers = [];
  }

  private setState(s: ConnState): void {
    this.state = s;
    this.o.onState(s);
  }
}
