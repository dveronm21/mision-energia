#!/usr/bin/env bash
# Pruebas de escritorio del núcleo de red (android/remote-core) — sin Android.
# Requiere JDK 8+ y Node 18+. Instala `ws` solo dentro de esta carpeta. Playwright/Chromium se toman
# de la instalación global (NODE_PATH=$(npm root -g), navegadores en /opt/pw-browsers).
set -euo pipefail
cd "$(dirname "$0")"
OUT=build/classes
rm -rf build && mkdir -p "$OUT"
javac -Xlint:all,-options -Werror --release 8 -encoding UTF-8 -d "$OUT" \
  $(find ../remote-core/src src -name '*.java')
echo "== CoreUnitTest"
JAVA_TOOL_OPTIONS= java -cp "$OUT" ar.com.inkfusion.misionenergia.remote.test.CoreUnitTest
[ -d node_modules/ws ] || npm install --no-audit --no-fund --silent
echo "== Integración (Node ws + UDP + Chromium)"
export NODE_PATH="${NODE_PATH:-$(npm root -g)}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
node test.mjs "$OUT"
