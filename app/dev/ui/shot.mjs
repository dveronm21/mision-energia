// Capturas del banco de UI con Playwright + chequeos automáticos (desbordes, objetivos táctiles chicos, texto cortado).
// Uso: npx esbuild dev/ui/harness.ts --bundle --outfile=dev/ui/out/harness.js && NODE_PATH=$(npm root -g) node dev/ui/shot.mjs [escena…]
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const APP = normalize(join(dirname(fileURLToPath(import.meta.url)), '..', '..'));
const OUT = join(APP, 'dev', 'ui', 'out', 'shots');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.woff2': 'font/woff2', '.css': 'text/css', '.png': 'image/png' };

const SCENES = ['splash', 'menu', 'menu-claimed', 'map', 'map-locked', 'workshop', 'shop-soles', 'shop-mejoras', 'shop-vestuario',
  'shop-result', 'gate', 'wardrobe', 'result-win', 'result-lose', 'pause', 'settings', 'settings-reset', 'hud', 'hud-inspect', 'hud-night'];
const VIEWPORTS = [[915, 412], [800, 360], [1280, 800]];

const server = createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (path.startsWith('/dev/ui/fonts/')) path = path.replace('/dev/ui/fonts/', '/public/fonts/');
  const file = normalize(join(APP, path));
  if (!file.startsWith(APP)) { res.writeHead(403).end(); return; }
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' }).end(body);
  } catch { res.writeHead(404).end(); }
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

await mkdir(OUT, { recursive: true });
const only = process.argv.slice(2);
const scenes = only.length ? SCENES.filter((s) => only.includes(s)) : SCENES;
const browser = await chromium.launch();
let problems = 0;

for (const [w, h] of VIEWPORTS) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  for (const scene of scenes) {
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(`http://127.0.0.1:${port}/dev/ui/harness.html?scene=${scene}`);
    await page.waitForFunction(() => window.__ready === true, null, { timeout: 8000 }).catch(() => errors.push('timeout __ready'));
    const issues = await page.evaluate(() => {
      const out = [];
      const W = innerWidth, H = innerHeight;
      const visible = (el) => {
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return false;
        const cs = getComputedStyle(el);
        return cs.visibility !== 'hidden' && cs.display !== 'none' && el.closest('[hidden]') === null;
      };
      const name = (el) => `${el.tagName.toLowerCase()}.${String(el.className).split(' ').join('.')}` + (el.textContent ? ` "${el.textContent.trim().slice(0, 30)}"` : '');
      // Clip: un elemento queda recortado si un ancestro con overflow lo corta (y ese ancestro no es scrolleable).
      const all = [...document.querySelectorAll('#ui *')].filter(visible);
      for (const el of all) {
        const r = el.getBoundingClientRect();
        if (el.closest('.splash-rays')) continue;
        if (r.right > W + 1 || r.bottom > H + 1 || r.left < -1 || r.top < -1) {
          // ¿Está dentro de un contenedor con scroll? Entonces es válido.
          let p = el.parentElement, scrolls = false;
          while (p && p.id !== 'ui') { const o = getComputedStyle(p); if (/(auto|scroll)/.test(o.overflowY + o.overflowX)) { scrolls = true; break; } p = p.parentElement; }
          if (!scrolls) out.push(`fuera de pantalla: ${name(el)} [${Math.round(r.left)},${Math.round(r.top)},${Math.round(r.right)},${Math.round(r.bottom)}]`);
        }
      }
      for (const el of all.filter((e) => e.matches('button,[role=switch],[role=tab]'))) {
        const r = el.getBoundingClientRect();
        if (r.width < 47.5 || r.height < 47.5) out.push(`objetivo chico (${Math.round(r.width)}×${Math.round(r.height)}): ${name(el)}`);
      }
      for (const el of all) {
        if (el.children.length) continue;
        const cs = getComputedStyle(el);
        if (cs.clip && cs.clip !== 'auto') continue; // sólo para lectores de pantalla
        if (cs.overflow === 'visible' && cs.textOverflow !== 'ellipsis') continue;
        if (/(auto|scroll)/.test(cs.overflowY)) continue;
        if (el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1) out.push(`texto cortado: ${name(el)}`);
      }
      // Superposición entre zonas del HUD.
      const zones = ['.hud-mission', '.hud-stats', '.hud-pause', '.hud-joy', '.hud-btns', '.hud-boosters', '.hud-alert', '.ui-toast', '.hud-meter', '.hud-inspect', '.hud-shed']
        .map((s) => document.querySelector(s)).filter((e) => e && visible(e) && !e.closest('.ui-layer[hidden]'));
      for (let i = 0; i < zones.length; i++) for (let j = i + 1; j < zones.length; j++) {
        const a = zones[i].getBoundingClientRect(), b = zones[j].getBoundingClientRect();
        if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) {
          // Sólo cuenta si ambos están en el HUD (los modales tapan a propósito).
          if (!document.querySelector('.scr')) out.push(`superposición HUD: ${zones[i].className} × ${zones[j].className}`);
        }
      }
      return out;
    });
    const file = join(OUT, `${scene}-${w}x${h}.png`);
    await page.screenshot({ path: file });
    const all = [...errors, ...issues];
    if (all.length) { problems += all.length; console.log(`✗ ${scene} ${w}×${h}\n   ${all.join('\n   ')}`); }
    else console.log(`✓ ${scene} ${w}×${h}`);
    await page.close();
  }
  await ctx.close();
}
await browser.close();
server.close();
console.log(problems ? `\n${problems} observaciones` : '\nSin observaciones');
console.log('Capturas en', OUT);
