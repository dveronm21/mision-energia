package ar.com.inkfusion.misionenergia.remote;

import java.util.ArrayList;
import java.util.List;

/**
 * Cola hilo-segura de BridgeEvent ({@code open}/{@code msg}/{@code close}) que el juego vacía con
 * {@link #poll()} una vez por frame.
 *
 * Si el JS deja de leer (WebView pausada), la cola no crece sin límite: por encima de
 * {@link #MAX_PENDING_MSGS} se descartan los {@code msg} nuevos (el protocolo es de estado
 * completo + keepalive, así que no se pierde nada importante). Los {@code open}/{@code close}
 * nunca se descartan.
 */
public final class EventQueue {
    public static final int MAX_PENDING_MSGS = 4096;

    private final List<String> events = new ArrayList<String>();
    private int pendingMsgs;
    private long dropped;

    public synchronized void open(int id, String addr) {
        events.add("{\"e\":\"open\",\"id\":" + id + ",\"addr\":" + Json.quote(addr) + "}");
    }

    public synchronized void message(int id, String data) {
        if (pendingMsgs >= MAX_PENDING_MSGS) {
            dropped++;
            return;
        }
        pendingMsgs++;
        events.add("{\"e\":\"msg\",\"id\":" + id + ",\"data\":" + Json.quote(data) + "}");
    }

    public synchronized void closed(int id) {
        events.add("{\"e\":\"close\",\"id\":" + id + "}");
    }

    /** JSON array con los eventos acumulados desde la última llamada ("[]" si no hay). */
    public String poll() {
        List<String> batch;
        synchronized (this) {
            if (events.isEmpty()) return "[]";
            batch = new ArrayList<String>(events);
            events.clear();
            pendingMsgs = 0;
        }
        int len = 2;
        for (String s : batch) len += s.length() + 1;
        StringBuilder b = new StringBuilder(len);
        b.append('[');
        for (int i = 0; i < batch.size(); i++) {
            if (i > 0) b.append(',');
            b.append(batch.get(i));
        }
        return b.append(']').toString();
    }

    public synchronized int size() { return events.size(); }

    public synchronized long droppedCount() { return dropped; }

    public synchronized void clear() {
        events.clear();
        pendingMsgs = 0;
    }
}
