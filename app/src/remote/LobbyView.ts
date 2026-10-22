import { el, button, setText, clear } from '../ui/dom';
import { icon } from '../ui/icons';
import { PLAYER_COLORS, MAX_PLAYERS, type PlayerSlot } from './protocol';
import type { RemoteHost, RemotePlayer } from './RemoteHost';
import { qrSvg } from './qr';
import { LOBBY_CSS } from './lobbyStyles';
import { moveFocus, type Dir } from './spatialNav';

export interface LobbyViewOptions {
  /** "Empezar" (habilitado con ≥1 jugador conectado). */
  onStart(): void;
  /** Botón "Volver" y tecla Atrás del control remoto. Si no se pasa, no se muestra. */
  onBack?(): void;
  /** Título grande. */
  title?: string;
  /** Muestra "Quitar" en cada lugar ocupado (libera el asiento). Por defecto true. */
  allowKick?: boolean;
}

const KEY_DIR: Record<string, Dir> = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' };
const BACK_KEYS = new Set(['Escape', 'Backspace', 'GoBack', 'BrowserBack']);

/**
 * Pantalla de espera del tele: QR grande con la URL del control, los 2 lugares y "Empezar".
 * Pensada para leerse a 3 m: textos grandes, alto contraste, área segura de TV (5%) y
 * navegación con D-pad (flechas + OK) con foco bien visible.
 *
 * Se actualiza sola mientras está visible (eventos del host + refresco cada 250 ms para latencia
 * y cuenta regresiva de reconexión).
 */
export class LobbyView {
  readonly root: HTMLDivElement;
  private readonly qrBox: HTMLDivElement;
  private readonly urlText: HTMLDivElement;
  private readonly startBtn: HTMLButtonElement;
  private readonly startHint: HTMLParagraphElement;
  private readonly slots: SlotCard[];
  private timer: ReturnType<typeof setInterval> | null = null;
  private readonly unsubs: (() => void)[] = [];
  private shownUrl: string | null = null;

  constructor(parent: HTMLElement, private readonly host: RemoteHost, private readonly opts: LobbyViewOptions) {
    injectCss();
    this.qrBox = el('div', 'rl-qr');
    this.urlText = el('div', 'rl-url');
    const qrCol = el('section', { cls: 'rl-qrcol', attrs: { 'aria-label': 'Cómo unirse' } }, [
      el('div', 'rl-qrcard', [this.qrBox]),
      el('p', { cls: 'rl-scan', text: 'Escaneá con la tablet o abrí Misión Energía Control' }),
      this.urlText,
    ]);

    this.slots = ([0, 1] as PlayerSlot[]).map((s) => new SlotCard(s, opts.allowKick !== false ? () => this.host.kick(s, 'El tele liberó tu lugar') : null));
    this.startBtn = button('rl-btn rl-btn-primary', [icon('play', 40), el('span', { text: 'Empezar' })], () => {
      if (!this.startBtn.disabled) this.opts.onStart();
    });
    this.startHint = el('p', { cls: 'rl-hint' });
    const actions = el('div', 'rl-actions', [this.startBtn]);
    if (opts.onBack) {
      actions.appendChild(button('rl-btn rl-btn-secondary', [icon('back', 34), el('span', { text: 'Volver' })], () => this.opts.onBack?.()));
    }

    const main = el('section', 'rl-main', [
      el('header', 'rl-head', [
        el('div', { cls: 'rl-eyebrow', text: 'Modo TV · hasta 2 jugadores' }),
        el('h1', { cls: 'rl-title', text: opts.title ?? '¡Sumate con tu tablet!' }),
        el('p', { cls: 'rl-sub', text: 'Cada tablet es un joystick. Misma red Wi-Fi que el tele.' }),
      ]),
      el('div', { cls: 'rl-slots', attrs: { role: 'list' } }, this.slots.map((s) => s.root)),
      el('div', 'rl-foot', [actions, this.startHint]),
    ]);

    this.root = el('div', { cls: 'rl', attrs: { role: 'dialog', 'aria-label': 'Sala de espera' }, hidden: true }, [
      el('div', 'rl-safe', [qrCol, main]),
    ]);
    parent.appendChild(this.root);

    const re = (): void => this.refresh();
    this.unsubs.push(host.onJoin(re), host.onLeave(re), host.onResume(re), host.onDrop(re));
  }

  get visible(): boolean { return !this.root.hidden; }

  show(): void {
    if (this.visible) return;
    this.root.hidden = false;
    this.refresh();
    this.timer = setInterval(() => this.refresh(), 250);
    // En la ventana (no en el root) para que el D-pad funcione aunque nada tenga foco todavía.
    window.addEventListener('keydown', this.onKey);
    this.focusDefault();
  }

  hide(): void {
    this.root.hidden = true;
    window.removeEventListener('keydown', this.onKey);
    if (this.timer !== null) { clearInterval(this.timer); this.timer = null; }
  }

  /** Vuelve a leer jugadores y URL del host (barato: solo toca el DOM si algo cambió). */
  refresh(): void {
    const url = this.host.controllerUrl;
    if (url !== this.shownUrl) this.renderUrl(url);
    const ps = this.host.players();
    const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
    ps.forEach((p, i) => this.slots[i].render(p, now));
    const ready = ps.some((p) => p?.connected);
    const wasDisabled = this.startBtn.disabled;
    this.startBtn.disabled = !ready;
    const n = ps.filter((p) => p?.connected).length;
    setText(this.startHint, ready
      ? (n < MAX_PLAYERS ? 'Podés empezar ya o esperar a otro jugador' : '¡Equipo completo!')
      : 'Necesitás al menos 1 tablet conectada');
    // Al habilitarse "Empezar", el foco salta ahí (un OK y arranca).
    if (wasDisabled && ready && this.visible) this.startBtn.focus({ preventScroll: true });
    if (!this.root.contains(document.activeElement) && this.visible) this.focusDefault();
  }

  dispose(): void {
    this.hide();
    this.unsubs.forEach((u) => u());
    this.root.remove();
  }

  private renderUrl(url: string): void {
    this.shownUrl = url;
    clear(this.qrBox);
    if (url) {
      this.qrBox.appendChild(qrSvg(url, { quiet: 2, label: `Código QR para abrir el control: ${url}` }));
      setText(this.urlText, url.replace(/^https?:\/\//, '').replace(/\/$/, ''));
      this.urlText.classList.remove('is-off');
    } else {
      this.qrBox.appendChild(el('div', 'rl-noqr', [
        el('b', { text: 'Sin red' }),
        el('span', { text: 'Conectá el tele a la red Wi-Fi para jugar con tablets' }),
      ]));
      setText(this.urlText, 'Esperando red…');
      this.urlText.classList.add('is-off');
    }
  }

  private focusDefault(): void {
    const target = !this.startBtn.disabled ? this.startBtn
      : Array.from(this.root.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')).find((b) => !b.hidden && !b.closest('[hidden]'));
    target?.focus({ preventScroll: true });
  }

  private onKey = (e: KeyboardEvent): void => {
    if (!this.visible) return;
    const dir = KEY_DIR[e.key];
    if (dir) {
      e.preventDefault();
      moveFocus(this.root, dir);
      return;
    }
    if (BACK_KEYS.has(e.key) && this.opts.onBack) {
      e.preventDefault();
      this.opts.onBack();
    }
  };
}

class SlotCard {
  readonly root: HTMLDivElement;
  private readonly name: HTMLDivElement;
  private readonly status: HTMLDivElement;
  private readonly ping: HTMLDivElement;
  private readonly pingText: HTMLSpanElement;
  private readonly kickBtn: HTMLButtonElement | null;
  private key = '';

  constructor(readonly slot: PlayerSlot, onKick: (() => void) | null) {
    const col = PLAYER_COLORS[slot];
    this.name = el('div', 'rl-name');
    this.status = el('div', 'rl-status');
    this.pingText = el('span');
    this.ping = el('div', { cls: 'rl-ping', attrs: { 'aria-label': 'Latencia' } }, [
      el('span', 'rl-bars', [el('i'), el('i'), el('i')]), this.pingText,
    ]);
    this.kickBtn = onKick ? button('rl-kick', [icon('close', 28), el('span', { text: 'Quitar' })], onKick) : null;
    this.root = el('div', { cls: 'rl-slot is-empty', attrs: { role: 'listitem' } }, [
      el('div', 'rl-avatar', [el('span', { cls: 'rl-num', text: String(slot + 1) }), icon('helmet', 44, 'rl-helmet')]),
      el('div', 'rl-info', [this.name, this.status]),
      this.ping,
      this.kickBtn,
    ]);
    this.root.style.setProperty('--pc', col.hex);
  }

  render(p: RemotePlayer | null, now: number): void {
    const col = PLAYER_COLORS[this.slot];
    let name: string, status: string, state: string, ping = '', q = '';
    if (!p) {
      state = 'empty';
      name = 'Esperando';
      status = `Lugar ${this.slot + 1} · ${col.name}`;
    } else if (p.connected) {
      state = 'on';
      name = p.name;
      status = `${col.name} · ${p.device === 'app' ? 'App Control' : 'Navegador'}`;
      if (p.latencyMs !== null) {
        ping = `${p.latencyMs} ms`;
        q = p.latencyMs < 60 ? 'good' : p.latencyMs < 150 ? 'ok' : 'bad';
      } else { ping = '…'; q = 'ok'; }
    } else {
      state = 'off';
      name = p.name;
      const left = p.reservedUntil !== null ? Math.max(0, Math.ceil((p.reservedUntil - now) / 1000)) : 0;
      status = `Reconectando… lugar guardado ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
    }
    const key = `${state}|${name}|${status}|${ping}|${q}`;
    if (key === this.key) return;
    this.key = key;
    this.root.className = `rl-slot is-${state}`;
    setText(this.name, name);
    setText(this.status, status);
    setText(this.pingText, ping);
    this.ping.hidden = state !== 'on';
    this.ping.dataset.q = q;
    if (this.kickBtn) {
      const wasFocused = document.activeElement === this.kickBtn;
      this.kickBtn.hidden = !p;
      this.kickBtn.setAttribute('aria-label', p ? `Quitar a ${p.name}` : 'Quitar');
      if (wasFocused && !p) (this.root.closest('.rl')?.querySelector('.rl-btn') as HTMLElement | null)?.focus();
    }
  }
}

let cssDone = false;
function injectCss(): void {
  if (cssDone || typeof document === 'undefined') return;
  cssDone = true;
  const s = document.createElement('style');
  s.id = 'remote-lobby-css';
  s.textContent = LOBBY_CSS;
  document.head.appendChild(s);
}
