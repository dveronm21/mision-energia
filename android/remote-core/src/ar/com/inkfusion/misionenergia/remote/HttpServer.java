package ar.com.inkfusion.misionenergia.remote;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.Socket;
import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Atiende una conexión TCP: sirve archivos estáticos de la página de control desde un
 * {@link AssetSource}, responde {@code /api/info} y, si es {@code GET /ws} con Upgrade,
 * la convierte en {@link WebSocketConnection}.
 *
 * HTTP/1.1 con keep-alive acotado (hasta 32 peticiones, 5 s de inactividad). Solo GET y HEAD.
 */
public final class HttpServer {
    public static final int HEAD_TIMEOUT_MS = 5000;
    public static final int MAX_REQUESTS_PER_CONNECTION = 32;
    public static final int MAX_ASSET_BYTES = 16 * 1024 * 1024;
    private static final Charset UTF8 = Charset.forName("UTF-8");
    private static final Map<String, String> MIME = new HashMap<String, String>();

    static {
        MIME.put("html", "text/html; charset=utf-8");
        MIME.put("htm", "text/html; charset=utf-8");
        MIME.put("js", "text/javascript; charset=utf-8");
        MIME.put("mjs", "text/javascript; charset=utf-8");
        MIME.put("css", "text/css; charset=utf-8");
        MIME.put("json", "application/json; charset=utf-8");
        MIME.put("map", "application/json; charset=utf-8");
        MIME.put("webmanifest", "application/manifest+json; charset=utf-8");
        MIME.put("txt", "text/plain; charset=utf-8");
        MIME.put("svg", "image/svg+xml");
        MIME.put("png", "image/png");
        MIME.put("jpg", "image/jpeg");
        MIME.put("jpeg", "image/jpeg");
        MIME.put("gif", "image/gif");
        MIME.put("webp", "image/webp");
        MIME.put("ico", "image/x-icon");
        MIME.put("woff", "font/woff");
        MIME.put("woff2", "font/woff2");
        MIME.put("ttf", "font/ttf");
        MIME.put("otf", "font/otf");
        MIME.put("mp3", "audio/mpeg");
        MIME.put("ogg", "audio/ogg");
        MIME.put("wav", "audio/wav");
        MIME.put("wasm", "application/wasm");
    }

    /** Lo que HttpServer necesita del servidor que lo contiene. */
    interface Host {
        AssetSource assets();
        String infoJson(InetAddress localAddress);
        /** Intenta reservar un lugar para un WebSocket nuevo; null si no hay lugar. */
        WebSocketConnection newWebSocket(Socket s, InputStream in, OutputStream out);
        boolean allowAnyOrigin();
        RemoteLog log();
    }

    private final Host host;

    HttpServer(Host host) { this.host = host; }

    /** Atiende el socket hasta que se cierra. Siempre cierra el socket al terminar. */
    void handle(Socket socket) {
        boolean upgraded = false;
        try {
            socket.setTcpNoDelay(true);
            socket.setSoTimeout(HEAD_TIMEOUT_MS);
            InputStream in = new BufferedInputStream(socket.getInputStream(), 8192);
            OutputStream out = new BufferedOutputStream(socket.getOutputStream(), 8192);
            for (int n = 0; n < MAX_REQUESTS_PER_CONNECTION; n++) {
                HttpRequest req;
                try {
                    req = HttpRequest.read(in);
                } catch (HttpRequest.HttpException e) {
                    sendError(out, e.status, e.getMessage(), false, false);
                    return;
                }
                if (req == null) return;
                boolean keepAlive = !req.headerHasToken("Connection", "close")
                        && "HTTP/1.1".equals(req.version) && n + 1 < MAX_REQUESTS_PER_CONNECTION;
                if (Protocol.WS_PATH.equals(req.path) && req.headerHasToken("Upgrade", "websocket")) {
                    upgraded = upgrade(socket, in, out, req);
                    return;
                }
                if (!serve(socket, out, req, keepAlive)) return;
            }
        } catch (IOException e) {
            // timeout o cliente cerrado: nada que hacer
        } finally {
            if (!upgraded) closeQuietly(socket);
        }
    }

    /** @return true si la conexión pasó a ser WebSocket (y ya terminó). */
    private boolean upgrade(Socket socket, InputStream in, OutputStream out, HttpRequest req) throws IOException {
        if (!"GET".equals(req.method)) { sendError(out, 405, "Método no permitido", false, false); return false; }
        if (!req.headerHasToken("Connection", "upgrade")) { sendError(out, 400, "Falta Connection: Upgrade", false, false); return false; }
        if (!"13".equals(req.header("Sec-WebSocket-Version"))) {
            byte[] body = "Versión de WebSocket no soportada\n".getBytes(UTF8);
            writeHead(out, 426, "Upgrade Required", "text/plain; charset=utf-8", body.length, false,
                    "Sec-WebSocket-Version: 13\r\n");
            out.write(body);
            out.flush();
            return false;
        }
        String key = req.header("Sec-WebSocket-Key");
        byte[] raw = key == null ? null : Base64Codec.decode(key.trim());
        if (raw == null || raw.length != 16) { sendError(out, 400, "Sec-WebSocket-Key inválida", false, false); return false; }
        if (!host.allowAnyOrigin() && !originAllowed(req.header("Origin"), req.header("Host"))) {
            sendError(out, 403, "Origen no permitido", false, false);
            return false;
        }
        WebSocketConnection ws = host.newWebSocket(socket, in, out);
        if (ws == null) { sendError(out, 503, "Demasiadas conexiones", false, false); return false; }
        String accept = WebSocketConnection.acceptKey(key.trim());
        String resp = "HTTP/1.1 101 Switching Protocols\r\n"
                + "Upgrade: websocket\r\n"
                + "Connection: Upgrade\r\n"
                + "Sec-WebSocket-Accept: " + accept + "\r\n\r\n";
        ws.run(resp.getBytes(UTF8)); // bloquea hasta que la conexión termina; cierra el socket
        return true;
    }

    /**
     * Sin Origin (apps nativas, Node) → permitido. Con Origin http(s), el host tiene que coincidir con
     * la cabecera Host (la página de control la sirve este mismo servidor). Evita que una página de
     * Internet abierta en una tablet use el navegador para conectarse al tele.
     */
    static boolean originAllowed(String origin, String hostHeader) {
        if (origin == null || origin.isEmpty() || "null".equals(origin)) return true;
        String o = origin.toLowerCase(Locale.ROOT);
        if (o.startsWith("file:")) return true;
        int sep = o.indexOf("://");
        if (sep < 0 || hostHeader == null) return false;
        String oh = o.substring(sep + 3);
        if (oh.endsWith("/")) oh = oh.substring(0, oh.length() - 1);
        return oh.equals(hostHeader.toLowerCase(Locale.ROOT).trim());
    }

    /** @return true si la conexión puede seguir (keep-alive). */
    private boolean serve(Socket socket, OutputStream out, HttpRequest req, boolean keepAlive) throws IOException {
        boolean head = "HEAD".equals(req.method);
        if (!head && !"GET".equals(req.method)) {
            sendError(out, 405, "Método no permitido", false, false);
            return false;
        }
        if (Protocol.INFO_PATH.equals(req.path)) {
            byte[] body = host.infoJson(socket.getLocalAddress()).getBytes(UTF8);
            writeHead(out, 200, "OK", "application/json; charset=utf-8", body.length, keepAlive,
                    "Access-Control-Allow-Origin: *\r\n");
            if (!head) out.write(body);
            out.flush();
            return keepAlive;
        }
        String rel = sanitizePath(req.path);
        if (rel == null) {
            sendError(out, 400, "Ruta inválida", head, keepAlive);
            return keepAlive;
        }
        byte[] body = readAsset(rel);
        if (body == null) {
            sendError(out, 404, "No encontrado", head, keepAlive);
            return keepAlive;
        }
        writeHead(out, 200, "OK", mimeFor(rel), body.length, keepAlive, null);
        if (!head) out.write(body);
        out.flush();
        return keepAlive;
    }

    private byte[] readAsset(String rel) {
        InputStream in = null;
        try {
            in = host.assets().open(rel);
            if (in == null) return null;
            ByteArrayOutputStream b = new ByteArrayOutputStream(8192);
            byte[] buf = new byte[8192];
            int r;
            while ((r = in.read(buf)) >= 0) {
                b.write(buf, 0, r);
                if (b.size() > MAX_ASSET_BYTES) return null;
            }
            return b.toByteArray();
        } catch (IOException e) {
            return null;
        } finally {
            if (in != null) try { in.close(); } catch (IOException ignored) { }
        }
    }

    /**
     * Convierte la ruta URL en una ruta relativa segura dentro de la carpeta de la página de control.
     * "/" → "index.html"; "/a/" → "a/index.html". Rechaza (null) "..", ".", segmentos ocultos,
     * barras invertidas, NUL, escapes % inválidos y caracteres fuera de [A-Za-z0-9._~ -/].
     */
    public static String sanitizePath(String urlPath) {
        if (urlPath == null || !urlPath.startsWith("/") || urlPath.length() > 512) return null;
        String decoded = percentDecode(urlPath);
        if (decoded == null) return null;
        if (decoded.endsWith("/")) decoded = decoded + "index.html";
        StringBuilder out = new StringBuilder();
        for (String seg : decoded.substring(1).split("/", -1)) {
            if (seg.isEmpty()) return null;               // "//" o similar
            if (seg.equals(".") || seg.equals("..") || seg.startsWith(".")) return null;
            for (int i = 0; i < seg.length(); i++) {
                char c = seg.charAt(i);
                boolean ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
                        || c == '.' || c == '_' || c == '-' || c == '~' || c == ' ';
                if (!ok) return null;
            }
            if (out.length() > 0) out.append('/');
            out.append(seg);
        }
        return out.length() == 0 ? null : out.toString();
    }

    private static String percentDecode(String s) {
        ByteArrayOutputStream b = new ByteArrayOutputStream(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '%') {
                if (i + 2 >= s.length()) return null;
                int hi = Character.digit(s.charAt(i + 1), 16);
                int lo = Character.digit(s.charAt(i + 2), 16);
                if (hi < 0 || lo < 0) return null;
                b.write((hi << 4) | lo);
                i += 2;
            } else if (c > 0x7e || c < 0x20) {
                return null;
            } else {
                b.write(c);
            }
        }
        String r = new String(b.toByteArray(), UTF8);
        if (r.indexOf('\0') >= 0 || r.indexOf('\\') >= 0) return null;
        return r;
    }

    public static String mimeFor(String path) {
        int dot = path.lastIndexOf('.');
        String ext = dot < 0 ? "" : path.substring(dot + 1).toLowerCase(Locale.ROOT);
        String m = MIME.get(ext);
        return m != null ? m : "application/octet-stream";
    }

    private static void writeHead(OutputStream out, int status, String reason, String type, int length,
                                  boolean keepAlive, String extra) throws IOException {
        StringBuilder h = new StringBuilder(256);
        h.append("HTTP/1.1 ").append(status).append(' ').append(reason).append("\r\n");
        h.append("Content-Type: ").append(type).append("\r\n");
        h.append("Content-Length: ").append(length).append("\r\n");
        h.append("Cache-Control: no-store\r\n");
        h.append("X-Content-Type-Options: nosniff\r\n");
        h.append("Referrer-Policy: no-referrer\r\n");
        h.append("Connection: ").append(keepAlive ? "keep-alive" : "close").append("\r\n");
        if (extra != null) h.append(extra);
        h.append("\r\n");
        out.write(h.toString().getBytes(UTF8));
    }

    private static void sendError(OutputStream out, int status, String msg, boolean head, boolean keepAlive)
            throws IOException {
        byte[] body = (status + " " + msg + "\n").getBytes(UTF8);
        writeHead(out, status, reasonPhrase(status), "text/plain; charset=utf-8", body.length, keepAlive, null);
        if (!head) out.write(body);
        out.flush();
    }

    private static String reasonPhrase(int s) {
        switch (s) {
            case 400: return "Bad Request";
            case 403: return "Forbidden";
            case 404: return "Not Found";
            case 405: return "Method Not Allowed";
            case 426: return "Upgrade Required";
            case 431: return "Request Header Fields Too Large";
            case 503: return "Service Unavailable";
            default: return "Error";
        }
    }

    static void closeQuietly(Socket s) {
        try { s.close(); } catch (IOException ignored) { }
    }
}
