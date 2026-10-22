package ar.com.inkfusion.misionenergia.remote;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/** Cabecera de una petición HTTP/1.1 (sin cuerpo). Parser estricto y acotado en tamaño. */
public final class HttpRequest {
    public static final int MAX_HEAD_BYTES = 8192;
    private static final Charset ISO = Charset.forName("ISO-8859-1");

    public final String method;
    public final String target;   // tal cual vino: "/ws?x=1"
    public final String path;     // sin query ni fragmento: "/ws"
    public final String version;
    private final Map<String, String> headers;

    private HttpRequest(String method, String target, String version, Map<String, String> headers) {
        this.method = method;
        this.target = target;
        int q = target.indexOf('?');
        int h = target.indexOf('#');
        int cut = target.length();
        if (q >= 0) cut = q;
        if (h >= 0 && h < cut) cut = h;
        this.path = target.substring(0, cut);
        this.version = version;
        this.headers = headers;
    }

    /** Valor de la cabecera (nombre sin distinguir mayúsculas) o null. */
    public String header(String name) { return headers.get(name.toLowerCase(Locale.ROOT)); }

    /** true si la cabecera (lista separada por comas) contiene el token, sin distinguir mayúsculas. */
    public boolean headerHasToken(String name, String token) {
        String v = header(name);
        if (v == null) return false;
        for (String part : v.split(",")) {
            if (part.trim().equalsIgnoreCase(token)) return true;
        }
        return false;
    }

    /**
     * Lee la cabecera hasta CRLFCRLF. Lee byte a byte para no consumir datos de más
     * (después de un Upgrade vienen frames WebSocket por el mismo stream).
     * @return null si el cliente cerró sin mandar nada.
     * @throws HttpException 400/431 si la petición es inválida o demasiado grande.
     */
    public static HttpRequest read(InputStream in) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream(512);
        int state = 0; // cuenta de \r\n\r\n
        while (true) {
            int c = in.read();
            if (c < 0) {
                if (buf.size() == 0) return null;
                throw new HttpException(400, "Petición incompleta");
            }
            buf.write(c);
            if (buf.size() > MAX_HEAD_BYTES) throw new HttpException(431, "Cabecera demasiado grande");
            if ((state == 0 || state == 2) && c == '\r') state++;
            else if ((state == 1 || state == 3) && c == '\n') state++;
            else if (c == '\r') state = 1;
            else state = 0;
            if (state == 4) break;
        }
        String head = new String(buf.toByteArray(), ISO);
        String[] lines = head.split("\r\n");
        if (lines.length == 0) throw new HttpException(400, "Petición vacía");
        String[] rl = lines[0].split(" ");
        if (rl.length != 3 || !rl[2].startsWith("HTTP/1.")) throw new HttpException(400, "Línea de petición inválida");
        if (!rl[1].startsWith("/")) throw new HttpException(400, "Destino inválido");
        Map<String, String> h = new HashMap<String, String>();
        for (int i = 1; i < lines.length; i++) {
            String l = lines[i];
            if (l.isEmpty()) continue;
            int colon = l.indexOf(':');
            if (colon <= 0) throw new HttpException(400, "Cabecera inválida");
            String k = l.substring(0, colon).trim().toLowerCase(Locale.ROOT);
            String v = l.substring(colon + 1).trim();
            String prev = h.get(k);
            h.put(k, prev == null ? v : prev + ", " + v);
        }
        return new HttpRequest(rl[0], rl[1], rl[2], h);
    }

    /** Error de protocolo HTTP con su código de estado. */
    public static final class HttpException extends IOException {
        private static final long serialVersionUID = 1L;
        public final int status;

        public HttpException(int status, String msg) {
            super(msg);
            this.status = status;
        }
    }
}
