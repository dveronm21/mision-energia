package ar.com.inkfusion.misionenergia.remote.test;

import ar.com.inkfusion.misionenergia.remote.Base64Codec;
import ar.com.inkfusion.misionenergia.remote.DirectoryAssetSource;
import ar.com.inkfusion.misionenergia.remote.EventQueue;
import ar.com.inkfusion.misionenergia.remote.HttpServer;
import ar.com.inkfusion.misionenergia.remote.Json;
import ar.com.inkfusion.misionenergia.remote.NetUtils;
import ar.com.inkfusion.misionenergia.remote.TvInfo;
import ar.com.inkfusion.misionenergia.remote.WebSocketConnection;

import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Random;

/** Pruebas unitarias sin framework (java -cp ... CoreUnitTest). Sale con código 1 si algo falla. */
public final class CoreUnitTest {
    private static int ok, fail;

    private static void check(String name, boolean cond) {
        if (cond) ok++; else { fail++; System.out.println("FALLA: " + name); }
    }

    public static void main(String[] args) throws Exception {
        // RFC 6455 §1.3, ejemplo oficial
        check("acceptKey RFC", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=".equals(WebSocketConnection.acceptKey("dGhlIHNhbXBsZSBub25jZQ==")));

        Random r = new Random(1);
        for (int n = 0; n < 200; n++) {
            byte[] b = new byte[r.nextInt(40)];
            r.nextBytes(b);
            String enc = Base64Codec.encode(b);
            check("base64 = JDK " + n, enc.equals(java.util.Base64.getEncoder().encodeToString(b)));
            check("base64 ida y vuelta " + n, Arrays.equals(b, Base64Codec.decode(enc)));
        }
        check("base64 inválido", Base64Codec.decode("ab$=") == null);

        // Saneado de rutas
        check("raíz", "index.html".equals(HttpServer.sanitizePath("/")));
        check("archivo", "app.js".equals(HttpServer.sanitizePath("/app.js")));
        check("subcarpeta", "sub/index.html".equals(HttpServer.sanitizePath("/sub/")));
        check("espacio %20", "a b.png".equals(HttpServer.sanitizePath("/a%20b.png")));
        String[] malas = {"/../etc/passwd", "/a/../../x", "/%2e%2e/x", "/%2E%2E%2Fx", "/..%5cx", "/a\\b",
                "/a%00.html", "/.env", "/a//b", "/%zz", "/a%", "relative", "/a?b", "/é.html", "/%c3%a9", "/./x"};
        for (String m : malas) check("rechaza " + m, HttpServer.sanitizePath(m) == null);
        check("mime js", HttpServer.mimeFor("a.js").startsWith("text/javascript"));
        check("mime html", HttpServer.mimeFor("index.html").startsWith("text/html"));
        check("mime woff2", "font/woff2".equals(HttpServer.mimeFor("f.woff2")));
        check("mime desconocido", "application/octet-stream".equals(HttpServer.mimeFor("x.bin")));

        // DirectoryAssetSource no sale de la carpeta ni siguiendo symlinks
        File tmp = new File(System.getProperty("java.io.tmpdir"), "me-assets-" + System.nanoTime());
        File root = new File(tmp, "root");
        root.mkdirs();
        new java.io.FileOutputStream(new File(tmp, "secret.txt")).close();
        new java.io.FileOutputStream(new File(root, "ok.txt")).close();
        try {
            java.nio.file.Files.createSymbolicLink(new File(root, "link.txt").toPath(), new File(tmp, "secret.txt").toPath());
        } catch (Exception ignored) { }
        DirectoryAssetSource src = new DirectoryAssetSource(root);
        check("asset existe", src.open("ok.txt") != null);
        check("asset no existe", src.open("nada.txt") == null);
        check("asset .. directo", src.open("../secret.txt") == null);
        check("asset symlink afuera", src.open("link.txt") == null);
        check("asset carpeta", src.open("") == null);

        // Json
        String weird = "a\"b\\c\n</script> \u0001ñ";
        Map<String, Object> m = Json.parseObject("{\"k\":" + Json.quote(weird) + ",\"n\":3,\"b\":true,\"z\":null,\"o\":{\"x\":1},\"a\":[1,2]}");
        check("json ida y vuelta", weird.equals(m.get("k")));
        check("json sin </script>", !Json.quote(weird).contains("</"));
        check("json num", Json.num(m, "n", 0) == 3);
        boolean threw = false;
        try { Json.parseObject("{\"a\":1"); } catch (IllegalArgumentException e) { threw = true; }
        check("json incompleto", threw);

        // TvInfo
        TvInfo tv = TvInfo.parse("{\"app\":\"mision-energia-tv\",\"v\":1,\"name\":\"Sala\",\"ip\":\"10.0.0.5\",\"port\":8765,\"players\":1,\"max\":2}");
        check("tvinfo", tv != null && tv.port == 8765 && "Sala".equals(tv.name));
        check("tvinfo ajeno", TvInfo.parse("{\"app\":\"otra\",\"ip\":\"1.2.3.4\",\"port\":1}") == null);
        check("tvinfo basura", TvInfo.parse("hola") == null);
        check("tvinfo roundtrip", TvInfo.parse(tv.toJson()).toJson().equals(tv.toJson()));

        // EventQueue
        EventQueue q = new EventQueue();
        check("cola vacía", "[]".equals(q.poll()));
        q.open(1, "1.2.3.4");
        for (int i = 0; i < EventQueue.MAX_PENDING_MSGS + 10; i++) q.message(1, "m" + i);
        q.closed(1);
        List<Map<String, Object>> evs = Json.parseObjectArray(q.poll());
        check("cola: open primero", "open".equals(evs.get(0).get("e")));
        check("cola: close último", "close".equals(evs.get(evs.size() - 1).get("e")));
        check("cola: descarta msg excedentes", evs.size() == EventQueue.MAX_PENDING_MSGS + 2 && q.droppedCount() == 10);
        check("cola vacía tras poll", "[]".equals(q.poll()));

        // NetUtils
        check("excluye rmnet", !NetUtils.isUsableName("rmnet_data0"));
        check("excluye tun", !NetUtils.isUsableName("tun0"));
        check("acepta wlan0", NetUtils.isUsableName("wlan0"));
        check("localAddressFor loopback", NetUtils.localAddressFor(java.net.InetAddress.getLoopbackAddress()) != null
                && NetUtils.localAddressFor(java.net.InetAddress.getLoopbackAddress()).isLoopbackAddress());

        System.out.println("CoreUnitTest: " + ok + " ok, " + fail + " fallas");
        System.exit(fail == 0 ? 0 : 1);
    }
}
