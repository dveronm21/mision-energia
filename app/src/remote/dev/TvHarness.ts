/**
 * Banco de pruebas del lado tele (NO es parte del juego). Corre RemoteHost + LobbyView y una
 * mini escena 2D para verificar el control sin depender del juego real.
 *
 *   ?relay=ws://host/bridge&url=http://host/   → puente de prueba (e2e/remote-e2e.mjs)
 *   ?fake=2                                    → 2 tablets simuladas en memoria (FakeBridge)
 *   (con window.RemoteBridge inyectado, usa el puente nativo)
 */
import { RemoteHost } from '../RemoteHost';
import { LobbyView } from '../LobbyView';
import { FakeBridge, type FakeClient } from '../FakeBridge';
import { WsRelayBridge } from '../WsRelayBridge';
import { PLAYER_COLORS, type ControllerContext, type NativeRemoteBridge, type PlayerSlot } from '../protocol';

const q = new URLSearchParams(location.search);
let bridge: NativeRemoteBridge | null = (window as unknown as { RemoteBridge?: NativeRemoteBridge }).RemoteBridge ?? null;
const relay = q.get('relay');
if (!bridge && relay) bridge = new WsRelayBridge(relay, q.get('url') ?? '', q.get('tv') ?? 'Tele de prueba');
if (!bridge && q.has('fake')) {
  const fb = new FakeBridge(q.get('url') ?? 'http://192.168.0.23:8765/');
  bridge = fb;
  const names = ['Ana', 'Beto'];
  const n = Math.min(2, Number(q.get('fake')) || 1);
  for (let i = 0; i < n; i++) {
    const c: FakeClient = fb.connect();
    c.hello(names[i]);
    let t = i * 2;
    setInterval(() => { t += 0.1; c.input({ x: Math.cos(t), y: Math.sin(t) }); if (Math.random() < 0.02) c.tap('action'); }, 100);
    setInterval(() => c.ping(performance.now(), 18 + Math.round(Math.random() * 30) + i * 70), 1000);
  }
}

const host = new RemoteHost(bridge);
document.body.style.cssText = 'margin:0;background:#0E2420;overflow:hidden';
const canvas = document.createElement('canvas');
canvas.style.cssText = 'position:fixed;inset:0;width:100%;height:100%';
document.body.appendChild(canvas);
const g = canvas.getContext('2d')!;

const stats = {
  actions: [0, 0], inspects: [0, 0], tools: [0, 0], pauses: [0, 0], maxX: [0, 0], minY: [0, 0],
  joins: 0, resumes: 0, leaves: 0, drops: 0, started: false, paused: false, toolOn: [false, false],
  last: [null, null] as unknown[],
};
host.onJoin(() => stats.joins++);
host.onResume(() => stats.resumes++);
host.onLeave(() => stats.leaves++);
host.onDrop(() => stats.drops++);

const pos = [{ x: 0.3, y: 0.6 }, { x: 0.7, y: 0.6 }];
const labels = ['Tomar panel', 'Colocar panel', 'Conectar cable'];

const lobby = new LobbyView(document.body, host, {
  onStart: () => start(),
  onBack: () => { /* en el juego: volver al menú */ },
});

function ctxFor(slot: PlayerSlot): ControllerContext {
  if (!stats.started) {
    return { action: { label: '¡Listo!', style: 'normal', enabled: true }, inspectEnabled: false, toolOn: false, toolEnabled: false, objective: 'Mirá el tele: la partida empieza en un momento', screen: 'lobby' };
  }
  const n = stats.actions[slot];
  return {
    action: { label: labels[n % labels.length], style: n % 3 === 2 ? 'drop' : 'normal', enabled: true },
    inspectEnabled: true, toolOn: stats.toolOn[slot], toolEnabled: true,
    objective: n < 3 ? 'Colocá los 6 paneles en la estructura' : 'Conectá el inversor a las baterías',
    screen: stats.paused ? 'paused' : 'playing',
    status: `Paneles ${Math.min(6, n)}/6 · Batería ${40 + n * 5}%`,
  };
}

function start(): void {
  stats.started = true;
  lobby.hide();
}

window.addEventListener('keydown', (e) => {
  if (stats.started && e.key === 'Escape') { stats.started = false; lobby.show(); }
});

function frame(): void {
  host.update();
  for (const s of [0, 1] as PlayerSlot[]) {
    const i = host.input(s).read();
    stats.last[s] = i;
    if (!i.connected) { host.setContext(s, ctxFor(s)); continue; }
    stats.maxX[s] = Math.max(stats.maxX[s], i.x);
    stats.minY[s] = Math.min(stats.minY[s], i.y);
    if (stats.started && !stats.paused) {
      const sp = i.run ? 0.012 : 0.006;
      pos[s].x = Math.max(0.05, Math.min(0.95, pos[s].x + i.x * sp));
      pos[s].y = Math.max(0.1, Math.min(0.95, pos[s].y + i.y * sp));
    }
    if (i.action) {
      stats.actions[s]++;
      host.haptic(s, [30, 40, 30]);
      host.toast(s, '¡Panel colocado!', 'good');
    }
    if (i.inspect) { stats.inspects[s]++; host.toast(s, 'Inversor híbrido: OK', 'info'); }
    if (i.tool) { stats.tools[s]++; stats.toolOn[s] = !stats.toolOn[s]; }
    if (i.pause) { stats.pauses[s]++; if (stats.started) stats.paused = !stats.paused; }
    host.setContext(s, ctxFor(s));
  }
  draw();
  requestAnimationFrame(frame);
}

function draw(): void {
  const w = (canvas.width = innerWidth), h = (canvas.height = innerHeight);
  g.fillStyle = '#16302A'; g.fillRect(0, 0, w, h);
  g.fillStyle = '#FFB82E'; g.font = `700 ${Math.round(h * 0.04)}px Fredoka, sans-serif`;
  g.fillText(stats.paused ? 'PAUSA' : 'Banco de pruebas · Modo TV', w * 0.05, h * 0.09);
  host.players().forEach((p, s) => {
    if (!p) return;
    g.globalAlpha = p.connected ? 1 : 0.35;
    g.fillStyle = PLAYER_COLORS[s as PlayerSlot].hex;
    g.beginPath(); g.arc(pos[s].x * w, pos[s].y * h, h * 0.04, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#fff'; g.font = `800 ${Math.round(h * 0.03)}px Nunito, sans-serif`;
    g.fillText(`${p.name} · ${stats.actions[s]} acciones${p.latencyMs !== null ? ` · ${p.latencyMs} ms` : ''}`, pos[s].x * w - h * 0.06, pos[s].y * h - h * 0.06);
    g.globalAlpha = 1;
  });
}

lobby.show();
requestAnimationFrame(frame);
(window as unknown as { __tv: unknown }).__tv = { host, stats, lobby, start };
