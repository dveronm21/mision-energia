/** Formatos en español rioplatense (es-AR). */

const nf0 = safeNf({ maximumFractionDigits: 0 });
const nf1 = safeNf({ minimumFractionDigits: 1, maximumFractionDigits: 1 });

function safeNf(o: Intl.NumberFormatOptions): (n: number) => string {
  try {
    const f = new Intl.NumberFormat('es-AR', o);
    return (n) => f.format(n);
  } catch {
    return (n) => (o.maximumFractionDigits === 0 ? String(Math.round(n)) : n.toFixed(1).replace('.', ','));
  }
}

export const fmtInt = (n: number): string => nf0(Math.round(n));
export const fmt1 = (n: number): string => nf1(n);
export const fmtKw = (n: number): string => `${fmt1(Math.max(0, n))} kW`;
export const fmtKwh = (n: number): string => `${fmt1(Math.max(0, n))} kWh`;
export const fmtPct = (p: number): string => `${Math.round(Math.max(0, Math.min(1, p)) * 100)}%`;

/** 10.5 → "10:30"; 30 → "06:00". */
export function fmtHour(hour: number): string {
  const h = ((hour % 24) + 24) % 24;
  let hh = Math.floor(h);
  let mm = Math.round((h - hh) * 60);
  if (mm === 60) { mm = 0; hh = (hh + 1) % 24; }
  return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}

/** 75 → "1:15". */
export function fmtClock(sec: number): string {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export function fmtMoney(cents: number, currency: 'ARS' | 'USD' = 'ARS'): string {
  try {
    return new Intl.NumberFormat('es-AR', {
      style: 'currency', currency, minimumFractionDigits: currency === 'USD' ? 2 : 0, maximumFractionDigits: 2,
    }).format(cents / 100);
  } catch {
    return `${currency === 'USD' ? 'US$' : '$'} ${(cents / 100).toFixed(2)}`;
  }
}
