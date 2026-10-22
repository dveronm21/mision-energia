package ar.com.inkfusion.misionenergia.remote;

import java.io.ByteArrayOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Conexión WebSocket (RFC 6455) del lado servidor, solo mensajes de texto.
 *
 * Hilos: el hilo que llama {@link #run(byte[])} lee frames; un hilo escritor propio envía la cola de salida
 * (así {@link #sendText} nunca bloquea al hilo del JS) y manda un ping cada {@link #PING_INTERVAL_MS}
 * si no hubo tráfico saliente. Si no llega nada del cliente en {@link #READ_TIMEOUT_MS} la conexión se
 * da por muerta (el cliente manda input cada 100 ms y responde los pings).
 */
public final class WebSocketConnection {
    public static final int CLOSE_NORMAL = 1000;
    public static final int CLOSE_GOING_AWAY = 1001;
    public static final int CLOSE_PROTOCOL_ERROR = 1002;
    public static final int CLOSE_UNSUPPORTED = 1003;
    public static final int CLOSE_INVALID_DATA = 1007;
    public static final int CLOSE_POLICY = 1008;
    public static final int CLOSE_TOO_BIG = 1009;
    public static final int CLOSE_INTERNAL = 1011;

    public static final int PING_INTERVAL_MS = 5000;
    public static final int READ_TIMEOUT_MS = 15000;
    public static final int CLOSE_WAIT_MS = 1000;
    public static final int SEND_QUEUE_MAX = 512;

    private static final String GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    private static final Charset UTF8 = Charset.forName("UTF-8");
    private static final byte[] POISON = new byte[0];

    /** Recibe el ciclo de vida de la conexión (lo implementa RemoteServer). */
    interface Listener {
        void onOpen(WebSocketConnection c);
        void onMessage(WebSocketConnection c, String text);
        /** @param wasOpen false si el handshake no llegó a completarse (no hubo onOpen). */
        void onClosed(WebSocketConnection c, boolean wasOpen);
    }

    private final int id;
    private final Socket socket;
    private final InputStream in;
    private final OutputStream out;
    private final String remoteAddress;
    private final Listener listener;
    private final RemoteLog log;
    private final int maxMessage;

    private final LinkedBlockingQueue<byte[]> queue = new LinkedBlockingQueue<byte[]>();
    private final AtomicBoolean closeQueued = new AtomicBoolean(false);
    private final AtomicBoolean finished = new AtomicBoolean(false);
    private final CountDownLatch readerDone = new CountDownLatch(1);
    private final CountDownLatch closedLatch = new CountDownLatch(1);
    private volatile byte[] closeFrame;
    private volatile boolean opened;
    private Thread writer;

    WebSocketConnection(int id, Socket socket, InputStream in, OutputStream out,
                        Listener listener, RemoteLog log, int maxMessage) {
        this.id = id;
        this.socket = socket;
        this.in = in;
        this.out = out;
        this.listener = listener;
        this.log = log;
        this.maxMessage = maxMessage;
        String a = socket.getInetAddress() != null ? socket.getInetAddress().getHostAddress() : "?";
        this.remoteAddress = a;
    }

    public int id() { return id; }

    public String remoteAddress() { return remoteAddress; }

    public boolean isOpen() { return !closeQueued.get() && !finished.get(); }

    /** Sec-WebSocket-Accept = base64(sha1(key + GUID)). */
    public static String acceptKey(String key) {
        try {
            MessageDigest sha1 = MessageDigest.getInstance("SHA-1");
            return Base64Codec.encode(sha1.digest((key + GUID).getBytes(UTF8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /**
     * Encola un mensaje de texto. No bloquea.
     * @return false si la conexión está cerrando, el texto supera el máximo o la cola está llena
     *         (en ese caso el cliente es demasiado lento y se lo desconecta).
     */
    public boolean sendText(String text) {
        if (text == null || !isOpen()) return false;
        byte[] payload = text.getBytes(UTF8);
        if (payload.length > maxMessage) {
            log.log("ws#" + id + ": mensaje saliente demasiado grande (" + payload.length + " B), descartado");
            return false;
        }
        if (queue.size() >= SEND_QUEUE_MAX) {
            close(CLOSE_POLICY, "cliente lento");
            return false;
        }
        queue.offer(frame(0x1, payload));
        return true;
    }

    /** Inicia el cierre ordenado (envía frame close y espera la respuesta hasta CLOSE_WAIT_MS). */
    public void close(int code, String reason) {
        if (!closeQueued.compareAndSet(false, true)) return;
        byte[] f = closeFramePayload(code, reason);
        closeFrame = frame(0x8, f);
        queue.offer(closeFrame);
    }

    /** Corta el socket sin handshake de cierre. */
    public void abort() { HttpServer.closeQuietly(socket); }

    /** Espera a que la conexión termine. @return true si terminó. */
    public boolean awaitClosed(long ms) {
        try {
            return closedLatch.await(ms, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }

    /**
     * Envía la respuesta 101 del handshake y queda leyendo. Bloquea hasta el cierre; al salir el
     * socket queda cerrado y el listener notificado exactamente una vez.
     */
    void run(byte[] handshakeResponse) {
        try {
            out.write(handshakeResponse);
            out.flush();
        } catch (IOException e) {
            abort();
            finish();
            return;
        }
        writer = new Thread(new Runnable() {
            @Override public void run() { writeLoop(); }
        }, "me-ws-" + id + "-tx");
        writer.setDaemon(true);
        try {
            socket.setSoTimeout(READ_TIMEOUT_MS);
            writer.start();
            opened = true;
            listener.onOpen(this);
            readLoop();
        } catch (SocketTimeoutException e) {
            log.log("ws#" + id + ": sin datos en " + READ_TIMEOUT_MS + " ms, se cierra");
        } catch (IOException e) {
            // EOF o socket cerrado
        } catch (RuntimeException e) {
            log.log("ws#" + id + ": error " + e);
        } finally {
            readerDone.countDown();
            if (!closeQueued.get()) abort();     // sin handshake de cierre: nada que enviar
            queue.offer(POISON);
            if (writer.isAlive()) {
                try {
                    writer.join(CLOSE_WAIT_MS + 1000);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            abort();
            if (writer.isAlive()) writer.interrupt();
            finish();
        }
    }

    private void finish() {
        if (!finished.compareAndSet(false, true)) return;
        try {
            listener.onClosed(this, opened);
        } finally {
            closedLatch.countDown();
        }
    }

    private void readLoop() throws IOException {
        ByteArrayOutputStream message = null; // mensaje fragmentado en curso
        while (true) {
            int b0 = readByte();
            int b1 = readByte();
            boolean fin = (b0 & 0x80) != 0;
            int opcode = b0 & 0x0f;
            if ((b0 & 0x70) != 0) { protocolError("bits RSV"); return; }
            if ((b1 & 0x80) == 0) { protocolError("frame sin máscara"); return; }
            long len = b1 & 0x7f;
            if (len == 126) {
                len = (readByte() << 8) | readByte();
            } else if (len == 127) {
                len = 0;
                for (int i = 0; i < 8; i++) len = (len << 8) | readByte();
                if (len < 0) { protocolError("largo inválido"); return; }
            }
            boolean control = opcode >= 0x8;
            if (control && (!fin || len > 125)) { protocolError("frame de control inválido"); return; }
            int current = message == null ? 0 : message.size();
            if (!control && len + current > maxMessage) {
                log.log("ws#" + id + ": mensaje entrante supera " + maxMessage + " B");
                close(CLOSE_TOO_BIG, "mensaje demasiado grande");
                return;
            }
            byte[] mask = new byte[4];
            readFully(mask);
            byte[] payload = new byte[(int) len];
            readFully(payload);
            for (int i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];

            switch (opcode) {
                case 0x0: // continuación
                    if (message == null) { protocolError("continuación inesperada"); return; }
                    message.write(payload, 0, payload.length);
                    if (fin) {
                        if (!deliver(message.toByteArray())) return;
                        message = null;
                    }
                    break;
                case 0x1: // texto
                    if (message != null) { protocolError("mensaje nuevo dentro de un fragmentado"); return; }
                    if (fin) {
                        if (!deliver(payload)) return;
                    } else {
                        message = new ByteArrayOutputStream(Math.max(256, payload.length * 2));
                        message.write(payload, 0, payload.length);
                    }
                    break;
                case 0x2: // binario
                    close(CLOSE_UNSUPPORTED, "solo texto");
                    return;
                case 0x8: { // close
                    int code = CLOSE_NORMAL;
                    if (payload.length == 1) code = CLOSE_PROTOCOL_ERROR;
                    else if (payload.length >= 2) {
                        code = ((payload[0] & 0xff) << 8) | (payload[1] & 0xff);
                        if (!validCloseCode(code)) code = CLOSE_PROTOCOL_ERROR;
                    }
                    close(code, ""); // si lo iniciamos nosotros, esto no hace nada
                    return;
                }
                case 0x9: // ping → pong con el mismo contenido
                    if (!closeQueued.get()) queue.offer(frame(0xA, payload));
                    break;
                case 0xA: // pong
                    break;
                default:
                    protocolError("opcode " + opcode);
                    return;
            }
        }
    }

    private boolean deliver(byte[] utf8) {
        String text;
        try {
            text = UTF8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(utf8)).toString();
        } catch (CharacterCodingException e) {
            close(CLOSE_INVALID_DATA, "UTF-8 inválido");
            return false;
        }
        if (!closeQueued.get()) listener.onMessage(this, text);
        return true;
    }

    private void protocolError(String why) {
        log.log("ws#" + id + ": error de protocolo: " + why);
        close(CLOSE_PROTOCOL_ERROR, why);
    }

    private static boolean validCloseCode(int c) {
        return (c >= 1000 && c <= 1003) || (c >= 1007 && c <= 1011) || (c >= 3000 && c <= 4999);
    }

    private void writeLoop() {
        try {
            while (true) {
                byte[] f = queue.poll(PING_INTERVAL_MS, TimeUnit.MILLISECONDS);
                if (f == null) {
                    f = frame(0x9, new byte[0]); // keepalive del servidor
                }
                if (f == POISON) {
                    out.flush();
                    return;
                }
                out.write(f);
                if (f == closeFrame) {
                    out.flush();
                    // Esperar el close del cliente (o que el lector termine) y cerrar TCP: lo hace el servidor.
                    long t0 = System.currentTimeMillis();
                    readerDone.await(CLOSE_WAIT_MS, TimeUnit.MILLISECONDS);
                    try { socket.shutdownOutput(); } catch (IOException ignored) { }
                    drainInput(CLOSE_WAIT_MS - (System.currentTimeMillis() - t0));
                    abort();
                    return;
                }
                if (queue.isEmpty()) out.flush();
            }
        } catch (IOException e) {
            abort();
        } catch (InterruptedException e) {
            abort();
        }
    }

    /**
     * Si el lector salió antes de tiempo (ej. mensaje demasiado grande), descarta lo que el cliente
     * siga mandando hasta que cierre, así el cierre TCP no es un RST que le haga perder el frame close.
     */
    private void drainInput(long ms) {
        if (ms <= 0 || readerDone.getCount() > 0) return;
        long deadline = System.currentTimeMillis() + ms;
        byte[] buf = new byte[8192];
        long total = 0;
        try {
            while (total < 4L * maxMessage) {
                long left = deadline - System.currentTimeMillis();
                if (left <= 0) return;
                socket.setSoTimeout((int) Math.max(1, left));
                int r = in.read(buf);
                if (r < 0) return;
                total += r;
            }
        } catch (IOException ignored) {
            // timeout o cerrado
        }
    }

    private int readByte() throws IOException {
        int b = in.read();
        if (b < 0) throw new EOFException();
        return b;
    }

    private void readFully(byte[] b) throws IOException {
        int off = 0;
        while (off < b.length) {
            int r = in.read(b, off, b.length - off);
            if (r < 0) throw new EOFException();
            off += r;
        }
    }

    private static byte[] closeFramePayload(int code, String reason) {
        byte[] r = reason == null ? new byte[0] : reason.getBytes(UTF8);
        if (r.length > 123) { // los frames de control llevan como máximo 125 bytes
            int n = 123;
            while (n > 0 && (r[n] & 0xC0) == 0x80) n--; // no cortar un carácter UTF-8 a la mitad
            byte[] t = new byte[n];
            System.arraycopy(r, 0, t, 0, n);
            r = t;
        }
        byte[] p = new byte[2 + r.length];
        p[0] = (byte) (code >> 8);
        p[1] = (byte) code;
        System.arraycopy(r, 0, p, 2, r.length);
        return p;
    }

    /** Frame del servidor (sin máscara, FIN=1). */
    static byte[] frame(int opcode, byte[] payload) {
        int len = payload.length;
        int headLen = len < 126 ? 2 : (len <= 0xFFFF ? 4 : 10);
        byte[] f = new byte[headLen + len];
        f[0] = (byte) (0x80 | opcode);
        if (len < 126) {
            f[1] = (byte) len;
        } else if (len <= 0xFFFF) {
            f[1] = 126;
            f[2] = (byte) (len >> 8);
            f[3] = (byte) len;
        } else {
            f[1] = 127;
            for (int i = 0; i < 8; i++) f[2 + i] = (byte) (((long) len) >> (56 - 8 * i));
        }
        System.arraycopy(payload, 0, f, headLen, len);
        return f;
    }
}
