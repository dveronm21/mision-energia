/**
 * Validación defensiva de lo que llega por la red (tablet → tele) y por el puente nativo.
 * Nada de lo que viene de afuera se usa sin pasar por acá: tipos, rangos y largos acotados.
 */
import type { BridgeEvent, ClientMsg, InputState, ServerMsg, TapCounters } from './protocol';

export const LIMITS = {
  /** Largo máximo de un mensaje crudo (un input real ocupa ~110 caracteres). */
  maxMsgChars: 1024,
  maxNameChars: 14,
  maxTokenChars: 64,
  /** Eventos procesados como máximo en un poll (protege el frame). */
  maxEventsPerPoll: 1000,
  /** Contadores de toques: enteros 0..2^31. */
  maxCounter: 0x7fffffff,
  maxToastChars: 80,
  maxHapticSteps: 12,
  maxHapticMs: 2000,
  maxRttMs: 10000,
} as const;

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => typeof v === 'object' && v !== null && !Array.isArray(v);
const isNum = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
const isCounter = (v: unknown): v is number => isNum(v) && Number.isInteger(v) && v >= 0 && v <= LIMITS.maxCounter;
const clamp = (v: number, a: number, b: number): number => (v < a ? a : v > b ? b : v);

/** Controles, marcas de dirección, separadores de línea y caracteres invisibles. */
const INVISIBLE = new RegExp('[\\u0000-\\u001f\\u007f-\\u009f\\u200b-\\u200f\\u2028-\\u202e\\u2060-\\u206f\\ufeff]', 'g');

/** Limpia un nombre: sin caracteres de control ni marcas invisibles, espacios colapsados, largo acotado. */
export function sanitizeName(raw: unknown, max: number = LIMITS.maxNameChars): string {
  if (typeof raw !== 'string') return '';
  const clean = raw.replace(/\s+/g, ' ').replace(INVISIBLE, '').replace(/ +/g, ' ').trim();
  return Array.from(clean).slice(0, max).join('').trim();
}

function parseTaps(v: unknown): TapCounters | null {
  if (!isObj(v)) return null;
  const { action, inspect, tool, pause } = v;
  if (!isCounter(action) || !isCounter(inspect) || !isCounter(tool) || !isCounter(pause)) return null;
  return { action, inspect, tool, pause };
}

export function parseInputState(v: unknown): InputState | null {
  if (!isObj(v)) return null;
  const { seq, x, y, held } = v;
  if (!isCounter(seq) || !isNum(x) || !isNum(y) || !isCounter(held)) return null;
  const taps = parseTaps(v.taps);
  if (!taps) return null;
  return { seq, x: clamp(x, -1, 1), y: clamp(y, -1, 1), held, taps };
}

/** Parsea un mensaje de la tablet. Devuelve null si es inválido (se ignora en silencio). */
export function parseClientMsg(raw: unknown): ClientMsg | null {
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > LIMITS.maxMsgChars) return null;
  let v: unknown;
  try { v = JSON.parse(raw); } catch { return null; }
  if (!isObj(v) || typeof v.t !== 'string') return null;
  switch (v.t) {
    case 'hello': {
      if (!isNum(v.v)) return null;
      if (typeof v.name !== 'string') return null;
      const device = v.device === 'app' ? 'app' : 'browser';
      let token: string | undefined;
      if (v.token !== undefined) {
        if (typeof v.token !== 'string' || v.token.length > LIMITS.maxTokenChars || !/^[A-Za-z0-9_-]*$/.test(v.token)) return null;
        token = v.token || undefined;
      }
      return { t: 'hello', v: v.v, name: sanitizeName(v.name), token, device };
    }
    case 'input': {
      const s = parseInputState(v.s);
      return s ? { t: 'input', s } : null;
    }
    case 'ping': {
      if (!isNum(v.at)) return null;
      const msg: ClientMsg = { t: 'ping', at: v.at };
      if (isNum(v.rtt) && v.rtt >= 0 && v.rtt <= LIMITS.maxRttMs) msg.rtt = Math.round(v.rtt);
      return msg;
    }
    case 'bye':
      return { t: 'bye' };
    default:
      return null;
  }
}

/** Parsea el JSON de `RemoteBridge.poll()`. Ignora eventos mal formados. */
export function parseBridgeEvents(raw: unknown): BridgeEvent[] {
  if (typeof raw !== 'string' || raw.length === 0) return [];
  let v: unknown;
  try { v = JSON.parse(raw); } catch { return []; }
  if (!Array.isArray(v)) return [];
  const out: BridgeEvent[] = [];
  for (let i = 0; i < v.length && out.length < LIMITS.maxEventsPerPoll; i++) {
    const ev = v[i];
    if (!isObj(ev) || !isCounter(ev.id)) continue;
    if (ev.e === 'open') out.push({ e: 'open', id: ev.id, addr: typeof ev.addr === 'string' ? ev.addr.slice(0, 64) : '' });
    else if (ev.e === 'close') out.push({ e: 'close', id: ev.id });
    else if (ev.e === 'msg' && typeof ev.data === 'string') out.push({ e: 'msg', id: ev.id, data: ev.data });
  }
  return out;
}

/** Parsea un mensaje del tele (lo usa la página de control). */
export function parseServerMsg(raw: unknown): ServerMsg | null {
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 8192) return null;
  let v: unknown;
  try { v = JSON.parse(raw); } catch { return null; }
  if (!isObj(v) || typeof v.t !== 'string') return null;
  const str = (x: unknown, max: number): string => (typeof x === 'string' ? x.slice(0, max) : '');
  switch (v.t) {
    case 'welcome':
      if ((v.slot !== 0 && v.slot !== 1) || typeof v.token !== 'string') return null;
      return {
        t: 'welcome', v: isNum(v.v) ? v.v : 0, slot: v.slot, token: str(v.token, LIMITS.maxTokenChars),
        color: /^#[0-9a-fA-F]{6}$/.test(str(v.color, 7)) ? str(v.color, 7) : '#F28C28',
        colorName: str(v.colorName, 24), tvName: str(v.tvName, 40), resumed: v.resumed === true,
      };
    case 'full': return { t: 'full', reason: str(v.reason, 120) };
    case 'kick': return { t: 'kick', reason: str(v.reason, 120) };
    case 'pong': return isNum(v.at) ? { t: 'pong', at: v.at } : null;
    case 'toast': {
      const kind = v.kind === 'good' || v.kind === 'bad' || v.kind === 'info' ? v.kind : undefined;
      return { t: 'toast', text: str(v.text, LIMITS.maxToastChars), kind };
    }
    case 'haptic': {
      const p = sanitizeHaptic(v.pattern);
      return p ? { t: 'haptic', pattern: p } : null;
    }
    case 'ctx': {
      const c = v.c;
      if (!isObj(c) || !isObj(c.action)) return null;
      const style = c.action.style === 'idle' || c.action.style === 'drop' ? c.action.style : 'normal';
      const screens = ['lobby', 'menu', 'playing', 'paused', 'result'] as const;
      const screen = screens.find((s) => s === c.screen) ?? 'playing';
      return {
        t: 'ctx',
        c: {
          action: { label: str(c.action.label, 40), style, enabled: c.action.enabled !== false },
          inspectEnabled: c.inspectEnabled === true,
          toolOn: c.toolOn === true,
          toolEnabled: c.toolEnabled === true,
          objective: str(c.objective, 140),
          screen,
          status: typeof c.status === 'string' ? str(c.status, 80) : undefined,
        },
      };
    }
    default: return null;
  }
}

/** Patrón de vibración seguro: enteros 0..2000 ms, máx 12 pasos. */
export function sanitizeHaptic(p: unknown): number[] | null {
  if (!Array.isArray(p) || p.length === 0) return null;
  const out: number[] = [];
  for (const n of p.slice(0, LIMITS.maxHapticSteps)) {
    if (!isNum(n)) return null;
    out.push(Math.round(clamp(n, 0, LIMITS.maxHapticMs)));
  }
  return out;
}
