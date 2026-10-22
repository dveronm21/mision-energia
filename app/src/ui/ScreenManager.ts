import { prefersReducedMotion } from './dom';
import type { UiScreen } from './types';

const ANIM_MS = 180;

/**
 * Pila de pantallas. Las pantallas "página" ocultan a las de abajo; las modales se superponen.
 * Transiciones cortas (fade + desplazamiento leve) que se desactivan con prefers-reduced-motion.
 */
export class ScreenManager {
  private readonly stack: UiScreen[] = [];
  private readonly listeners = new Set<(top: UiScreen | null) => void>();

  constructor(private readonly host: HTMLElement, private readonly reducedMotion: () => boolean = prefersReducedMotion) {}

  get size(): number { return this.stack.length; }
  top(): UiScreen | null { return this.stack[this.stack.length - 1] ?? null; }
  has(s: UiScreen): boolean { return this.stack.includes(s); }

  push(s: UiScreen): void {
    const prev = this.top();
    prev?.onLeave?.();
    this.stack.push(s);
    s.root.classList.add('scr', s.modal ? 'scr-modal' : 'scr-page');
    s.root.hidden = false;
    this.host.appendChild(s.root);
    this.animateIn(s.root);
    this.syncVisibility();
    s.onEnter?.();
    this.focusFirst(s.root);
    this.emit();
  }

  /** Quita la pantalla de arriba. */
  pop(): UiScreen | null {
    const s = this.stack.pop() ?? null;
    if (!s) return null;
    s.onLeave?.();
    this.detach(s);
    this.syncVisibility();
    const top = this.top();
    top?.onEnter?.();
    this.emit();
    return s;
  }

  /** Quita una pantalla concreta (esté donde esté). */
  remove(s: UiScreen): void {
    if (this.top() === s) { this.pop(); return; }
    const i = this.stack.indexOf(s);
    if (i < 0) return;
    this.stack.splice(i, 1);
    this.detach(s);
    this.syncVisibility();
    this.emit();
  }

  /** Reemplaza la pantalla de arriba. */
  replace(s: UiScreen): void {
    const old = this.stack.pop();
    if (old) { old.onLeave?.(); this.detach(old, true); }
    this.push(s);
  }

  /** Vacía la pila y opcionalmente apila una nueva. */
  reset(s?: UiScreen): void {
    while (this.stack.length) {
      const old = this.stack.pop()!;
      old.onLeave?.();
      this.detach(old, true);
    }
    if (s) this.push(s); else { this.syncVisibility(); this.emit(); }
  }

  /** Botón atrás de Android. Devuelve true si alguna pantalla lo consumió. */
  handleBack(): boolean {
    const top = this.top();
    if (!top) return false;
    if (top.onBack) return top.onBack();
    return false;
  }

  onChange(cb: (top: UiScreen | null) => void): () => void {
    this.listeners.add(cb);
    return () => this.listeners.delete(cb);
  }

  private emit(): void { const t = this.top(); this.listeners.forEach((cb) => cb(t)); }

  private syncVisibility(): void {
    // Visible: desde la última página hacia arriba (las modales dejan ver lo de abajo).
    let lastPage = -1;
    for (let i = this.stack.length - 1; i >= 0; i--) if (!this.stack[i].modal) { lastPage = i; break; }
    this.stack.forEach((s, i) => {
      s.root.hidden = i < lastPage;
      s.root.inert = i !== this.stack.length - 1;
      if (i !== this.stack.length - 1) s.root.setAttribute('aria-hidden', 'true');
      else s.root.removeAttribute('aria-hidden');
    });
  }

  private animateIn(node: HTMLElement): void {
    if (this.reducedMotion()) return;
    node.classList.remove('scr-out');
    node.classList.add('scr-in');
    window.setTimeout(() => node.classList.remove('scr-in'), ANIM_MS + 40);
  }

  private detach(s: UiScreen, immediate = false): void {
    const node = s.root;
    const done = (): void => {
      node.classList.remove('scr-out');
      if (node.parentNode === this.host) this.host.removeChild(node);
      s.dispose?.();
    };
    if (immediate || this.reducedMotion()) { done(); return; }
    node.inert = true;
    node.classList.remove('scr-in');
    node.classList.add('scr-out');
    window.setTimeout(done, ANIM_MS);
  }

  private focusFirst(root: HTMLElement): void {
    const target = root.querySelector<HTMLElement>('[data-autofocus]');
    if (target) { try { target.focus({ preventScroll: true }); } catch { /* sin foco */ } }
  }
}
