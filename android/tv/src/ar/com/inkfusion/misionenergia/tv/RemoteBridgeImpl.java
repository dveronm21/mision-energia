package ar.com.inkfusion.misionenergia.tv;

import android.webkit.JavascriptInterface;

import ar.com.inkfusion.misionenergia.remote.RemoteServer;

/**
 * {@code window.RemoteBridge} del juego: implementa NativeRemoteBridge (app/src/remote/protocol.ts).
 * Los métodos corren en el hilo "JavaBridge" de la WebView; todos son baratos y no bloquean
 * (send() solo encola: el envío real lo hace el hilo escritor de cada WebSocket).
 */
public final class RemoteBridgeImpl {
    private static final int MAX_JSON_CHARS = 64 * 1024;
    private final RemoteServer server;

    public RemoteBridgeImpl(RemoteServer server) {
        this.server = server;
    }

    /** URL para el QR, ej. "http://192.168.0.23:8765/". Vacío si no hay red. */
    @JavascriptInterface
    public String getControllerUrl() {
        return server.getControllerUrl();
    }

    @JavascriptInterface
    public String getTvName() {
        return server.getTvName();
    }

    /** JSON BridgeEvent[] acumulados desde el último poll. */
    @JavascriptInterface
    public String poll() {
        return server.poll();
    }

    /** Envía un ServerMsg (JSON) a una conexión. */
    @JavascriptInterface
    public void send(int connId, String json) {
        if (json == null || json.length() > MAX_JSON_CHARS) return;
        server.send(connId, json);
    }

    /** Cierra una conexión. */
    @JavascriptInterface
    public void close(int connId, String reason) {
        server.close(connId, reason == null ? "" : reason);
    }
}
