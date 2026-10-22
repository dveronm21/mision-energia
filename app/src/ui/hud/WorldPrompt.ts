import { el, setText } from '../dom';

/**
 * Etiqueta que sigue un punto del mundo 3D proyectado a pantalla.
 * main.ts proyecta (Vector3.project) y llama setScreenPosition(px, py) cada cuadro.
 */
export class WorldPrompt {
  readonly root: HTMLDivElement;
  private x = -9999;
  private y = -9999;

  constructor(host: HTMLElement) {
    this.root = el('div', { cls: 'hud-prompt', attrs: { 'aria-hidden': 'true' }, hidden: true });
    host.appendChild(this.root);
  }

  show(text: string): void { setText(this.root, text); this.root.hidden = false; }
  hide(): void { this.root.hidden = true; }

  /** Coordenadas en píxeles CSS de la ventana; visible=false si el punto quedó detrás de la cámara. */
  setScreenPosition(px: number, py: number, visible = true): void {
    if (!visible) { this.root.style.visibility = 'hidden'; return; }
    this.root.style.visibility = '';
    const w = this.root.offsetWidth, h = this.root.offsetHeight;
    const m = 8;
    const cx = Math.max(m + w / 2, Math.min(window.innerWidth - m - w / 2, px));
    const cy = Math.max(m + h, Math.min(window.innerHeight - m, py));
    if (Math.abs(cx - this.x) < 0.5 && Math.abs(cy - this.y) < 0.5) return;
    this.x = cx; this.y = cy;
    this.root.style.transform = `translate(${(cx - w / 2).toFixed(1)}px, ${(cy - h).toFixed(1)}px)`;
  }
}
