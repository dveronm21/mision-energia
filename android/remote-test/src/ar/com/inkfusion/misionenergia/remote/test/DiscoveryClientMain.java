package ar.com.inkfusion.misionenergia.remote.test;

import ar.com.inkfusion.misionenergia.remote.DiscoveryClient;
import ar.com.inkfusion.misionenergia.remote.TvInfo;

import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;

/**
 * Prueba del lado tablet (el mismo código que usa la app Control).
 * Uso: DiscoveryClientMain <udpPort> <httpPort>
 * Imprime "SCAN <json>" (broadcast + unicast a 127.0.0.1) y "PROBE <json>" (conexión manual).
 */
public final class DiscoveryClientMain {
    public static void main(String[] args) throws Exception {
        int udp = Integer.parseInt(args[0]);
        int http = Integer.parseInt(args[1]);
        List<InetAddress> extra = new ArrayList<InetAddress>();
        extra.add(InetAddress.getByName("127.0.0.1"));
        long t0 = System.nanoTime();
        List<TvInfo> found = DiscoveryClient.scan(1000, udp, extra, true);
        StringBuilder b = new StringBuilder("[");
        for (int i = 0; i < found.size(); i++) b.append(i > 0 ? "," : "").append(found.get(i).toJson());
        System.out.println("SCAN " + b.append(']') + " ms=" + (System.nanoTime() - t0) / 1000000);
        TvInfo p = DiscoveryClient.probe("127.0.0.1", http, udp, 1000);
        System.out.println("PROBE " + (p == null ? "null" : p.toJson()));
        // Fallback HTTP: puerto UDP equivocado → tiene que encontrarlo por /api/info
        TvInfo h = DiscoveryClient.probe("127.0.0.1", http, udp + 1000, 1000);
        System.out.println("PROBEHTTP " + (h == null ? "null" : h.toJson()));
    }
}
