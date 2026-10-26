# Publicar Misión Energía en Google Play

La versión de Play es la misma app del celular (`ar.com.inkfusion.misionenergia`), con la **misma firma** que el APK del QR de la feria: quien la instaló en la feria puede actualizarla desde Play. Se diferencia en una cosa: **no tiene compras con dinero real**. La tienda solo vende con Soles, que se ganan jugando. Las compras con Google Play Billing se pueden sumar en una actualización.

## 1. Conseguir el AAB
Cada tag `vX.Y.Z` compila `MisionEnergia.aab` en GitHub Actions:
*Actions → la compilación del tag → Artifacts → `MisionEnergia-play-aab`*.
El código de versión sale del tag (v1.0.0 → 10000, v1.0.1 → 10001…). Play no acepta dos veces el mismo código, así que cada subida necesita una versión nueva. Los tags de prueba de una misma versión (`v1.0.0-rc1`, `-rc2`…) comparten código: para Play usá versiones finales.

## 2. Crear la app en Play Console
*Crear app* → nombre "Misión Energía", idioma predeterminado Español (Latinoamérica), **Juego**, **Gratis**. Aceptar las declaraciones.

## 3. Firma de la app (con la clave de la feria)
En *Configuración → Integridad de la app → Firma de apps*, elegir **usar otra clave** y la opción para exportar y subir una clave de un keystore de Java (Play Console baja la herramienta `pepk.jar` y muestra el comando exacto con su clave de cifrado). Se corre en tu compu, con tu keystore:

```
java -jar pepk.jar --keystore=<tu keystore .jks> --alias=misionenergia \
  --output=clave-para-play.zip --include-cert --rsa-aes-encryption \
  --encryption-key-path=<archivo de clave que da Play Console>
```

Subí `clave-para-play.zip`. Así Play firma con la misma clave que el APK de la feria. El AAB que sube el CI ya va firmado con esa misma clave, que también hace de clave de subida.

> El keystore y su contraseña no se suben nunca al repositorio.

## 4. Primera versión
*Pruebas → Prueba interna → Crear versión* → subir `MisionEnergia.aab` → notas de la versión → *Revisar y lanzar*. Sumate como testers con tu cuenta y probá la instalación desde Play.

Después se puede pasar a *Producción*. Ojo: las cuentas personales de desarrollador nuevas tienen que hacer antes una prueba cerrada con al menos 12 testers durante 14 días.

## 5. Contenido de la app (*Política → Contenido de la app*)
| Formulario | Respuesta |
|---|---|
| Política de privacidad | URL de `docs/play-store/PRIVACIDAD.md` en GitHub: `https://github.com/dveronm21/mision-energia/blob/main/docs/play-store/PRIVACIDAD.md` |
| Anuncios | No contiene anuncios |
| Acceso a la app | Toda la funcionalidad está disponible sin restricciones (no hay login) |
| Público objetivo | El que corresponda: si incluye menores de 13, la app entra en la política de Familias. Cumple: sin anuncios, sin datos, sin compras |
| Seguridad de los datos | **No recopila ni comparte datos** (todo se guarda en el dispositivo; la app no tiene permiso de internet) |
| Clasificación de contenido (IARC) | Categoría "Juego"; sin violencia, sin contenido sexual, sin lenguaje ofensivo, sin drogas, sin apuestas, sin interacción entre usuarios, sin compras digitales. Resultado esperado: apto para todo público (ATP / PEGI 3 / Everyone) |
| Apps gubernamentales | No |
| Funciones financieras | Ninguna |
| Salud | Ninguna |

## 6. Ficha de Play Store
Textos y recursos gráficos: [FICHA.md](FICHA.md).

## 7. Subidas automáticas (opcional)
Para que cada tag suba el AAB solo a *Prueba interna*, como borrador:
1. En Google Cloud, crear una cuenta de servicio con una clave JSON.
2. En Play Console, *Usuarios y permisos → Invitar usuarios*: agregar el mail de la cuenta de servicio con permiso para publicar en pistas de prueba.
3. En GitHub, *Settings → Secrets → Actions*, crear `PLAY_SERVICE_ACCOUNT_JSON` con el contenido del JSON.

La primera versión se sube siempre a mano (paso 4).

## Más adelante
- **Compras reales:** proveedor `GooglePlayBillingProvider` con verificación en un servidor antes de acreditar Soles (regla del proyecto). Al activarlas: actualizar la política de privacidad y los formularios de *Seguridad de los datos* y *Clasificación*.
- **Android TV en Play:** cuando el modo TV esté probado en un tele real.
