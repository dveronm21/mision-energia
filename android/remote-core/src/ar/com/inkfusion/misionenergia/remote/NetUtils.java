package ar.com.inkfusion.misionenergia.remote;

import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.List;
import java.util.Locale;

/** Utilidades de red: IP LAN preferida (Wi-Fi/Ethernet), direcciones de broadcast. Solo IPv4. */
public final class NetUtils {
    private NetUtils() { }

    /** Prefijos de interfaces que nunca son la LAN local (datos móviles, VPN, túneles). */
    private static final String[] EXCLUDED = {
            "rmnet", "ccmni", "pdp", "ppp", "tun", "dummy", "clat", "v4-", "ipsec", "ip6tnl",
            "sit", "gre", "erspan", "ifb", "veth", "lo"
    };

    /** IPv4 de la interfaz LAN preferida, o null si no hay red. */
    public static InetAddress preferredIPv4() {
        List<Candidate> list = candidates();
        return list.isEmpty() ? null : list.get(0).address;
    }

    /** Todas las IPv4 LAN utilizables, de mejor a peor. */
    public static List<InetAddress> lanIPv4s() {
        List<InetAddress> out = new ArrayList<InetAddress>();
        for (Candidate c : candidates()) out.add(c.address);
        return out;
    }

    /** Direcciones de broadcast de las interfaces LAN (ej. 192.168.0.255), más 255.255.255.255. */
    public static List<InetAddress> broadcastAddresses() {
        List<InetAddress> out = new ArrayList<InetAddress>();
        for (Candidate c : candidates()) {
            if (c.broadcast != null && !out.contains(c.broadcast)) out.add(c.broadcast);
        }
        try {
            InetAddress all = InetAddress.getByName("255.255.255.255");
            if (!out.contains(all)) out.add(all);
        } catch (Exception ignored) { }
        return out;
    }

    /**
     * IP local que el sistema usaría para llegar a {@code remote}: la de la interfaz por la que
     * llegó una consulta. Se obtiene "conectando" un socket UDP (no envía paquetes).
     */
    public static InetAddress localAddressFor(InetAddress remote) {
        DatagramSocket s = null;
        try {
            s = new DatagramSocket();
            s.connect(new InetSocketAddress(remote, 9));
            InetAddress a = s.getLocalAddress();
            if (a != null && !a.isAnyLocalAddress() && a instanceof Inet4Address) return a;
        } catch (Exception ignored) {
        } finally {
            if (s != null) s.close();
        }
        return null;
    }

    public static boolean isUsableName(String name) {
        String n = name == null ? "" : name.toLowerCase(Locale.ROOT);
        for (String p : EXCLUDED) if (n.startsWith(p)) return false;
        return true;
    }

    /** Puntaje por nombre de interfaz: Wi-Fi primero, luego Ethernet, hotspot, el resto. */
    static int score(String name) {
        String n = name == null ? "" : name.toLowerCase(Locale.ROOT);
        if (n.startsWith("wlan") || n.startsWith("wl")) return 100;
        if (n.startsWith("eth") || n.startsWith("en")) return 90;
        if (n.startsWith("ap") || n.startsWith("swlan") || n.startsWith("softap")) return 80;
        if (n.startsWith("docker") || n.startsWith("br-") || n.startsWith("virbr")) return 5;
        return 20;
    }

    private static final class Candidate implements Comparable<Candidate> {
        final InetAddress address;
        final InetAddress broadcast;
        final int score;

        Candidate(InetAddress a, InetAddress b, int s) { address = a; broadcast = b; score = s; }

        @Override
        public int compareTo(Candidate o) {
            if (score != o.score) return o.score - score;
            // Preferir redes privadas (192.168 > 10 > 172.16) a direcciones públicas raras.
            return privateRank(o.address) - privateRank(address);
        }
    }

    static int privateRank(InetAddress a) {
        byte[] b = a.getAddress();
        int b0 = b[0] & 0xff, b1 = b[1] & 0xff;
        if (b0 == 192 && b1 == 168) return 3;
        if (b0 == 10) return 2;
        if (b0 == 172 && b1 >= 16 && b1 < 32) return 1;
        return 0;
    }

    private static List<Candidate> candidates() {
        List<Candidate> out = new ArrayList<Candidate>();
        Enumeration<NetworkInterface> en;
        try {
            en = NetworkInterface.getNetworkInterfaces();
        } catch (SocketException e) {
            return out;
        }
        if (en == null) return out;
        while (en.hasMoreElements()) {
            NetworkInterface ni = en.nextElement();
            try {
                if (!ni.isUp() || ni.isLoopback() || ni.isVirtual() || ni.isPointToPoint()) continue;
            } catch (SocketException e) {
                continue;
            }
            if (!isUsableName(ni.getName())) continue;
            int sc = score(ni.getName());
            for (InterfaceAddress ia : ni.getInterfaceAddresses()) {
                InetAddress a = ia.getAddress();
                if (!(a instanceof Inet4Address)) continue;           // ignora IPv6
                if (a.isLoopbackAddress() || a.isLinkLocalAddress() || a.isAnyLocalAddress()) continue;
                out.add(new Candidate(a, ia.getBroadcast(), sc));
            }
        }
        Collections.sort(out);
        return out;
    }
}
