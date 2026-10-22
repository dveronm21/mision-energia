export type Dir = 'left' | 'right' | 'up' | 'down';

const FOCUSABLE = 'button:not(:disabled), [href], input:not(:disabled), [tabindex]:not([tabindex="-1"])';

function visible(e: HTMLElement): boolean {
  if (e.closest('[hidden]')) return false;
  const r = e.getBoundingClientRect();
  return r.width > 0 && r.height > 0;
}

/**
 * Navegación espacial para D-pad: mueve el foco al elemento más cercano en la dirección pedida
 * (distancia en el eje principal + penalización por desvío lateral). Devuelve el nuevo foco.
 */
export function moveFocus(root: ParentNode, dir: Dir): HTMLElement | null {
  const items = Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(visible);
  if (items.length === 0) return null;
  const cur = document.activeElement as HTMLElement | null;
  if (!cur || !items.includes(cur)) { items[0].focus(); return items[0]; }
  const a = cur.getBoundingClientRect();
  const ax = a.left + a.width / 2, ay = a.top + a.height / 2;
  let best: HTMLElement | null = null, bestScore = Infinity;
  for (const it of items) {
    if (it === cur) continue;
    const b = it.getBoundingClientRect();
    const bx = b.left + b.width / 2, by = b.top + b.height / 2;
    const dx = bx - ax, dy = by - ay;
    let main: number, side: number;
    switch (dir) {
      case 'right': if (b.left < a.right - 4) continue; main = dx; side = Math.abs(dy); break;
      case 'left': if (b.right > a.left + 4) continue; main = -dx; side = Math.abs(dy); break;
      case 'down': if (b.top < a.bottom - 4) continue; main = dy; side = Math.abs(dx); break;
      case 'up': if (b.bottom > a.top + 4) continue; main = -dy; side = Math.abs(dx); break;
    }
    const score = main + side * 2;
    if (score < bestScore) { bestScore = score; best = it; }
  }
  best?.focus({ preventScroll: true });
  return best;
}
