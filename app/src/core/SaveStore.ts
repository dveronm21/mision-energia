import type { ISaveStore } from '../contracts';

/** Subconjunto de la Web Storage API que usamos (permite inyectar un falso en tests). */
export interface KeyValueStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
  key(index: number): string | null;
  readonly length: number;
}

/** Devuelve localStorage si existe y es usable; si no, null (node, modo privado, WebView sin storage). */
export function detectLocalStorage(): KeyValueStorage | null {
  try {
    const ls = (globalThis as { localStorage?: KeyValueStorage }).localStorage;
    if (!ls) return null;
    const probe = '__me_probe__';
    ls.setItem(probe, '1');
    ls.removeItem(probe);
    return ls;
  } catch {
    return null;
  }
}

/**
 * Persistencia JSON con prefijo de versión ("me.v1."). Siempre mantiene una copia en memoria:
 * si localStorage falla (cuota, permisos) o no existe, el juego sigue andando durante la sesión.
 */
export class SaveStore implements ISaveStore {
  private readonly memory = new Map<string, string>();

  constructor(
    private readonly storage: KeyValueStorage | null = detectLocalStorage(),
    private readonly prefix = 'me.v1.',
  ) {}

  load<T>(key: string, fallback: T): T {
    const k = this.prefix + key;
    let raw: string | null = null;
    if (this.storage) {
      try { raw = this.storage.getItem(k); } catch { raw = null; }
    }
    if (raw === null) raw = this.memory.get(k) ?? null;
    if (raw === null) return fallback;
    try { return JSON.parse(raw) as T; } catch { return fallback; }
  }

  save<T>(key: string, value: T): void {
    const k = this.prefix + key;
    const raw = JSON.stringify(value);
    this.memory.set(k, raw);
    if (!this.storage) return;
    try { this.storage.setItem(k, raw); } catch { /* respaldo en memoria */ }
  }

  clearAll(): void {
    this.memory.clear();
    if (!this.storage) return;
    try {
      const keys: string[] = [];
      for (let i = 0; i < this.storage.length; i++) {
        const k = this.storage.key(i);
        if (k && k.startsWith(this.prefix)) keys.push(k);
      }
      keys.forEach((k) => this.storage!.removeItem(k));
    } catch { /* nada */ }
  }
}
