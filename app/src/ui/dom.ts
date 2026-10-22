/**
 * Helpers de DOM seguros: todo el texto entra por textContent, nunca por innerHTML.
 */

export type Child = Node | string | number | null | undefined | false;

export interface ElProps {
  cls?: string;
  text?: string;
  attrs?: Record<string, string | number | boolean | undefined>;
  on?: { [K in keyof HTMLElementEventMap]?: (ev: HTMLElementEventMap[K]) => void };
  hidden?: boolean;
}

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: ElProps | string = {},
  children: Child[] = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  const p: ElProps = typeof props === 'string' ? { cls: props } : props;
  if (p.cls) node.className = p.cls;
  if (p.text !== undefined) node.textContent = p.text;
  if (p.attrs) {
    for (const [k, v] of Object.entries(p.attrs)) {
      if (v === undefined || v === false) continue;
      node.setAttribute(k, v === true ? '' : String(v));
    }
  }
  if (p.hidden) node.hidden = true;
  if (p.on) {
    for (const [ev, fn] of Object.entries(p.on)) {
      if (fn) node.addEventListener(ev, fn as EventListener);
    }
  }
  append(node, children);
  return node;
}

export function append(parent: Node, children: Child[]): void {
  for (const c of children) {
    if (c === null || c === undefined || c === false) continue;
    parent.appendChild(typeof c === 'string' || typeof c === 'number' ? document.createTextNode(String(c)) : c);
  }
}

/** Botón accesible (type="button" siempre). */
export function button(
  cls: string,
  children: Child[],
  onClick: (ev: MouseEvent) => void,
  attrs: Record<string, string | number | boolean | undefined> = {},
): HTMLButtonElement {
  return el('button', { cls, attrs: { type: 'button', ...attrs }, on: { click: onClick } }, children);
}

export function clear(node: Node): void {
  while (node.firstChild) node.removeChild(node.firstChild);
}

export function setText(node: Node, text: string): void {
  if (node.textContent !== text) node.textContent = text;
}

export function prefersReducedMotion(): boolean {
  try {
    return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch {
    return false;
  }
}
