// Empaqueta el juego en dist/ (index.html + game.js + fonts). dist/ se copia a android/assets.
import { build } from 'esbuild';
import { cpSync, mkdirSync, rmSync, readFileSync, writeFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
rmSync('dist', { recursive: true, force: true });
mkdirSync('dist', { recursive: true });
await build({
  entryPoints: ['src/main.ts'],
  bundle: true,
  minify: true,
  sourcemap: false,
  target: ['es2019', 'chrome80'],
  format: 'iife',
  outfile: 'dist/game.js',
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  loader: { '.css': 'text' },
  legalComments: 'none',
});
cpSync('public', 'dist', { recursive: true });
const html = readFileSync('index.html', 'utf8').replaceAll('__APP_VERSION__', pkg.version);
writeFileSync('dist/index.html', html);

// Página de control para tablets (la sirve el tele por HTTP en "/"): dist/controller/.
// Autocontenida (fuentes copiadas) para que funcione servida desde la raíz.
await build({
  entryPoints: ['src/controller/main.ts'],
  bundle: true,
  minify: true,
  sourcemap: false,
  target: ['es2019', 'chrome70', 'safari12'],
  format: 'iife',
  outfile: 'dist/controller/controller.js',
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  legalComments: 'none',
});
mkdirSync('dist/controller/fonts', { recursive: true });
for (const f of ['fredoka-latin-500-normal', 'fredoka-latin-600-normal', 'fredoka-latin-700-normal', 'nunito-latin-700-normal', 'nunito-latin-800-normal']) {
  cpSync(`public/fonts/${f}.woff2`, `dist/controller/fonts/${f}.woff2`);
}
writeFileSync('dist/controller/index.html', readFileSync('controller.html', 'utf8').replaceAll('__APP_VERSION__', pkg.version));
console.log('dist listo — versión', pkg.version);
