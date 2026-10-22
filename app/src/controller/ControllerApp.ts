import { el, button, clear, setText } from '../ui/dom';
import { icon } from '../ui/icons';
import { BTN, type ControllerContext, type ServerMsg } from '../remote/protocol';
import { sanitizeName } from '../remote/validate';
import { Connection, type ConnState } from './Connection';
import { InputModel, type TapKey } from './InputModel';
import { FloatingStick, type StickOutput } from './FloatingStick';
import { glyph } from './glyphs';
import { goFullscreen, isApp, keepAwake, store, vibrate, wsUrl } from './device';

const K_NAME = 'me.remote.name';
const K_TOKEN = 'me.remote.token';
const SEND_TICK_MS = 16;

type Screen = 'name' | 'connecting' | 'retrying' | 'full' | 'kicked' | 'lobby' | 'paused' | 'play';

interface Me { slot: number; color: string; colorName: string; tvName: string; }

/**
 * Página de control: nombre → conexión → joystick + botones. Toda la lógica de red está en
 * Connection; acá se arma la UI y se traduce el contexto del tele a la pantalla.
 */
export class ControllerApp {
  private readonly root: HTMLDivElement;
  private readonly model = new InputModel();
  private readonly conn: Connection;
  private ctx: ControllerContext | null = null;
  private me: Me | null = null;
  private name: string;
  private screen: Screen = 'name';
  private overlayKey = '';
  private toolOptimistic: boolean | null = null;

  // Nodos
  private readonly over: HTMLDivElement;
  private readonly connPill: HTMLDivElement;
  private readonly connText: HTMLSpanElement;
  private connIcon: SVGSVGElement;
  private readonly meName: HTMLDivElement;
  private readonly meSub: HTMLDivElement;
  private readonly meAva: HTMLDivElement;
  private readonly goalText: HTMLDivElement;
  private readonly goalStatus: HTMLDivElement;
  private readonly act: HTMLButtonElement;
  private readonly actLabel: HTMLSpanElement;
  private readonly inspect: HTMLButtonElement;
  private readonly tool: HTMLButtonElement;
  private readonly toolState: HTMLSpanElement;
  private readonly pause: HTMLButtonElement;
  private readonly toastHost: HTMLDivElement;
  private readonly stick: FloatingStick;
  private toastTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(host: HTMLElement) {
    this.name = sanitizeName(store.get(K_NAME) ?? '');
    const token = store.get(K_TOKEN, true) ?? store.get(K_TOKEN);

    // ----- Barra superior -----
    this.connIcon = glyph('wifi', 22);
    this.connText = el('span', { text: 'Conectando' });
    this.connPill = el('div', { cls: 'c-conn', attrs: { 'aria-live': 'polite' } }, [this.connIcon, this.connText]);
    this.meAva = el('div', { cls: 'c-ava', text: '1' });
    this.meName = el('div', 'c-me-name');
    this.meSub = el('div', 'c-me-sub');
    this.goalText = el('div', 'c-goal-text');
    this.goalStatus = el('div', 'c-goal-status');
    this.pause = el('button', { cls: 'c-pause', attrs: { type: 'button', 'aria-label': 'Pausa' } }, [icon('pause', 30)]);
    const top = el('header', 'c-top', [
      el('div', 'c-me', [this.meAva, el('div', 'c-me-txt', [this.meName, this.meSub])]),
      el('div', 'c-goal', [el('div', { cls: 'c-goal-eyebrow', text: 'Objetivo' }), this.goalText, this.goalStatus]),
      this.connPill,
      this.pause,
    ]);

    // ----- Joystick -----
    const zone = el('div', { cls: 'c-zone', attrs: { 'aria-label': 'Zona del joystick: apoyá el dedo y arrastrá' } }, [
      el('div', 'c-zone-hint', [el('div', 'c-ghost'), el('b', { text: 'Apoyá el dedo para caminar' }), el('span', { text: 'Sacalo fuera del aro para correr' })]),
    ]);
    this.stick = new FloatingStick(zone, (o) => this.onStick(o));
    this.stick.base.appendChild(el('div', 'c-run', [glyph('run', 18), el('span', { text: '¡Corriendo!' })]));

    // ----- Botones -----
    this.toolState = el('span', { cls: 'c-onoff', text: 'OFF' });
    this.inspect = el('button', { cls: 'c-round', attrs: { type: 'button', 'aria-label': 'Revisar lo que tenés cerca' } }, [
      el('span', 'c-circle', [icon('search', 40)]), el('span', { cls: 'c-cap', text: 'Revisar' }),
    ]);
    this.tool = el('button', { cls: 'c-round', attrs: { type: 'button', 'aria-label': 'Sacar o guardar el multímetro', 'aria-pressed': 'false' } }, [
      el('span', 'c-circle', [icon('meter', 40)]), el('span', { cls: 'c-cap', text: 'Multímetro' }), this.toolState,
    ]);
    this.actLabel = el('span', { text: '¡Listo!' });
    this.act = el('button', { cls: 'c-act is-idle', attrs: { type: 'button' } }, [this.actLabel]);
    const btns = el('div', 'c-btns', [el('div', 'c-col', [this.tool, this.inspect]), this.act]);

    this.toastHost = el('div');
    this.over = el('div', { cls: 'c-over', attrs: { role: 'dialog', 'aria-modal': 'true' } });
    const rotate = el('div', 'c-rotate', [glyph('rotate', 120), el('h2', { cls: 'c-h', text: 'Girá la tablet' }), el('p', { cls: 'c-p', text: 'El control se usa en horizontal, con las dos manos.' })]);

    this.root = el('div', 'c-app', [el('div', 'c-edge'), top, el('main', 'c-pad', [zone, btns]), this.toastHost, this.over, rotate]);
    host.appendChild(this.root);

    this.bindPress(this.act, 'action', () => !this.act.disabled);
    this.bindPress(this.inspect, 'inspect', () => !this.inspect.disabled);
    this.bindPress(this.tool, 'tool', () => !this.tool.disabled, () => {
      this.toolOptimistic = !(this.toolOptimistic ?? this.ctx?.toolOn ?? false);
      this.renderTool();
    });
    this.bindPress(this.pause, 'pause', () => this.screen === 'play');

    this.conn = new Connection({
      url: wsUrl(),
      name: this.name,
      device: isApp() ? 'app' : 'browser',
      token,
      onToken: (t) => { store.set(K_TOKEN, t, true); store.set(K_TOKEN, t); },
      onMessage: (m) => this.onServer(m),
      onState: (s) => this.onConnState(s),
    });

    // Primer toque: pantalla completa (requiere gesto del usuario). En la app ya es completa.
    if (!isApp()) document.addEventListener('pointerdown', () => goFullscreen(), { once: true, capture: true });
    document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && this.conn.isOpen) void keepAwake(); });

    setInterval(() => this.tick(), SEND_TICK_MS);
    setInterval(() => this.slowTick(), 250);

    this.renderHeader();
    // Si ya tenía nombre y token (recarga de la página), entra directo a recuperar su lugar.
    if (this.name && token) this.join(); else this.setScreen('name');
  }

  /* ---------------- Flujo ---------------- */

  private join(): void {
    this.name = sanitizeName(this.name) || 'Jugador';
    store.set(K_NAME, this.name);
    this.conn.setName(this.name);
    this.renderHeader();
    this.conn.start();
  }

  private onConnState(s: ConnState): void {
    switch (s.k) {
      case 'idle': if (this.screen !== 'name') this.setScreen('name'); break;
      case 'connecting': if (this.screen !== 'retrying' && this.screen !== 'full') this.setScreen('connecting'); break;
      case 'open':
        this.model.newConnection();
        void keepAwake();
        this.applyCtxScreen();
        break;
      case 'retrying': this.stick.reset(); this.setScreen('retrying'); break;
      case 'full': this.setScreen('full'); break;
      case 'kicked': this.stick.reset(); this.setScreen('kicked'); break;
    }
    this.renderConn();
    this.renderOverlay(true);
  }

  private onServer(m: ServerMsg): void {
    switch (m.t) {
      case 'welcome':
        this.me = { slot: m.slot, color: m.color, colorName: m.colorName, tvName: m.tvName };
        document.documentElement.style.setProperty('--pc', m.color);
        this.renderHeader();
        if (m.resumed) this.showToast('¡Volviste! Recuperaste tu lugar', 'good');
        vibrate([30]);
        break;
      case 'ctx':
        this.ctx = m.c;
        this.toolOptimistic = null;
        this.renderCtx();
        if (this.conn.isOpen) this.applyCtxScreen();
        break;
      case 'haptic': vibrate(m.pattern); break;
      case 'toast': this.showToast(m.text, m.kind); break;
      case 'kick': store.set(K_TOKEN, null, true); store.set(K_TOKEN, null); break;
      default: break;
    }
  }

  private applyCtxScreen(): void {
    const s = this.ctx?.screen ?? 'lobby';
    const next: Screen = s === 'lobby' || s === 'menu' ? 'lobby' : s === 'paused' ? 'paused' : 'play';
    if (next !== 'play') this.stick.reset();
    this.setScreen(next);
  }

  private setScreen(s: Screen): void {
    if (this.screen === s && this.over.childNodes.length) return;
    this.screen = s;
    this.root.dataset.screen = s;
    this.renderOverlay(true);
  }

  /* ---------------- Entrada ---------------- */

  private onStick(o: StickOutput): void {
    if (this.screen !== 'play') { this.model.setStick(0, 0); this.model.setHeld(0); return; }
    const wasRun = (this.lastHeld & BTN.RUN) !== 0;
    this.model.setStick(o.x, o.y);
    this.lastHeld = o.run ? BTN.RUN : 0;
    this.model.setHeld(this.lastHeld);
    if (o.run && !wasRun) vibrate(12);
  }
  private lastHeld = 0;

  /** Botón táctil: cuenta el toque en pointerdown (respuesta inmediata) y anima mientras se aprieta. */
  private bindPress(b: HTMLButtonElement, key: TapKey, can: () => boolean, after?: () => void): void {
    const ids = new Set<number>();
    const release = (e: PointerEvent): void => { ids.delete(e.pointerId); if (ids.size === 0) b.classList.remove('is-down'); };
    b.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      if (!can()) return;
      ids.add(e.pointerId);
      b.classList.add('is-down');
      this.pressed(key);
      after?.();
      if (key === 'action') {
        b.classList.remove('is-pulse');
        void b.offsetWidth;
        b.classList.add('is-pulse');
      }
    });
    b.addEventListener('pointerup', release);
    b.addEventListener('pointercancel', release);
    b.addEventListener('pointerleave', release);
    // Teclado / accesibilidad (Enter o Espacio sobre el botón enfocado).
    b.addEventListener('click', (e) => { if (e.detail === 0 && can()) { this.pressed(key); after?.(); } });
  }

  private pressed(key: TapKey): void {
    this.model.tap(key);
    vibrate(key === 'action' ? 18 : 10);
    this.flush();
  }

  private tick(): void {
    if (!this.conn.isOpen) return;
    const now = performance.now();
    if (this.model.shouldSend(now)) this.conn.sendInput(this.model.take(now));
  }

  private flush(): void {
    if (this.conn.isOpen) this.conn.sendInput(this.model.take(performance.now()));
  }

  private slowTick(): void {
    this.renderConn();
    if (this.screen === 'retrying' || this.screen === 'full') this.renderOverlay(false);
  }

  /* ---------------- Render ---------------- */

  private renderHeader(): void {
    setText(this.meName, this.name || 'Jugador');
    setText(this.meAva, this.me ? String(this.me.slot + 1) : '?');
    setText(this.meSub, this.me ? `Jugador ${this.me.slot + 1} · ${this.me.colorName}` : 'Sin lugar todavía');
  }

  private renderConn(): void {
    const s = this.conn.current;
    let q: string, text: string, ic: 'wifi' | 'wifiOff' = 'wifi';
    if (s.k === 'open') {
      const l = this.conn.latencyMs;
      text = l === null ? 'Conectado' : `${l} ms`;
      q = l === null || l < 60 ? 'good' : l < 150 ? 'ok' : 'bad';
    } else if (s.k === 'connecting') { text = 'Conectando'; q = 'ok'; }
    else { text = 'Sin conexión'; q = 'off'; ic = 'wifiOff'; }
    if (this.connPill.dataset.q !== q || this.connPill.dataset.ic !== ic) {
      const g = glyph(ic, 22);
      this.connIcon.replaceWith(g);
      this.connIcon = g;
      this.connPill.dataset.q = q;
      this.connPill.dataset.ic = ic;
    }
    setText(this.connText, text);
  }

  private renderCtx(): void {
    const c = this.ctx;
    if (!c) return;
    setText(this.goalText, c.objective || '—');
    setText(this.goalStatus, c.status ?? '');
    this.goalStatus.hidden = !c.status;
    const label = c.action.label || ' ';
    setText(this.actLabel, label);
    this.act.dataset.len = label.length > 16 ? 'l' : label.length > 10 ? 'm' : 's';
    this.act.classList.toggle('is-idle', c.action.style === 'idle');
    this.act.classList.toggle('is-drop', c.action.style === 'drop');
    this.act.disabled = !c.action.enabled;
    this.act.setAttribute('aria-label', label);
    this.inspect.disabled = !c.inspectEnabled;
    this.tool.disabled = !c.toolEnabled;
    this.renderTool();
    if (this.screen === 'lobby' || this.screen === 'paused') this.renderOverlay(true);
  }

  private renderTool(): void {
    const on = this.toolOptimistic ?? this.ctx?.toolOn ?? false;
    this.tool.classList.toggle('is-on', on);
    this.tool.setAttribute('aria-pressed', String(on));
    setText(this.toolState, on ? 'ON' : 'OFF');
  }

  private showToast(text: string, kind?: 'good' | 'bad' | 'info'): void {
    clear(this.toastHost);
    if (!text) return;
    this.toastHost.appendChild(el('div', { cls: `c-toast${kind === 'good' ? ' is-good' : kind === 'bad' ? ' is-bad' : ''}`, text, attrs: { role: 'status' } }));
    if (this.toastTimer) clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => clear(this.toastHost), 2600);
  }

  /** Dibuja la pantalla de estado. `force` = reconstruir aunque la clave no cambie. */
  private renderOverlay(force: boolean): void {
    const s = this.conn.current;
    const now = performance.now();
    const secs = (at: number): number => Math.max(0, Math.ceil((at - now) / 1000));
    let key = this.screen;
    if (this.screen === 'retrying' && s.k === 'retrying') key += `|${s.attempt}|${secs(s.at)}`;
    if (this.screen === 'retrying' && s.k === 'connecting') key += `|c${s.attempt}`;
    if (this.screen === 'full' && s.k === 'full') key += `|${secs(s.at)}`;
    if (this.screen === 'full' && s.k === 'connecting') key += '|c';
    if (this.screen === 'lobby' || this.screen === 'paused') key += `|${JSON.stringify(this.ctx)}|${this.me?.slot}`;
    if (!force && key === this.overlayKey) return;
    if (key === this.overlayKey && this.over.childNodes.length) return;
    this.overlayKey = key;
    clear(this.over);
    this.over.hidden = this.screen === 'play';
    if (this.screen === 'play') return;
    const card = this.buildCard(s, secs);
    this.over.appendChild(card);
  }

  private buildCard(s: ConnState, secs: (at: number) => number): HTMLElement {
    const tv = this.me?.tvName;
    switch (this.screen) {
      case 'name': {
        const input = el('input', { attrs: { type: 'text', maxlength: 14, autocomplete: 'nickname', autocapitalize: 'words', spellcheck: 'false', enterkeyhint: 'go', 'aria-label': 'Tu nombre', placeholder: 'Tu nombre' } });
        input.value = this.name;
        const go = button('c-btn c-btn-primary', [el('span', { text: 'Entrar' }), icon('next', 26)], () => submit());
        const submit = (): void => {
          const n = sanitizeName(input.value);
          if (!n) { input.focus(); return; }
          this.name = n;
          input.blur();
          this.join();
        };
        const sync = (): void => { go.disabled = !sanitizeName(input.value); };
        input.addEventListener('input', sync);
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
        sync();
        return el('div', 'c-card', [
          el('div', 'c-badge', [icon('helmet', 48)]),
          el('div', { cls: 'c-eyebrow', text: 'Misión Energía · Control' }),
          el('h1', { cls: 'c-h', text: '¿Cómo te llamás?' }),
          el('div', 'c-name', [input, go]),
          el('p', { cls: 'c-small', text: 'Tu nombre aparece en el tele. Máximo 14 letras.' }),
        ]);
      }
      case 'connecting':
        return el('div', 'c-card', [
          el('div', 'c-spin'),
          el('h1', { cls: 'c-h c-dots', text: 'Conectando con el tele' }),
          el('p', { cls: 'c-p', text: 'La tablet y el tele tienen que estar en la misma red Wi-Fi.' }),
        ]);
      case 'retrying': {
        const waiting = s.k === 'retrying' ? secs(s.at) : 0;
        const hadSeat = s.k === 'retrying' ? s.hadSeat : true;
        return el('div', 'c-card', [
          el('div', 'c-badge is-bad', [glyph('wifiOff', 48)]),
          el('h1', { cls: 'c-h', text: 'Se cortó la conexión' }),
          el('p', { cls: 'c-p', text: hadSeat ? 'Tranqui: tu lugar te espera 1 minuto. Reconectamos sola.' : 'No encontramos el tele. Probamos de nuevo sola.' }),
          el('p', { cls: 'c-small', text: s.k === 'connecting' ? `Intentando ahora (intento ${s.attempt})` : `Nuevo intento en ${waiting} s` }),
          el('div', 'c-row', [button('c-btn c-btn-primary', [icon('retry', 26), el('span', { text: 'Reintentar ahora' })], () => this.conn.retryNow())]),
        ]);
      }
      case 'full':
        return el('div', 'c-card', [
          el('div', 'c-badge', [glyph('users', 48)]),
          el('h1', { cls: 'c-h', text: 'El tele está lleno' }),
          el('p', { cls: 'c-p', text: 'Ya hay 2 jugadores. Cuando se libere un lugar entrás solo.' }),
          el('p', { cls: 'c-small', text: s.k === 'full' ? `Volvemos a probar en ${secs(s.at)} s` : 'Probando…' }),
          el('div', 'c-row', [
            button('c-btn c-btn-primary', [icon('retry', 26), el('span', { text: 'Probar ahora' })], () => this.conn.retryNow()),
            button('c-btn c-btn-secondary', [el('span', { text: 'Cambiar nombre' })], () => { this.conn.stop(); this.setScreen('name'); }),
          ]),
        ]);
      case 'kicked':
        return el('div', 'c-card', [
          el('div', 'c-badge is-bad', [glyph('exit', 48)]),
          el('h1', { cls: 'c-h', text: 'Saliste del juego' }),
          el('p', { cls: 'c-p', text: s.k === 'kicked' ? s.reason : 'El tele cerró tu lugar' }),
          el('div', 'c-row', [button('c-btn c-btn-primary', [el('span', { text: 'Volver a entrar' })], () => this.join())]),
        ]);
      case 'lobby': {
        const c = this.ctx;
        const ready = c && c.action.enabled;
        const readyBtn = ready ? button('c-btn c-btn-primary c-btn-big', [el('span', { text: c!.action.label || '¡Listo!' })], () => this.pressed('action')) : null;
        return el('div', 'c-card is-wide', [
          el('div', { cls: 'c-badge is-me', text: this.me ? String(this.me.slot + 1) : '?' }),
          el('div', 'c-card-col', [
            el('div', { cls: 'c-eyebrow', text: this.me ? `Jugador ${this.me.slot + 1} · ${this.me.colorName}` : 'Conectado' }),
            el('h1', { cls: 'c-h', text: `¡Listo, ${this.name}!` }),
            el('p', { cls: 'c-p', text: c?.objective || 'Mirá el tele: la partida empieza en un momento' }),
            tv ? el('div', 'c-tv', [glyph('tv', 20), el('span', { text: tv })]) : null,
            readyBtn,
          ]),
        ]);
      }
      case 'paused':
        return el('div', 'c-card', [
          el('div', 'c-badge', [icon('pause', 48)]),
          el('h1', { cls: 'c-h', text: 'Juego en pausa' }),
          el('p', { cls: 'c-p', text: this.ctx?.objective || 'Cuando estén listos, sigan jugando.' }),
          el('div', 'c-row', [
            button('c-btn c-btn-primary c-btn-big', [icon('play', 30), el('span', { text: 'Seguir' })], () => this.pressed('pause')),
            button('c-btn c-btn-secondary', [glyph('exit', 24), el('span', { text: 'Salir del juego' })], () => { this.conn.leave(); store.set(K_TOKEN, null, true); store.set(K_TOKEN, null); this.me = null; this.renderHeader(); this.setScreen('name'); }),
          ]),
        ]);
      default:
        return el('div');
    }
  }
}
