#!/usr/bin/env bash
# Compila y firma el APK de Misión Energía sin Gradle (herramientas Android de Ubuntu).
# Requiere: apt install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 + JDK 17+
# Uso:   KS=/ruta/misionenergia-release.jks KS_PASS=... ./android/build.sh
# Antes: cd app && npm ci && npm run build   (genera app/dist)
set -euo pipefail
cd "$(dirname "$0")"
ANDROID_JAR=/usr/lib/android-sdk/platforms/android-23/android.jar
BT=/usr/lib/android-sdk/build-tools/debian
: "${KS:?Falta KS (ruta al keystore)}"
: "${KS_PASS:?Falta KS_PASS}"
VERSION=$(grep -o 'android:versionName="[^"]*"' AndroidManifest.xml | cut -d'"' -f2)
OUT=build
rm -rf "$OUT" assets && mkdir -p "$OUT/classes" "$OUT/gen"
[ -f ../app/dist/index.html ] || { echo "Falta app/dist: corré npm run build en app/"; exit 1; }
cp -r ../app/dist assets

aapt package -f -m -J "$OUT/gen" -M AndroidManifest.xml -S res -I "$ANDROID_JAR"
javac -nowarn --release 8 -encoding UTF-8 -classpath "$ANDROID_JAR" -d "$OUT/classes" \
  $(find src "$OUT/gen" -name '*.java') 2>&1 | grep -v "^warning\|bootstrap" || true
"$BT/dx" --dex --output="$OUT/classes.dex" "$OUT/classes"
aapt package -f -M AndroidManifest.xml -S res -A assets -I "$ANDROID_JAR" -F "$OUT/unsigned.apk"
(cd "$OUT" && aapt add unsigned.apk classes.dex >/dev/null)
zipalign -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
apksigner sign --ks "$KS" --ks-key-alias misionenergia --ks-pass env:KS_PASS --key-pass env:KS_PASS \
  --out "$OUT/MisionEnergia.apk" "$OUT/aligned.apk"
apksigner verify "$OUT/MisionEnergia.apk"
echo "APK listo: android/$OUT/MisionEnergia.apk (versión $VERSION)"
