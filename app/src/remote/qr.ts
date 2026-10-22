import qrcode from 'qrcode-generator';

const NS = 'http://www.w3.org/2000/svg';

/** Matriz de módulos del QR (true = oscuro). Corrección 'M': aguanta reflejos en la pantalla del tele. */
export function qrMatrix(text: string, ecc: 'L' | 'M' | 'Q' | 'H' = 'M'): boolean[][] {
  const qr = qrcode(0, ecc);
  qr.addData(text, 'Byte');
  qr.make();
  const n = qr.getModuleCount();
  const rows: boolean[][] = [];
  for (let r = 0; r < n; r++) {
    const row: boolean[] = [];
    for (let c = 0; c < n; c++) row.push(qr.isDark(r, c));
    rows.push(row);
  }
  return rows;
}

/**
 * QR como SVG escalable (un solo <path>, sin innerHTML). `quiet` = margen en módulos (4 = estándar).
 * Se dibuja nítido a cualquier tamaño: `shape-rendering: crispEdges`.
 */
export function qrSvg(text: string, opts: { quiet?: number; dark?: string; light?: string; label?: string } = {}): SVGSVGElement {
  const m = qrMatrix(text);
  const q = opts.quiet ?? 4;
  const size = m.length + q * 2;
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', `0 0 ${size} ${size}`);
  svg.setAttribute('shape-rendering', 'crispEdges');
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label', opts.label ?? `Código QR: ${text}`);
  const bg = document.createElementNS(NS, 'rect');
  bg.setAttribute('width', String(size));
  bg.setAttribute('height', String(size));
  bg.setAttribute('fill', opts.light ?? '#FFFFFF');
  svg.appendChild(bg);
  let d = '';
  for (let r = 0; r < m.length; r++) {
    let c = 0;
    while (c < m.length) {
      if (!m[r][c]) { c++; continue; }
      const start = c;
      while (c < m.length && m[r][c]) c++;
      d += `M${start + q} ${r + q}h${c - start}v1h${start - c}z`;
    }
  }
  const path = document.createElementNS(NS, 'path');
  path.setAttribute('d', d);
  path.setAttribute('fill', opts.dark ?? '#0E2420');
  svg.appendChild(path);
  return svg;
}
