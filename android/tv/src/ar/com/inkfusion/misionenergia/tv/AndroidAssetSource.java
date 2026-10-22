package ar.com.inkfusion.misionenergia.tv;

import android.content.res.AssetManager;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

import ar.com.inkfusion.misionenergia.remote.AssetSource;

/** AssetSource sobre los assets del APK, limitado a una subcarpeta (ej. "controller/"). */
public final class AndroidAssetSource implements AssetSource {
    private final AssetManager assets;
    private final String prefix;

    public AndroidAssetSource(AssetManager assets, String prefix) {
        this.assets = assets;
        this.prefix = prefix.endsWith("/") ? prefix : prefix + "/";
    }

    @Override
    public InputStream open(String path) throws IOException {
        // HttpServer ya saneó la ruta (sin "..", sin "/" inicial); AssetManager no tiene symlinks.
        try {
            return assets.open(prefix + path, AssetManager.ACCESS_STREAMING);
        } catch (FileNotFoundException e) {
            return null; // no existe o es una carpeta
        }
    }
}
