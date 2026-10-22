#!/usr/bin/env bash
# Compila y firma una variante de Misión Energía sin Gradle (herramientas Android de Ubuntu).
#
#   KS=/ruta/keystore.jks KS_PASS=... ./android/build-variant.sh <phone|tv|control>
#
#   phone   → android/build/MisionEnergia.apk         (juego en el celular; = build.sh)
#   tv      → android/build/MisionEnergiaTV.apk       (juego en el tele + servidor de control remoto)
#   control → android/build/MisionEnergiaControl.apk  (tablet de control de feria)
#
# Las tres usan la misma firma (KS, KS_PASS; alias KS_ALIAS, por defecto "misionenergia").
# phone y tv toman el juego de app/dist (antes: cd app && npm ci && npm run build).
# tv sirve a las tablets app/dist/controller/; si todavía no existe usa tv/placeholder-controller/.
# Cada variante se arma en android/build/<variante>/ sin tocar android/assets ni las otras.
set -euo pipefail
cd "$(dirname "$0")"
VARIANT="${1:-}"
ANDROID_JAR=/usr/lib/android-sdk/platforms/android-23/android.jar
BT=/usr/lib/android-sdk/build-tools/debian
: "${KS:?Falta KS (ruta al keystore)}"
: "${KS_PASS:?Falta KS_PASS}"
KS_ALIAS="${KS_ALIAS:-misionenergia}"
export KS_PASS

case "$VARIANT" in
  phone)   MANIFEST=AndroidManifest.xml;         SRC="src";                         APK=MisionEnergia.apk ;;
  tv)      MANIFEST=tv/AndroidManifest.xml;      SRC="tv/src remote-core/src";      APK=MisionEnergiaTV.apk ;;
  control) MANIFEST=control/AndroidManifest.xml; SRC="control/src remote-core/src"; APK=MisionEnergiaControl.apk ;;
  *) echo "Uso: $0 <phone|tv|control>" >&2; exit 2 ;;
esac

W="build/$VARIANT"
rm -rf "$W" && mkdir -p "$W/classes" "$W/gen" "$W/res" "$W/assets"

# Recursos: íconos comunes (res/) + lo propio de la variante encima.
cp -r res/. "$W/res/"
[ "$VARIANT" = phone ] || cp -r "$VARIANT/res/." "$W/res/"

# Assets
if [ "$VARIANT" = control ]; then
  cp -r control/assets/. "$W/assets/"
else
  [ -f ../app/dist/index.html ] || { echo "Falta app/dist: corré npm run build en app/" >&2; exit 1; }
  cp -r ../app/dist/. "$W/assets/"
  if [ "$VARIANT" = phone ]; then
    rm -rf "$W/assets/controller"   # el celular no sirve la página de control
  elif [ ! -f "$W/assets/controller/index.html" ]; then
    echo "AVISO: app/dist/controller/ no existe todavía; se usa tv/placeholder-controller/" >&2
    mkdir -p "$W/assets/controller" && cp -r tv/placeholder-controller/. "$W/assets/controller/"
  fi
fi

VERSION=$(grep -o 'android:versionName="[^"]*"' "$MANIFEST" | cut -d'"' -f2)
aapt package -f -m -J "$W/gen" -M "$MANIFEST" -S "$W/res" -I "$ANDROID_JAR"
# shellcheck disable=SC2086
if ! javac -nowarn -Xlint:-options --release 8 -encoding UTF-8 -classpath "$ANDROID_JAR" -d "$W/classes" \
     $(find $SRC "$W/gen" -name '*.java') 2> "$W/javac.log"; then
  grep -v "^Picked up" "$W/javac.log" >&2; echo "javac falló" >&2; exit 1
fi
"$BT/dx" --dex --output="$W/classes.dex" "$W/classes"
aapt package -f -M "$MANIFEST" -S "$W/res" -A "$W/assets" -I "$ANDROID_JAR" -F "$W/unsigned.apk"
(cd "$W" && aapt add unsigned.apk classes.dex >/dev/null)
zipalign -f -p 4 "$W/unsigned.apk" "$W/aligned.apk"
apksigner sign --ks "$KS" --ks-key-alias "$KS_ALIAS" --ks-pass env:KS_PASS --key-pass env:KS_PASS \
  --out "build/$APK" "$W/aligned.apk"
rm -f "build/$APK.idsig"
apksigner verify "build/$APK"
echo "APK listo: android/build/$APK (versión $VERSION)"
