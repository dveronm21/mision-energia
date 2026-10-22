package ar.com.inkfusion.misionenergia.remote;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/** AssetSource sobre una carpeta del disco. Rechaza todo lo que resuelva fuera de la carpeta (incluidos symlinks). */
public final class DirectoryAssetSource implements AssetSource {
    private final File root;
    private final String rootPrefix;

    public DirectoryAssetSource(File root) throws IOException {
        this.root = root.getCanonicalFile();
        this.rootPrefix = this.root.getPath() + File.separator;
    }

    @Override
    public InputStream open(String path) throws IOException {
        File f = new File(root, path).getCanonicalFile();
        if (!f.getPath().startsWith(rootPrefix)) return null;
        if (!f.isFile()) return null;
        return new FileInputStream(f);
    }
}
