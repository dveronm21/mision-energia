package ar.com.inkfusion.misionenergia.remote;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.SocketException;
import java.net.SocketTimeoutException;
import java.nio.charset.Charset;

/**
 * Escucha UDP en DISCOVERY_PORT. A cada datagrama cuyo contenido sea exactamente DISCOVERY_QUERY
 * le responde por unicast (al puerto de origen) con un DiscoveryReply JSON. La IP del reply es la
 * de la interfaz por la que se llega al que preguntó (no "la primera que aparece").
 * Cualquier otro contenido se ignora. Limitado a {@link #MAX_REPLIES_PER_SECOND}.
 */
public final class DiscoveryResponder {
    public static final int MAX_REPLIES_PER_SECOND = 50;
    private static final Charset ASCII = Charset.forName("US-ASCII");
    private static final Charset UTF8 = Charset.forName("UTF-8");

    /** Arma el JSON de respuesta para una IP local dada. */
    public interface ReplyBuilder {
        String reply(InetAddress localAddress);
    }

    private final int port;
    private final ReplyBuilder builder;
    private final RemoteLog log;
    private volatile DatagramSocket socket;
    private Thread thread;
    private volatile boolean running;

    public DiscoveryResponder(int port, ReplyBuilder builder, RemoteLog log) {
        this.port = port;
        this.builder = builder;
        this.log = log;
    }

    public synchronized void start() throws SocketException {
        if (running) return;
        DatagramSocket s = new DatagramSocket(null);
        s.setReuseAddress(true);
        s.setBroadcast(true);
        s.setSoTimeout(1000);
        s.bind(new InetSocketAddress(port));
        socket = s;
        running = true;
        thread = new Thread(new Runnable() {
            @Override public void run() { loop(); }
        }, "me-discovery");
        thread.setDaemon(true);
        thread.start();
    }

    public synchronized void stop() {
        running = false;
        DatagramSocket s = socket;
        if (s != null) s.close();
        socket = null;
        if (thread != null) {
            try {
                thread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            thread = null;
        }
    }

    public boolean isRunning() { return running; }

    private void loop() {
        byte[] buf = new byte[512];
        long windowStart = 0;
        int windowCount = 0;
        DatagramSocket s = socket;
        while (running && s != null && !s.isClosed()) {
            DatagramPacket p = new DatagramPacket(buf, buf.length);
            try {
                s.receive(p);
            } catch (SocketTimeoutException e) {
                continue;
            } catch (IOException e) {
                break; // socket cerrado por stop()
            }
            if (p.getLength() > 64) continue;
            String q = new String(p.getData(), p.getOffset(), p.getLength(), ASCII).trim();
            if (!Protocol.DISCOVERY_QUERY.equals(q)) continue;
            long now = System.currentTimeMillis();
            if (now - windowStart >= 1000) { windowStart = now; windowCount = 0; }
            if (++windowCount > MAX_REPLIES_PER_SECOND) continue;
            InetAddress local = NetUtils.localAddressFor(p.getAddress());
            if (local == null) local = NetUtils.preferredIPv4();
            byte[] out = builder.reply(local).getBytes(UTF8);
            try {
                s.send(new DatagramPacket(out, out.length, p.getAddress(), p.getPort()));
            } catch (IOException e) {
                log.log("discovery: no se pudo responder a " + p.getAddress() + ": " + e.getMessage());
            }
        }
    }
}
