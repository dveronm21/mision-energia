/**
 * Capacidades del dispositivo con degradación silenciosa: almacenamiento, vibración,
 * Wake Lock, pantalla completa y orientación. Nada de esto puede romper la página.
 */

type HapticsBridge = { vibrate(patternJson: string): void };

export const store = {
  get(key: string, session = false): string | null {
    try { return (session ? sessionStorage : localStorage).getItem(key); } catch { return null; }
  },
  set(key: string, value: string | null, session = false): void {
    try {
      const s = session ? sessionStorage : localStorage;
      if (value === null) s.removeItem(key); else s.setItem(key, value);
    } catch { /* modo privado o bloqueado */ }
  },
};

/**
 * Vibra con un patrón estilo navigator.vibrate. Dentro de la app Control (WebView) usa
 * `window.Haptics.vibrate(json)` que inyecta Java, porque el WebView suele ignorar
 * navigator.vibrate; en un navegador usa navigator.vibrate y, si no existe, Haptics.
 */
export function vibrate(pattern: number[] | number): void {
  const p = Array.isArray(pattern) ? pattern : [pattern];
  const w = window as unknown as { Haptics?: HapticsBridge };
  const viaBridge = (): boolean => {
    try { if (w.Haptics && typeof w.Haptics.vibrate === 'function') { w.Haptics.vibrate(JSON.stringify(p)); return true; } } catch { /* */ }
    return false;
  };
  if (isApp() && viaBridge()) return;
  try {
    if (typeof navigator.vibrate === 'function' && navigator.vibrate(p)) return;
  } catch { /* */ }
  viaBridge();
}

export function isApp(): boolean {
  try { return new URLSearchParams(location.search).get('app') === '1'; } catch { return false; }
}

let wakeLock: { release(): Promise<void>; released?: boolean } | null = null;
export async function keepAwake(): Promise<void> {
  const nav = navigator as unknown as { wakeLock?: { request(t: 'screen'): Promise<{ release(): Promise<void>; released?: boolean }> } };
  if (!nav.wakeLock || document.visibilityState !== 'visible') return;
  if (wakeLock && !wakeLock.released) return;
  try { wakeLock = await nav.wakeLock.request('screen'); } catch { wakeLock = null; }
}

/** Pantalla completa + bloqueo horizontal (se llama en el primer toque: requiere gesto). */
export function goFullscreen(): void {
  const d = document as Document & { webkitFullscreenElement?: Element };
  if (d.fullscreenElement || d.webkitFullscreenElement) return;
  const el = document.documentElement as HTMLElement & { webkitRequestFullscreen?: () => void };
  try {
    const p = el.requestFullscreen ? el.requestFullscreen({ navigationUI: 'hide' }) : (el.webkitRequestFullscreen?.(), undefined);
    Promise.resolve(p).then(() => {
      const o = screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> };
      return o?.lock?.('landscape');
    }).catch(() => { /* no permitido */ });
  } catch { /* */ }
}

/** Evita zoom por gestos y doble toque, menú contextual y scroll elástico. */
export function lockGestures(): void {
  const stop = (e: Event): void => { if (e.cancelable) e.preventDefault(); };
  for (const ev of ['gesturestart', 'gesturechange', 'gestureend', 'contextmenu', 'dblclick']) document.addEventListener(ev, stop, { passive: false });
  document.addEventListener('touchmove', (e) => {
    const t = e.target as HTMLElement | null;
    if (e.cancelable && (!t || !t.closest('input'))) e.preventDefault();
  }, { passive: false });
  document.addEventListener('touchstart', (e) => { if (e.touches.length > 1) { const t = e.target as HTMLElement | null; if (e.cancelable && !t?.closest('input')) e.preventDefault(); } }, { passive: false });
}

export function wsUrl(): string {
  const q = new URLSearchParams(location.search);
  const explicit = q.get('ws');
  if (explicit && /^wss?:\/\/[^\s]+$/.test(explicit)) return explicit;
  const host = q.get('host') || location.host;
  const secure = location.protocol === 'https:';
  return `${secure ? 'wss' : 'ws'}://${host}/ws`;
}
