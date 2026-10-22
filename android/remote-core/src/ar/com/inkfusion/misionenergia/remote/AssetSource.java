package ar.com.inkfusion.misionenergia.remote;

import java.io.IOException;
import java.io.InputStream;

/**
 * Origen de los archivos estáticos de la página de control.
 * En escritorio: {@link DirectoryAssetSource}; en Android: un adaptador sobre AssetManager.
 */
public interface AssetSource {
    /**
     * Abre un archivo. {@code path} ya viene saneado por HttpServer: relativo, sin "..",
     * sin barras invertidas y sin "/" inicial (ej. "index.html", "js/app.js").
     * @return el stream, o null si no existe (o es una carpeta).
     */
    InputStream open(String path) throws IOException;
}
