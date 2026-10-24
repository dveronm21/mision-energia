#!/usr/bin/env bash
# Prepara la plantilla Gradle de Godot para exportar "Misión Energía TV" (preset "Android TV").
#
#   ./android/godot/prepare-tv-template.sh <ruta a android_source.zip de Godot 4.7.2>
#
# Hace lo mismo que "Proyecto → Instalar plantilla de compilación de Android" (descomprime en
# godot/android/build, escribe .build_version y .gdignore) y le agrega lo que el export de
# Godot no trae para Android TV:
#   - android:banner (el banner de 320×180 del lanzador de TV, el mismo de la app web)
#   - uses-feature leanback y touchscreen como no requeridos (si no, Google TV la oculta)
# Godot genera después src/release/AndroidManifest.xml y Gradle lo fusiona con este, así que
# estos agregados se conservan.
set -euo pipefail
cd "$(dirname "$0")/../.."
ZIP="${1:?Uso: $0 <android_source.zip>}"
VERSION_ID="${GODOT_TEMPLATE_ID:-4.7.2.stable}"
ROOT=godot/android
B="$ROOT/build"

rm -rf "$B"
mkdir -p "$B"
unzip -q -o "$ZIP" -d "$B"
echo "$VERSION_ID" > "$ROOT/.build_version"
echo "" > "$B/.gdignore"
chmod +x "$B/gradlew" 2>/dev/null || true

M="$B/src/main/AndroidManifest.xml"
[ -f "$M" ] || { echo "No está $M: ¿es el android_source.zip correcto?" >&2; exit 1; }

mkdir -p "$B/res/drawable-xhdpi"
cp android/tv/res/drawable-xhdpi/banner.png "$B/res/drawable-xhdpi/banner.png"

# Banner en <application> (una sola vez).
if ! grep -q 'android:banner=' "$M"; then
  sed -i 's|<application|<application android:banner="@drawable/banner"|' "$M"
fi
# Features de TV antes de <application> (una sola vez).
if ! grep -q 'android.software.leanback' "$M"; then
  sed -i 's|<application|<uses-feature android:name="android.software.leanback" android:required="false" />\n    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />\n\n    <application|' "$M"
fi

grep -q 'android:banner="@drawable/banner"' "$M" || { echo "No se pudo agregar el banner" >&2; exit 1; }
echo "Plantilla de TV lista en $B (banner y features de Android TV agregados)"
