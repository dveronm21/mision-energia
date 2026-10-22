import type { LevelEvents, LoadBlock } from '../contracts';

/** Funciones físicas puras y didácticas compartidas por el simulador, el clima y los tests. */

/** Hora del día 0..24 a partir de una hora de juego (puede ser > 24). */
export function dayHour(hour: number): number {
  return ((hour % 24) + 24) % 24;
}

/** Elevación solar normalizada 0..1: sale 6:30, pico ~13:15, se pone 20:00. */
export function sunFactor(hour: number): number {
  return Math.max(0, Math.sin(Math.PI * (dayHour(hour) - 6.5) / 13.5));
}

/** Factor de irradiancia por nubes (0..1). Las franjas usan horas de juego (sin módulo). Si se superponen, gana la más oscura. */
export function cloudFactor(clouds: LevelEvents['clouds'], hour: number): number {
  let f = 1;
  for (const c of clouds) if (hour >= c.from && hour < c.to) f = Math.min(f, c.factor);
  return f;
}

/** ¿La franja de consumo está activa a esa hora? Soporta franjas que cruzan medianoche (from > to). */
export function blockActive(b: LoadBlock, hour: number): boolean {
  const x = dayHour(hour);
  return b.from <= b.to ? x >= b.from && x < b.to : x >= b.from || x < b.to;
}

/** Consumo total en kW a esa hora, sin las cargas apagadas por el jugador. */
export function loadKw(loads: LoadBlock[], hour: number, shed: readonly string[] = []): number {
  let kw = 0;
  for (const b of loads) if (!shed.includes(b.label) && blockActive(b, hour)) kw += b.kw;
  return kw;
}
