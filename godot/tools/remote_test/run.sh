#!/usr/bin/env bash
# Integración del servidor remoto GDScript contra Node ws + UDP + Chromium.
# Requiere: godot 4.7 en el PATH (o GODOT=...), Node 18+, Playwright global (NODE_PATH) y Chromium en /opt/pw-browsers.
set -euo pipefail
cd "$(dirname "$0")"
[ -d node_modules/ws ] || npm install --no-audit --no-fund --silent
# Que Godot no escanee node_modules/ ni las capturas (si no, importa los PNG como texturas).
mkdir -p out && touch node_modules/.gdignore out/.gdignore
"${GODOT:-godot}" --headless --path ../.. --import >/dev/null 2>&1 || true
export NODE_PATH="${NODE_PATH:-$(npm root -g)}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
node test.mjs
