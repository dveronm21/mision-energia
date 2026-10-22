/**
 * PROTOCOLO DE CONTROL REMOTO — Misión Energía TV
 *
 * Tele (host, app Android TV) ⇄ tablets (control) por la red local (Wi-Fi).
 *
 * Transporte:
 *  - HTTP + WebSocket en el tele, puerto HTTP_PORT. `GET /` sirve la página de control
 *    (assets/controller/). `GET /ws` abre el WebSocket del protocolo (mensajes JSON de texto).
 *  - Descubrimiento UDP (para la app de control instalada): la tablet manda por broadcast
 *    el texto `DISCOVERY_QUERY` al puerto DISCOVERY_PORT; el tele responde por unicast con
 *    JSON DiscoveryReply. También se puede conectar escaneando el QR del tele (URL directa).
 *
 * Mejoras respecto al protocolo de BombSquad Remote (UDP 43210, estados con acks):
 *  - Sin escribir IP: QR en el tele + descubrimiento UDP + reconexión automática.
 *  - Asiento reservado: `token` de sesión; si la tablet se cae y vuelve en RESUME_WINDOW_MS,
 *    recupera su jugador.
 *  - Bidireccional: el tele manda contexto (texto del botón de acción, objetivo, color),
 *    vibración y estado del jugador; la tablet muestra latencia (ping/pong).
 *  - Estado y no eventos: cada `input` trae el estado completo (último gana) con `seq`;
 *    se envía al cambiar y como keepalive cada KEEPALIVE_MS. Los botones de un toque usan
 *    contador `taps` acumulativo para no perder pulsaciones aunque se pierda un mensaje.
 */

export const PROTOCOL_VERSION = 1;
export const HTTP_PORT = 8765;
export const DISCOVERY_PORT = 8766;
export const DISCOVERY_QUERY = 'MISION-ENERGIA-DISCOVER-1';
export const MAX_PLAYERS = 2;
export const KEEPALIVE_MS = 100;
export const PLAYER_TIMEOUT_MS = 3000;     // sin mensajes → jugador "desconectado" (personaje quieto)
export const RESUME_WINDOW_MS = 60000;     // asiento reservado para reconectar con el mismo token

export type PlayerSlot = 0 | 1;
export const PLAYER_COLORS: Record<PlayerSlot, { name: string; hex: string; vest: number; helmet: number }> = {
  0: { name: 'Naranja', hex: '#F28C28', vest: 0xf28c28, helmet: 0xffd23f },
  1: { name: 'Azul', hex: '#2F7BE0', vest: 0x2f7be0, helmet: 0xffffff },
};

/** Botones mantenidos (bitmask en InputState.held). */
export const BTN = { RUN: 1 << 0 } as const;

/** Contadores acumulativos de toques (se comparan con el último visto). */
export interface TapCounters { action: number; inspect: number; tool: number; pause: number; }

export interface InputState {
  seq: number;          // creciente por conexión
  x: number;            // joystick −1..1 (derecha +)
  y: number;            // joystick −1..1 (abajo +)
  held: number;         // bitmask BTN
  taps: TapCounters;
}

/* ---------- Mensajes tablet → tele ---------- */
export type ClientMsg =
  | { t: 'hello'; v: number; name: string; token?: string; device: 'browser' | 'app' }
  | { t: 'input'; s: InputState }
  | { t: 'ping'; at: number }
  | { t: 'bye' };

/* ---------- Mensajes tele → tablet ---------- */
export type ActionStyle = 'normal' | 'idle' | 'drop';
export interface ControllerContext {
  action: { label: string; style: ActionStyle; enabled: boolean };
  inspectEnabled: boolean;
  toolOn: boolean;
  toolEnabled: boolean;
  objective: string;            // paso actual de la misión
  screen: 'lobby' | 'menu' | 'playing' | 'paused' | 'result';
  status?: string;              // línea corta: "Batería 57% · 14:30"
}

export type ServerMsg =
  | { t: 'welcome'; v: number; slot: PlayerSlot; token: string; color: string; colorName: string; tvName: string }
  | { t: 'full'; reason: string }
  | { t: 'ctx'; c: ControllerContext }
  | { t: 'haptic'; pattern: number[] }          // ms para navigator.vibrate
  | { t: 'toast'; text: string; kind?: 'good' | 'bad' | 'info' }
  | { t: 'pong'; at: number }
  | { t: 'kick'; reason: string };

export interface DiscoveryReply { app: 'mision-energia-tv'; v: number; name: string; ip: string; port: number; players: number; max: number; }

/* ======================================================================
 * PUENTE NATIVO (Java ⇄ JS) en la app del tele
 * ==================================================================== */

/**
 * Objeto que la app Android TV inyecta como `window.RemoteBridge` (JavascriptInterface).
 * Todos los métodos son sincrónicos y baratos; el juego llama `poll()` una vez por frame.
 */
export interface NativeRemoteBridge {
  /** URL para el QR, ej. "http://192.168.0.23:8765/". Vacío si no hay red. */
  getControllerUrl(): string;
  getTvName(): string;
  /** JSON: BridgeEvent[] acumulados desde el último poll. */
  poll(): string;
  /** Envía un ServerMsg (JSON) a una conexión. */
  send(connId: number, json: string): void;
  /** Cierra una conexión. */
  close(connId: number, reason: string): void;
}

/** Eventos que entrega `poll()`: conexiones de WebSocket y sus mensajes crudos. */
export type BridgeEvent =
  | { e: 'open'; id: number; addr: string }
  | { e: 'msg'; id: number; data: string }
  | { e: 'close'; id: number };

/* ======================================================================
 * ENTRADA DEL JUEGO (abstracción usada por GameSession)
 * ==================================================================== */

/** Lo que un jugador "quiere hacer" en este frame, venga de pantalla táctil, teclado o tablet. */
export interface PlayerIntent {
  x: number; y: number;          // movimiento −1..1
  run: boolean;
  action: boolean;               // flanco: se pulsó acción en este frame
  inspect: boolean;              // flanco
  tool: boolean;                 // flanco
  pause: boolean;                // flanco
  connected: boolean;
}

export interface IInputSource {
  /** Llamar una vez por frame; devuelve la intención del jugador para este frame. */
  read(): PlayerIntent;
}
