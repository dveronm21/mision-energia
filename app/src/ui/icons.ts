/**
 * Set de íconos SVG de trazo propio (viewBox 24×24, stroke = currentColor).
 * Se construyen con createElementNS; no hay markup como texto.
 */

const NS = 'http://www.w3.org/2000/svg';

type Shape =
  | ['path', string]
  | ['fpath', string]                       // path relleno
  | ['circle', number, number, number]
  | ['fcircle', number, number, number]
  | ['rect', number, number, number, number, number?]
  | ['frect', number, number, number, number, number?]
  | ['ellipse', number, number, number, number];

function gearPath(): string {
  const teeth = 8, ro = 9.6, ri = 7.4, cx = 12, cy = 12;
  const pts: string[] = [];
  for (let i = 0; i < teeth * 4; i++) {
    const a = (i / (teeth * 4)) * Math.PI * 2 - Math.PI / 2;
    const r = i % 4 < 2 ? ro : ri;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(2)} ${(cy + Math.sin(a) * r).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

const STAR = 'M12 2.6l2.9 6 6.6.8-4.9 4.5 1.3 6.5L12 17.1l-5.9 3.3 1.3-6.5L2.5 9.4l6.6-.8z';
const SPEAKER = 'M4 9h4l5-4v14l-5-4H4z';

const ICONS = {
  sun: [['circle', 12, 12, 4.5], ['path', 'M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8']],
  soles: [['circle', 12, 12, 9.2], ['fcircle', 12, 12, 3.6], ['path', 'M12 5.6v1.6M12 16.8v1.6M5.6 12h1.6M16.8 12h1.6M7.5 7.5l1.1 1.1M15.4 15.4l1.1 1.1M7.5 16.5l1.1-1.1M15.4 8.6l1.1-1.1']],
  panel: [['path', 'M3 16.5L6 4.5h15l-3 12z'], ['path', 'M4.5 10.5h15M10 4.5l-1.5 12M15.5 4.5l-1.5 12M11.5 16.5v4M8 20.5h7']],
  battery: [['rect', 2.5, 7, 16, 10, 2.2], ['path', 'M21.5 10.2v3.6M6.5 10v4M10 10v4']],
  bolt: [['path', 'M13.5 2L4.5 13.5h6.5L10 22l9.5-12H13z']],
  helmet: [['path', 'M4.5 16a7.5 7.5 0 0 1 15 0'], ['path', 'M2 16h20v2.5H2zM12 8.5v4.5M9 9.3l.7 3.7M15 9.3l-.7 3.7']],
  vest: [['path', 'M8.5 3L4.5 5.5V21h6v-8.5L12 9.5l1.5 3V21h6V5.5L15.5 3 12 8z'], ['path', 'M4.5 15.5h6M13.5 15.5h6']],
  lock: [['rect', 5, 10.5, 14, 10.5, 2.5], ['path', 'M8 10.5V7.5a4 4 0 0 1 8 0v3M12 14.5v2.5']],
  star: [['path', STAR]],
  starFill: [['fpath', STAR]],
  gear: [['path', gearPath()], ['circle', 12, 12, 3]],
  cart: [['path', 'M2.5 4h2.3l2.4 11h11l2.3-8H6'], ['circle', 9, 19.5, 1.6], ['circle', 17, 19.5, 1.6]],
  play: [['fpath', 'M8 4.8v14.4L19.5 12z']],
  pause: [['frect', 6.5, 5, 4, 14, 1], ['frect', 13.5, 5, 4, 14, 1]],
  search: [['circle', 10.5, 10.5, 6.5], ['path', 'M15.5 15.5l5.5 5.5']],
  meter: [['rect', 6, 2, 12, 20, 3], ['rect', 8.5, 5, 7, 4.2, 1], ['circle', 12, 15, 3], ['path', 'M12 15l1.6-1.6']],
  drone: [['rect', 9, 10, 6, 4, 1.2], ['path', 'M9 11L6 8.3M15 11l3-2.7M9 13l-3 2.7M15 13l3 2.7'], ['ellipse', 5.5, 7.5, 3.3, 1.2], ['ellipse', 18.5, 7.5, 3.3, 1.2], ['ellipse', 5.5, 16.5, 3.3, 1.2], ['ellipse', 18.5, 16.5, 3.3, 1.2]],
  hint: [['path', 'M9 18h6M10 21h4M12 3a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.3 1.1 2.2h5c0-.9.4-1.6 1.1-2.2A6 6 0 0 0 12 3z']],
  back: [['path', 'M15 4.5L7.5 12l7.5 7.5']],
  close: [['path', 'M6 6l12 12M18 6L6 18']],
  check: [['path', 'M4.5 12.5l5 5L19.5 7']],
  plus: [['path', 'M12 5v14M5 12h14']],
  minus: [['path', 'M5 12h14']],
  sound: [['path', SPEAKER], ['path', 'M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12']],
  mute: [['path', SPEAKER], ['path', 'M16.5 9.5l5 5M21.5 9.5l-5 5']],
  wind: [['path', 'M3 8h11a3 3 0 1 0-3-3M3 12h16a3 3 0 1 1-3 3M3 16h8']],
  map: [['path', 'M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14']],
  retry: [['path', 'M4.5 12a7.5 7.5 0 1 0 2.2-5.3'], ['path', 'M4.5 3.5v4.5H9']],
  next: [['path', 'M4.5 12h14M13 6l6 6-6 6']],
  gift: [['rect', 3, 8.5, 18, 4.5, 1], ['path', 'M5 13v8h14v-8M12 8.5V21M12 8.5C10 4 6 4.5 6.5 7c.4 1.6 3.5 1.5 5.5 1.5 2 0 5.1.1 5.5-1.5.5-2.5-3.5-3-5.5 1.5']],
  city: [['path', 'M3 21h18M5 21V10.5L10 8v13M10 21V4l9 3.5V21M13 9.5h3M13 13h3M13 16.5h3M7 13h1M7 16.5h1']],
  plug: [['path', 'M9 2.5v4.5M15 2.5v4.5M6.5 7h11v3.5a5.5 5.5 0 0 1-11 0zM12 16v5.5']],
  trophy: [['path', 'M7 4h10v5a5 5 0 0 1-10 0zM7 6H4v1.5A3.5 3.5 0 0 0 7.5 11M17 6h3v1.5a3.5 3.5 0 0 1-3.5 3.5M12 14v4M8 21h8M9.5 18h5']],
  pump: [['path', 'M4 20h16M7 20v-9h6v9M13 14h3.5a2.5 2.5 0 0 0 2.5-2.5V8M17 8h4M10 11V7M8 7h4']],
  cloud: [['path', 'M7 18.5h10.5a4 4 0 0 0 .5-8 6 6 0 0 0-11.5 1.5A3.3 3.3 0 0 0 7 18.5z']],
  loose: [['path', 'M4 12h5M15 12h5M9 8.5v7M15 8.5v7M11.5 10l1-2M11.5 14l1 2']],
} satisfies Record<string, Shape[]>;

export type IconName = keyof typeof ICONS;

export function isIconName(n: string): n is IconName {
  return Object.prototype.hasOwnProperty.call(ICONS, n);
}

/** Alias para ids de íconos que pueda mandar el catálogo de productos. */
const ALIASES: Record<string, IconName> = {
  sol: 'soles', coin: 'soles', token: 'soles', pack: 'soles',
  bulb: 'hint', pista: 'hint', clue: 'hint',
  dron: 'drone', clean: 'drone',
  'battery-emergency': 'battery', emergency: 'battery', bateria: 'battery',
  casco: 'helmet', chaleco: 'vest', shirt: 'vest', unlock: 'lock',
};

export function resolveIcon(id: string): IconName {
  if (isIconName(id)) return id;
  const low = id.toLowerCase();
  if (ALIASES[low]) return ALIASES[low];
  for (const key of Object.keys(ALIASES)) if (low.includes(key)) return ALIASES[key];
  if (low.includes('helmet')) return 'helmet';
  if (low.includes('vest')) return 'vest';
  if (low.includes('drone')) return 'drone';
  if (low.includes('hint')) return 'hint';
  if (low.includes('batt')) return 'battery';
  return 'soles';
}

export function icon(name: IconName, size = 24, cls = ''): SVGSVGElement {
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
  for (const s of ICONS[name] as readonly Shape[]) {
    let n: SVGElement;
    switch (s[0]) {
      case 'path':
      case 'fpath':
        n = document.createElementNS(NS, 'path');
        n.setAttribute('d', s[1]);
        if (s[0] === 'fpath') n.setAttribute('fill', 'currentColor');
        break;
      case 'circle':
      case 'fcircle':
        n = document.createElementNS(NS, 'circle');
        n.setAttribute('cx', String(s[1])); n.setAttribute('cy', String(s[2])); n.setAttribute('r', String(s[3]));
        if (s[0] === 'fcircle') n.setAttribute('fill', 'currentColor');
        break;
      case 'rect':
      case 'frect':
        n = document.createElementNS(NS, 'rect');
        n.setAttribute('x', String(s[1])); n.setAttribute('y', String(s[2]));
        n.setAttribute('width', String(s[3])); n.setAttribute('height', String(s[4]));
        if (s[5]) n.setAttribute('rx', String(s[5]));
        if (s[0] === 'frect') { n.setAttribute('fill', 'currentColor'); n.setAttribute('stroke', 'none'); }
        break;
      case 'ellipse':
        n = document.createElementNS(NS, 'ellipse');
        n.setAttribute('cx', String(s[1])); n.setAttribute('cy', String(s[2]));
        n.setAttribute('rx', String(s[3])); n.setAttribute('ry', String(s[4]));
        break;
    }
    svg.appendChild(n);
  }
  return svg;
}
