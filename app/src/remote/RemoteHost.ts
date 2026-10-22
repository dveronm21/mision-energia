import {
  MAX_PLAYERS, PLAYER_COLORS, PLAYER_TIMEOUT_MS, PROTOCOL_VERSION, RESUME_WINDOW_MS,
  type ControllerContext, type NativeRemoteBridge, type PlayerSlot, type ServerMsg,
} from './protocol';
import { RemoteInputSource, type StickTuning } from './RemoteInputSource';
import { LIMITS, parseBridgeEvents, parseClientMsg, sanitizeHaptic, sanitizeName } from './validate';

/** Intervalo mínimo entre dos `ctx` a la misma tablet (a lo sumo 10 por segundo). */
export const CTX_MIN_INTERVAL_MS = 100;
/** Una conexión que no manda `hello` en este tiempo se cierra. */
export const HELLO_TIMEOUT_MS = 5000;
/** Conexiones abiertas sin asiento a la vez (protección ante abusos). */
export const MAX_PENDING_CONNS = 8;
/** Límite de mensajes por conexión: ráfaga y recarga por segundo (token bucket). */
const RATE_BURST = 120;
const RATE_PER_SEC = 60;

export interface RemotePlayer {
  slot: PlayerSlot;
  name: string;
  color: string;
  colorName: string;
  /** Hay una conexión viva. false = se cayó, el asiento sigue reservado hasta `reservedUntil`. */
  connected: boolean;
  /** Última latencia ida y vuelta informada por la tablet (ms), o null si aún no hay dato. */
  latencyMs: number | null;
  device: 'browser' | 'app';
  /** Momento (reloj del host) hasta el que se guarda el asiento si está desconectado. */
  reservedUntil: number | null;
}

export type LeaveReason = 'bye' | 'kick' | 'expired' | 'released';
export type DropReason = 'closed' | 'timeout';

export interface RemoteHostEvents {
  join: (p: RemotePlayer) => void;
  leave: (slot: PlayerSlot, reason: LeaveReason) => void;
  resume: (p: RemotePlayer) => void;
  drop: (slot: PlayerSlot, reason: DropReason) => void;
}

export interface RemoteHostOptions {
  now?: () => number;
  makeToken?: () => string;
  stick?: Partial<StickTuning>;
}

interface Conn {
  id: number;
  openedAt: number;
  slot: PlayerSlot | null;
  bucket: number;
  bucketAt: number;
}

interface Seat {
  token: string;
  name: string;
  device: 'browser' | 'app';
  connId: number | null;
  lastSeenAt: number;
  droppedAt: number | null;
  latencyMs: number | null;
}

interface SlotCtx {
  wanted: ControllerContext;
  wantedJson: string;
  sentJson: string;
  sentAt: number;
}

const SLOTS: readonly PlayerSlot[] = [0, 1];

export function defaultContext(): ControllerContext {
  return {
    action: { label: '¡Listo!', style: 'idle', enabled: false },
    inspectEnabled: false, toolOn: false, toolEnabled: false,
    objective: 'Mirá el tele: la partida empieza en un momento',
    screen: 'lobby',
  };
}

function randomToken(): string {
  const bytes = new Uint8Array(12);
  const c = (globalThis as { crypto?: { getRandomValues?: (a: Uint8Array) => Uint8Array } }).crypto;
  if (c?.getRandomValues) c.getRandomValues(bytes);
  else for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Lado tele del control remoto. Lee `RemoteBridge.poll()` una vez por frame (`update()`),
 * valida los mensajes, asigna asientos 0/1, reserva el asiento por token durante
 * RESUME_WINDOW_MS, responde ping, detecta timeouts y expone un `RemoteInputSource` por asiento.
 *
 * Sin puente (navegador común) queda inactivo: `active === false` y todo es no-op.
 */
export class RemoteHost {
  readonly active: boolean;
  private readonly now: () => number;
  private readonly makeToken: () => string;
  private readonly conns = new Map<number, Conn>();
  private readonly seats: (Seat | null)[] = [null, null];
  private readonly inputs: readonly [RemoteInputSource, RemoteInputSource];
  private readonly ctx: [SlotCtx, SlotCtx];
  private readonly listeners: { [K in keyof RemoteHostEvents]: Set<RemoteHostEvents[K]> } = {
    join: new Set(), leave: new Set(), resume: new Set(), drop: new Set(),
  };

  /** Usa `window.RemoteBridge` si la app del tele lo inyectó; si no, queda inactivo. */
  static fromWindow(opts: RemoteHostOptions = {}): RemoteHost {
    const w = (typeof window !== 'undefined' ? window : undefined) as (Window & { RemoteBridge?: NativeRemoteBridge }) | undefined;
    const b = w?.RemoteBridge;
    return new RemoteHost(b && typeof b.poll === 'function' ? b : null, opts);
  }

  constructor(private readonly bridge: NativeRemoteBridge | null, opts: RemoteHostOptions = {}) {
    this.active = bridge !== null;
    this.now = opts.now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
    this.makeToken = opts.makeToken ?? randomToken;
    this.inputs = [new RemoteInputSource(0, opts.stick), new RemoteInputSource(1, opts.stick)];
    const mk = (): SlotCtx => {
      const wanted = defaultContext();
      return { wanted, wantedJson: JSON.stringify(wanted), sentJson: '', sentAt: -Infinity };
    };
    this.ctx = [mk(), mk()];
  }

  /* ======================= API para el juego ======================= */

  /** URL para el QR (vacía si no hay red o no hay puente). */
  get controllerUrl(): string { return this.safe(() => this.bridge?.getControllerUrl() ?? '', ''); }
  get tvName(): string { return this.safe(() => this.bridge?.getTvName() ?? '', '') || 'Misión Energía TV'; }

  /** Entrada del asiento (estable: siempre la misma instancia). */
  input(slot: PlayerSlot): RemoteInputSource { return this.inputs[slot]; }

  /** Llamar una vez por frame, antes de leer las entradas. */
  update(): void {
    if (!this.bridge) return;
    const now = this.now();
    const raw = this.safe(() => this.bridge!.poll(), '');
    for (const ev of parseBridgeEvents(raw)) {
      if (ev.e === 'open') this.onOpen(ev.id, now);
      else if (ev.e === 'close') this.onClose(ev.id);
      else this.onMessage(ev.id, ev.data, now);
    }
    this.checkTimeouts(now);
    for (const s of SLOTS) this.flushCtx(s, now);
  }

  /** Contexto del control (texto del botón, objetivo, pantalla…). Se manda solo si cambió, ≤10/s. */
  setContext(slot: PlayerSlot, ctx: ControllerContext): void {
    const c = this.ctx[slot];
    const json = JSON.stringify(ctx);
    if (json === c.wantedJson) return;
    c.wanted = JSON.parse(json) as ControllerContext;
    c.wantedJson = json;
    if (this.bridge) this.flushCtx(slot, this.now());
  }

  /** Igual que setContext para los dos asientos. */
  setContextAll(ctx: ControllerContext): void { for (const s of SLOTS) this.setContext(s, ctx); }

  getContext(slot: PlayerSlot): ControllerContext { return JSON.parse(this.ctx[slot].wantedJson) as ControllerContext; }

  /** Vibración en la tablet (ms, formato navigator.vibrate). */
  haptic(slot: PlayerSlot, pattern: number[]): void {
    const p = sanitizeHaptic(pattern);
    if (p) this.sendTo(slot, { t: 'haptic', pattern: p });
  }

  toast(slot: PlayerSlot, text: string, kind?: 'good' | 'bad' | 'info'): void {
    this.sendTo(slot, { t: 'toast', text: String(text).slice(0, LIMITS.maxToastChars), kind });
  }

  /** Echa al jugador y libera el asiento. */
  kick(slot: PlayerSlot, reason = 'El tele cerró tu lugar'): void {
    const seat = this.seats[slot];
    if (!seat) return;
    if (seat.connId !== null) {
      this.sendRaw(seat.connId, { t: 'kick', reason });
      this.closeConn(seat.connId, 'kick');
    }
    this.freeSeat(slot, 'kick');
  }

  /** Libera un asiento reservado (jugador desconectado) sin esperar RESUME_WINDOW_MS. */
  release(slot: PlayerSlot): void {
    const seat = this.seats[slot];
    if (seat && seat.connId === null) this.freeSeat(slot, 'released');
  }

  /** Jugadores por asiento (índice = slot); null = lugar libre. */
  players(): (RemotePlayer | null)[] { return SLOTS.map((s) => this.info(s)); }

  /** Asientos ocupados (conectados o reservados). */
  playerCount(): number { return this.seats.filter(Boolean).length; }
  connectedCount(): number { return this.seats.filter((s) => s && s.connId !== null).length; }

  onJoin(fn: RemoteHostEvents['join']): () => void { return this.on('join', fn); }
  onLeave(fn: RemoteHostEvents['leave']): () => void { return this.on('leave', fn); }
  onResume(fn: RemoteHostEvents['resume']): () => void { return this.on('resume', fn); }
  /** Se cayó la conexión pero el asiento queda reservado. */
  onDrop(fn: RemoteHostEvents['drop']): () => void { return this.on('drop', fn); }

  /** Cierra todas las conexiones y olvida los asientos. */
  dispose(): void {
    for (const id of Array.from(this.conns.keys())) this.closeConn(id, 'bye');
    for (const s of SLOTS) if (this.seats[s]) this.freeSeat(s, 'released');
    for (const k of Object.keys(this.listeners) as (keyof RemoteHostEvents)[]) this.listeners[k].clear();
  }

  /* ======================= Internos ======================= */

  private on<K extends keyof RemoteHostEvents>(k: K, fn: RemoteHostEvents[K]): () => void {
    this.listeners[k].add(fn);
    return () => { this.listeners[k].delete(fn); };
  }

  private emit<K extends keyof RemoteHostEvents>(k: K, ...args: Parameters<RemoteHostEvents[K]>): void {
    for (const fn of Array.from(this.listeners[k])) {
      try { (fn as (...a: Parameters<RemoteHostEvents[K]>) => void)(...args); } catch (e) { console.warn('[remote] listener', e); }
    }
  }

  private info(slot: PlayerSlot): RemotePlayer | null {
    const s = this.seats[slot];
    if (!s) return null;
    const col = PLAYER_COLORS[slot];
    return {
      slot, name: s.name, color: col.hex, colorName: col.name, connected: s.connId !== null,
      latencyMs: s.latencyMs, device: s.device,
      reservedUntil: s.droppedAt === null ? null : s.droppedAt + RESUME_WINDOW_MS,
    };
  }

  private onOpen(id: number, now: number): void {
    if (this.conns.has(id)) return;
    const pending = Array.from(this.conns.values()).filter((c) => c.slot === null).length;
    if (pending >= MAX_PENDING_CONNS) { this.safe(() => this.bridge!.close(id, 'busy'), undefined); return; }
    this.conns.set(id, { id, openedAt: now, slot: null, bucket: RATE_BURST, bucketAt: now });
  }

  private onClose(id: number): void {
    const c = this.conns.get(id);
    if (!c) return;
    this.conns.delete(id);
    if (c.slot !== null) this.dropSeat(c.slot, 'closed');
  }

  private onMessage(id: number, data: string, now: number): void {
    let c = this.conns.get(id);
    if (!c) {
      // El puente puede entregar un mensaje sin 'open' previo (o lo descartamos por lleno): lo registramos.
      this.onOpen(id, now);
      c = this.conns.get(id);
      if (!c) return;
    }
    // Token bucket: descarta excesos sin cortar la conexión.
    c.bucket = Math.min(RATE_BURST, c.bucket + ((now - c.bucketAt) / 1000) * RATE_PER_SEC);
    c.bucketAt = now;
    if (c.bucket < 1) return;
    c.bucket -= 1;

    const msg = parseClientMsg(data);
    if (!msg) return;
    if (msg.t === 'hello') { this.onHello(c, msg.v, msg.name, msg.token, msg.device, now); return; }
    if (c.slot === null) return;
    const seat = this.seats[c.slot];
    if (!seat || seat.connId !== c.id) return;
    seat.lastSeenAt = now;
    switch (msg.t) {
      case 'input': this.inputs[c.slot].applyState(msg.s); break;
      case 'ping':
        if (msg.rtt !== undefined) seat.latencyMs = msg.rtt;
        this.sendRaw(c.id, { t: 'pong', at: msg.at });
        break;
      case 'bye': {
        const slot = c.slot;
        this.closeConn(c.id, 'bye');
        this.freeSeat(slot, 'bye');
        break;
      }
    }
  }

  private onHello(c: Conn, v: number, rawName: string, token: string | undefined, device: 'browser' | 'app', now: number): void {
    if (c.slot !== null) return; // hello repetido
    if (v !== PROTOCOL_VERSION) {
      this.sendRaw(c.id, { t: 'kick', reason: 'Versión incompatible: actualizá la app de control' });
      this.closeConn(c.id, 'version');
      return;
    }
    // ¿Vuelve un jugador con su token?
    const resumed = token ? SLOTS.find((s) => this.seats[s]?.token === token) : undefined;
    if (resumed !== undefined) {
      const seat = this.seats[resumed]!;
      if (seat.connId !== null && seat.connId !== c.id) this.closeConn(seat.connId, 'replaced');
      if (rawName) seat.name = rawName;
      seat.device = device;
      this.bind(c, resumed, seat, now, false);
      this.emit('resume', this.info(resumed)!);
      return;
    }
    const free = SLOTS.find((s) => this.seats[s] === null);
    if (free === undefined) {
      this.sendRaw(c.id, { t: 'full', reason: `Ya hay ${MAX_PLAYERS} jugadores en este tele` });
      this.closeConn(c.id, 'full');
      return;
    }
    const seat: Seat = {
      token: this.makeToken(), name: rawName || `Jugador ${free + 1}`, device,
      connId: null, lastSeenAt: now, droppedAt: null, latencyMs: null,
    };
    this.seats[free] = seat;
    this.bind(c, free, seat, now, true);
    this.emit('join', this.info(free)!);
  }

  private bind(c: Conn, slot: PlayerSlot, seat: Seat, now: number, newPlayer: boolean): void {
    c.slot = slot;
    seat.connId = c.id;
    seat.lastSeenAt = now;
    seat.droppedAt = null;
    this.inputs[slot].beginConnection(newPlayer);
    const col = PLAYER_COLORS[slot];
    this.sendRaw(c.id, {
      t: 'welcome', v: PROTOCOL_VERSION, slot, token: seat.token, color: col.hex, colorName: col.name,
      tvName: this.tvName, resumed: !newPlayer,
    });
    // El contexto va siempre enseguida del welcome (conexión nueva = nada enviado aún).
    const sc = this.ctx[slot];
    sc.sentJson = '';
    sc.sentAt = -Infinity;
    this.flushCtx(slot, now);
  }

  private checkTimeouts(now: number): void {
    for (const c of Array.from(this.conns.values())) {
      if (c.slot === null && now - c.openedAt > HELLO_TIMEOUT_MS) this.closeConn(c.id, 'hello-timeout');
    }
    for (const s of SLOTS) {
      const seat = this.seats[s];
      if (!seat) continue;
      if (seat.connId !== null && now - seat.lastSeenAt > PLAYER_TIMEOUT_MS) {
        const id = seat.connId;
        this.dropSeat(s, 'timeout');
        this.conns.delete(id);
        this.safe(() => this.bridge!.close(id, 'timeout'), undefined);
      } else if (seat.connId === null && seat.droppedAt !== null && now - seat.droppedAt > RESUME_WINDOW_MS) {
        this.freeSeat(s, 'expired');
      }
    }
  }

  private dropSeat(slot: PlayerSlot, reason: DropReason): void {
    const seat = this.seats[slot];
    if (!seat || seat.connId === null) return;
    seat.connId = null;
    seat.droppedAt = this.now();
    this.inputs[slot].disconnect();
    this.emit('drop', slot, reason);
  }

  private freeSeat(slot: PlayerSlot, reason: LeaveReason): void {
    if (!this.seats[slot]) return;
    this.seats[slot] = null;
    this.inputs[slot].disconnect();
    this.emit('leave', slot, reason);
  }

  private flushCtx(slot: PlayerSlot, now: number): void {
    const seat = this.seats[slot];
    if (!seat || seat.connId === null) return;
    const c = this.ctx[slot];
    if (c.wantedJson === c.sentJson || now - c.sentAt < CTX_MIN_INTERVAL_MS) return;
    c.sentJson = c.wantedJson;
    c.sentAt = now;
    this.sendRaw(seat.connId, { t: 'ctx', c: c.wanted });
  }

  private sendTo(slot: PlayerSlot, msg: ServerMsg): void {
    const seat = this.seats[slot];
    if (seat && seat.connId !== null) this.sendRaw(seat.connId, msg);
  }

  private sendRaw(connId: number, msg: ServerMsg): void {
    if (!this.bridge) return;
    const json = JSON.stringify(msg);
    this.safe(() => this.bridge!.send(connId, json), undefined);
  }

  /** Cierra la conexión del lado del tele; si tenía asiento, lo desvincula sin liberarlo. */
  private closeConn(id: number, reason: string): void {
    const c = this.conns.get(id);
    this.conns.delete(id);
    if (c && c.slot !== null) {
      const seat = this.seats[c.slot];
      if (seat && seat.connId === id) {
        seat.connId = null;
        seat.droppedAt = this.now();
        this.inputs[c.slot].disconnect();
      }
    }
    if (this.bridge) this.safe(() => this.bridge!.close(id, reason), undefined);
  }

  private safe<T>(fn: () => T, fallback: T): T {
    try { return fn(); } catch (e) { console.warn('[remote] bridge', e); return fallback; }
  }
}

/** Nombre limpio para mostrar (re-exportado para la UI). */
export { sanitizeName };
