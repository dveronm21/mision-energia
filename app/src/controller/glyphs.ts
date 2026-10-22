/** Íconos extra del control (mismo estilo de trazo que src/ui/icons.ts). */
const NS = 'http://www.w3.org/2000/svg';

const GLYPHS = {
  wifi: ['M2.5 9a14 14 0 0 1 19 0', 'M5.5 12.5a9.5 9.5 0 0 1 13 0', 'M8.7 16a5 5 0 0 1 6.6 0', 'M12 19.6h.01'],
  wifiOff: ['M2.5 9a14 14 0 0 1 19 0', 'M5.5 12.5a9.5 9.5 0 0 1 13 0', 'M8.7 16a5 5 0 0 1 6.6 0', 'M12 19.6h.01', 'M4 3.5l16 17'],
  tv: ['M3 5.5h18v11H3z', 'M8 20.5h8', 'M12 16.5v4'],
  users: ['M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z', 'M2.5 20a6.5 6.5 0 0 1 13 0', 'M16 4.3a3.5 3.5 0 0 1 0 6.4', 'M18 14a6.5 6.5 0 0 1 3.5 6'],
  rotate: ['M7 3.5h6a1.5 1.5 0 0 1 1.5 1.5v14a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z', 'M17 4.5a8 8 0 0 1 4 7', 'M18.8 9.8l2.2 1.9 1.6-2.5'],
  exit: ['M14 4.5h4.5v15H14', 'M10 8l-4 4 4 4', 'M6 12h10'],
  run: ['M15.3 4.6a1.8 1.8 0 1 1-3.6 0 1.8 1.8 0 1 1 3.6 0', 'M9 21l2.5-5.5 3 2.5V22', 'M6.5 12.5l2.5-4 4 .5 2.5 3.5 3 1', 'M11.5 15.5l1-6'],
} as const;

export type GlyphName = keyof typeof GLYPHS;

export function glyph(name: GlyphName, size = 24, cls = ''): SVGSVGElement {
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', String(size));
  svg.setAttribute('height', String(size));
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2.2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('focusable', 'false');
  svg.setAttribute('class', `ic ${cls}`.trim());
  for (const d of GLYPHS[name]) {
    const p = document.createElementNS(NS, 'path');
    p.setAttribute('d', d);
    svg.appendChild(p);
  }
  return svg;
}
