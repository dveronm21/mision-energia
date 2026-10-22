import type { BridgeEvent, NativeRemoteBridge } from './protocol';

/**
 * Puente de PRUEBA para correr el lado tele en un navegador común contra un servidor de
 * desarrollo (e2e/remote-e2e.mjs) que hace lo mismo que el servidor Java: acepta los WebSocket
 * de las tablets y reenvía todo por un WebSocket de "relay".
 *
 * Relay (JSON por mensaje):
 *   servidor → tele: BridgeEvent ({e:'open'|'msg'|'close', id, ...})
 *   tele → servidor: {cmd:'send', id, json} | {cmd:'close', id, reason}
 */
export class WsRelayBridge implements NativeRemoteBridge {
  private queue: BridgeEvent[] = [];
  private outbox: string[] = [];
  private ws: WebSocket | null = null;

  constructor(private readonly relayUrl: string, private readonly controllerUrl: string, private readonly tvName = 'Tele de prueba') {
    this.open();
  }

  getControllerUrl(): string { return this.controllerUrl; }
  getTvName(): string { return this.tvName; }

  poll(): string {
    const out = JSON.stringify(this.queue);
    this.queue = [];
    return out;
  }

  send(connId: number, json: string): void { this.post(JSON.stringify({ cmd: 'send', id: connId, json })); }
  close(connId: number, reason: string): void { this.post(JSON.stringify({ cmd: 'close', id: connId, reason })); }

  private post(s: string): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) this.ws.send(s);
    else this.outbox.push(s);
  }

  private open(): void {
    const ws = new WebSocket(this.relayUrl);
    this.ws = ws;
    ws.onopen = () => { for (const s of this.outbox.splice(0)) ws.send(s); };
    ws.onmessage = (ev) => {
      try { this.queue.push(JSON.parse(String(ev.data)) as BridgeEvent); } catch { /* ignorar */ }
    };
    ws.onclose = () => { setTimeout(() => this.open(), 500); };
  }
}
