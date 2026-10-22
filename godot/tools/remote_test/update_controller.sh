#!/usr/bin/env bash
# Actualiza la página de control que sirve el tele (godot/controller/) desde la versión web (app/).
#   ./godot/tools/remote_test/update_controller.sh
# 1) npm run build en app/ (genera app/dist/controller/)  2) copia a godot/controller/
# 3) marca las fuentes .woff2 con importer="keep" (se exportan tal cual, no como FontFile)
# 4) reimporta el proyecto.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT_DIR="$(cd "$HERE/../.." && pwd)"
APP_DIR="$(cd "$GODOT_DIR/../app" && pwd)"
(cd "$APP_DIR" && npm run build)
rm -rf "$GODOT_DIR/controller"
mkdir -p "$GODOT_DIR/controller"
cp -r "$APP_DIR/dist/controller/." "$GODOT_DIR/controller/"
find "$GODOT_DIR/controller" -name '*.woff2' -print0 | while IFS= read -r -d '' f; do
  printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
"${GODOT:-godot}" --headless --path "$GODOT_DIR" --import >/dev/null 2>&1 || true
echo "controller/ actualizado: $(find "$GODOT_DIR/controller" -type f ! -name '*.import' | wc -l) archivos"
