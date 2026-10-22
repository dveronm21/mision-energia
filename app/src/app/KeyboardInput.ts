/** Teclado (escritorio y pruebas): WASD/flechas para caminar, E/Espacio acción, R revisar, M multímetro, Esc atrás. */
export interface KeyboardHandlers {
  onAction(): void;
  onInspect(): void;
  onMeter(): void;
  onBack(): void;
}

export class KeyboardInput {
  private readonly keys = new Set<string>();

  constructor(private readonly h: KeyboardHandlers) {
    window.addEventListener('keydown', this.down);
    window.addEventListener('keyup', this.up);
    window.addEventListener('blur', this.clear);
  }

  vector(): { x: number; y: number } {
    const k = this.keys;
    let x = 0, y = 0;
    if (k.has('a') || k.has('arrowleft')) x -= 1;
    if (k.has('d') || k.has('arrowright')) x += 1;
    if (k.has('w') || k.has('arrowup')) y -= 1;
    if (k.has('s') || k.has('arrowdown')) y += 1;
    return { x, y };
  }

  private down = (e: KeyboardEvent): void => {
    const t = e.target as HTMLElement | null;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) return;
    const k = e.key.toLowerCase();
    this.keys.add(k);
    if (e.repeat) return;
    if (k === 'e' || k === ' ') { e.preventDefault(); this.h.onAction(); }
    else if (k === 'r') this.h.onInspect();
    else if (k === 'm') this.h.onMeter();
    else if (k === 'escape') this.h.onBack();
  };

  private up = (e: KeyboardEvent): void => { this.keys.delete(e.key.toLowerCase()); };
  private clear = (): void => { this.keys.clear(); };
}
