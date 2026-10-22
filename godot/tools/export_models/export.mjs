// Exporta los modelos procedurales de la versión web a godot/assets/models/*.glb.
//
// Uso (desde la raíz del repo):
//   NODE_PATH=$(npm root -g) node godot/tools/export_models/export.mjs
//
// 1. Empaqueta entry.ts con el esbuild de app/node_modules (three se resuelve desde app/node_modules).
// 2. Abre un chromium headless (Playwright, SwiftShader) que construye cada pieza con ModelFactory y la
//    exporta con GLTFExporter (binario, texturas embebidas).
// 3. Escribe los .glb en godot/assets/models/, las texturas sueltas en godot/assets/textures/ y el JSON de
//    instancias del ambiente en godot/assets/models/env_instances.json.
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { mkdirSync, writeFileSync, existsSync, readFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../../..');
const appModules = join(root, 'app/node_modules');
const require = createRequire(import.meta.url);
const esbuild = require(join(appModules, 'esbuild'));
const { chromium } = require('playwright');

const outDir = join(here, 'out');
mkdirSync(outDir, { recursive: true });
await esbuild.build({
  entryPoints: [join(here, 'entry.ts')],
  bundle: true,
  format: 'iife',
  outfile: join(outDir, 'bundle.js'),
  nodePaths: [appModules],
  logLevel: 'warning',
});
writeFileSync(join(outDir, 'index.html'), '<!doctype html><meta charset="utf-8"><body><script src="bundle.js"></script></body>');

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--allow-file-access-from-files'] });
const page = await browser.newPage();
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log(`[browser] ${m.type()}: ${m.text()}`); });
page.on('pageerror', (e) => console.log(`[browser] pageerror: ${e.message}`));
await page.goto(pathToFileURL(join(outDir, 'index.html')).href);
const fontBase = pathToFileURL(join(root, 'godot/assets/fonts')).href + '/';
const files = await page.evaluate((fb) => window.__exportAll(fb), fontBase);
await browser.close();

const models = join(root, 'godot/assets/models');
const textures = join(root, 'godot/assets/textures');
mkdirSync(models, { recursive: true });
mkdirSync(textures, { recursive: true });
// Texturas sueltas: con mipmaps y filtro (se usan en 3D).
const texImport = (src) => `[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="${src}"

[params]

compress/mode=0
mipmaps/generate=true
detect_3d/compress_to=0
`;
let total = 0;
for (const [name, data] of Object.entries(files)) {
  if (name.startsWith('tex:')) {
    const fn = name.slice(4);
    writeFileSync(join(textures, fn), Buffer.from(data, 'base64'));
    if (!existsSync(join(textures, fn + '.import'))) writeFileSync(join(textures, fn + '.import'), texImport('res://assets/textures/' + fn));
    console.log('textura', fn);
    continue;
  }
  if (name.endsWith('.json')) { writeFileSync(join(models, name), data); console.log('json', name, data.length); continue; }
  const buf = Buffer.from(data, 'base64');
  total += buf.length;
  writeFileSync(join(models, name), buf);
  // .import con el post-import script (colores por vértice sRGB, materiales para Compatibility).
  const imp = join(models, name + '.import');
  const script = 'import_script/path="res://tools/gltf_post_import.gd"';
  if (existsSync(imp)) {
    const txt = readFileSync(imp, 'utf8');
    if (!txt.includes(script)) writeFileSync(imp, txt.replace(/import_script\/path="[^"]*"/, script));
  } else {
    writeFileSync(imp, `[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="res://assets/models/${name}"\n\n[params]\n\n${script}\n`);
  }
  console.log('glb', name, (buf.length / 1024).toFixed(1) + ' KB');
}
console.log('total glb', (total / 1024 / 1024).toFixed(2) + ' MB');
