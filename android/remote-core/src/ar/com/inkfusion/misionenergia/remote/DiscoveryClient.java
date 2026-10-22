package ar.com.inkfusion.misionenergia.remote;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.Proxy;
import java.net.SocketTimeoutException;
import java.net.URL;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Lado tablet del descubrimiento: manda DISCOVERY_QUERY por broadcast (255.255.255.255 y el
 * broadcast de cada interfaz LAN) y por unicast a destinos extra (ej. el último tele usado, útil
 * cuando el router bloquea broadcast), reenviando a los 0, 300 y 800 ms por si se pierde un paquete.
 * Bloqueante: llamarlo desde un hilo de fondo.
 */
public final class DiscoveryClient {
    private static final Charset UTF8 = Charset.forName("UTF-8");
    private static final int[] RESEND_AT_MS = {0, 300, 800};

    private DiscoveryClient() { }

    /** Busca teles durante {@code timeoutMs}. Resultado sin duplicados, en orden de llegada. */
    public static List<TvInfo> scan(int timeoutMs, int discoveryPort, List<InetAddress> extraTargets,
                                    boolean broadcast) throws IOException {
        Map<String, TvInfo> found = new LinkedHashMap<String, TvInfo>();
        List<InetAddress> targets = new ArrayList<InetAddress>();
        if (broadcast) targets.addAll(NetUtils.broadcastAddresses());
        if (extraTargets != null) {
            for (InetAddress a : extraTargets) if (a != null && !targets.contains(a)) targets.add(a);
        }
        byte[] q = Protocol.DISCOVERY_QUERY.getBytes(UTF8);
        DatagramSocket s = new DatagramSocket();
        try {
            s.setBroadcast(true);
            long start = System.currentTimeMillis();
            long deadline = start + timeoutMs;
            int sends = 0;
            byte[] buf = new byte[1024];
            while (true) {
                long now = System.currentTimeMillis();
                while (sends < RESEND_AT_MS.length && now - start >= RESEND_AT_MS[sends]) {
                    for (InetAddress t : targets) {
                        try {
                            s.send(new DatagramPacket(q, q.length, t, discoveryPort));
                        } catch (IOException ignored) {
                            // red sin broadcast, interfaz caída, etc.: seguir con las demás
                        }
                    }
                    sends++;
                }
                long left = deadline - now;
                if (left <= 0) break;
                long nextSend = sends < RESEND_AT_MS.length ? start + RESEND_AT_MS[sends] - now : left;
                s.setSoTimeout((int) Math.max(1, Math.min(left, nextSend)));
                DatagramPacket p = new DatagramPacket(buf, buf.length);
                try {
                    s.receive(p);
                } catch (SocketTimeoutException e) {
                    continue;
                }
                TvInfo tv = TvInfo.parse(new String(p.getData(), p.getOffset(), p.getLength(), UTF8));
                if (tv != null && !found.containsKey(tv.key())) found.put(tv.key(), tv);
            }
        } finally {
            s.close();
        }
        return new ArrayList<TvInfo>(found.values());
    }

    /**
     * Prueba una dirección escrita a mano: primero UDP unicast; si no contesta (firewall),
     * HTTP GET /api/info al puerto dado. @return el tele o null.
     */
    public static TvInfo probe(String host, int httpPort, int discoveryPort, int timeoutMs) {
        try {
            InetAddress a = InetAddress.getByName(host);
            List<InetAddress> one = new ArrayList<InetAddress>();
            one.add(a);
            List<TvInfo> r = scan(Math.max(300, timeoutMs / 2), discoveryPort, one, false);
            for (TvInfo tv : r) if (tv.port == httpPort || httpPort <= 0) return tv;
            if (!r.isEmpty()) return r.get(0);
        } catch (IOException ignored) {
            // seguimos con HTTP
        }
        return fetchInfo(host, httpPort > 0 ? httpPort : Protocol.HTTP_PORT, Math.max(500, timeoutMs / 2));
    }

    /** GET http://host:port/api/info. @return el tele o null. */
    public static TvInfo fetchInfo(String host, int port, int timeoutMs) {
        HttpURLConnection c = null;
        try {
            URL u = new URL("http", host, port, Protocol.INFO_PATH);
            c = (HttpURLConnection) u.openConnection(Proxy.NO_PROXY);
            c.setConnectTimeout(timeoutMs);
            c.setReadTimeout(timeoutMs);
            c.setUseCaches(false);
            if (c.getResponseCode() != 200) return null;
            InputStream in = c.getInputStream();
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            byte[] buf = new byte[1024];
            int n;
            while ((n = in.read(buf)) >= 0) {
                b.write(buf, 0, n);
                if (b.size() > 4096) return null;
            }
            return TvInfo.parse(new String(b.toByteArray(), UTF8));
        } catch (IOException e) {
            return null;
        } catch (IllegalArgumentException e) {
            return null;
        } finally {
            if (c != null) c.disconnect();
        }
    }
}
