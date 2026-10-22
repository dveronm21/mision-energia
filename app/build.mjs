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
console.log('dist listo — versión', pkg.version);
