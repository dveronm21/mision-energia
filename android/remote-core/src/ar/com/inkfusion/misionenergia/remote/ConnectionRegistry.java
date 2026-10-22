package ar.com.inkfusion.misionenergia.remote;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** Conexiones WebSocket abiertas, por id. Hilo-seguro: send/close se llaman desde el hilo del JS. */
public final class ConnectionRegistry {
    private final ConcurrentHashMap<Integer, WebSocketConnection> map =
            new ConcurrentHashMap<Integer, WebSocketConnection>();
    private final AtomicInteger nextId = new AtomicInteger(1);

    int newId() { return nextId.getAndIncrement(); }

    void add(WebSocketConnection c) { map.put(c.id(), c); }

    void remove(WebSocketConnection c) { map.remove(c.id(), c); }

    public WebSocketConnection get(int id) { return map.get(id); }

    public int size() { return map.size(); }

    /** Envía texto a una conexión. @return false si no existe, está cerrada o el mensaje es inválido. */
    public boolean send(int id, String text) {
        WebSocketConnection c = map.get(id);
        return c != null && c.sendText(text);
    }

    /** Cierra una conexión con código 1000 y el motivo dado. */
    public void close(int id, String reason) {
        WebSocketConnection c = map.get(id);
        if (c != null) c.close(WebSocketConnection.CLOSE_NORMAL, reason);
    }

    /** Cierra todas (apagado). Bloquea a lo sumo {@code waitMs} esperando que terminen. */
    public void closeAll(int code, String reason, long waitMs) {
        List<WebSocketConnection> all = new ArrayList<WebSocketConnection>(map.values());
        for (WebSocketConnection c : all) c.close(code, reason);
        long deadline = System.currentTimeMillis() + waitMs;
        for (WebSocketConnection c : all) {
            long left = deadline - System.currentTimeMillis();
            if (!c.awaitClosed(Math.max(1, left))) c.abort();
        }
    }
}
