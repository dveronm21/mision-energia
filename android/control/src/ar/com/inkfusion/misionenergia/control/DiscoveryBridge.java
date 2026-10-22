package ar.com.inkfusion.misionenergia.control;

import android.webkit.JavascriptInterface;

import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import ar.com.inkfusion.misionenergia.remote.DiscoveryClient;
import ar.com.inkfusion.misionenergia.remote.NetUtils;
import ar.com.inkfusion.misionenergia.remote.Protocol;
import ar.com.inkfusion.misionenergia.remote.TvInfo;

/**
 * {@code window.Discovery} para assets/discovery.html. Todo lo que toca la red corre en un hilo de
 * fondo y el resultado vuelve al JS como {@code window.onNativeEvent(tipo, datos)}:
 *  - "scan"  → TvInfo[] encontrados
 *  - "probe" → {address, tv: TvInfo|null}
 */
public final class DiscoveryBridge {
    /** IPv4 o nombre de host, con puerto opcional. */
    private static final Pattern ADDRESS = Pattern.compile("^([A-Za-z0-9.-]{1,253})(?::(\\d{1,5}))?$");

    private final ControlActivity activity;
    private final ExecutorService worker;
    private volatile long lastScanAt;

    DiscoveryBridge(ControlActivity activity, ExecutorService worker) {
        this.activity = activity;
        this.worker = worker;
    }

    /** Busca teles por broadcast (y unicast al último conocido) durante timeoutMs (300–5000). */
    @JavascriptInterface
    public void scan(int timeoutMs) {
        final int t = Math.max(300, Math.min(5000, timeoutMs));
        long now = System.currentTimeMillis();
        if (now - lastScanAt < 250) return; // anti-rebote
        lastScanAt = now;
        worker.execute(new Runnable() {
            @Override public void run() {
                List<InetAddress> extra = new ArrayList<InetAddress>();
                TvInfo last = activity.lastTv();
                if (last != null) {
                    try { extra.add(InetAddress.getByName(last.ip)); } catch (Exception ignored) { }
                }
                StringBuilder b = new StringBuilder("[");
                try {
                    activity.acquireMulticastLock();
                    List<TvInfo> found = DiscoveryClient.scan(t, Protocol.DISCOVERY_PORT, extra, true);
                    for (int i = 0; i < found.size(); i++) b.append(i > 0 ? "," : "").append(found.get(i).toJson());
                } catch (Exception e) {
                    // sin red: lista vacía
                } finally {
                    activity.releaseMulticastLock();
                }
                activity.emit("scan", b.append(']').toString());
            }
        });
    }

    /** Conexión manual: "192.168.0.23" o "192.168.0.23:8765". Prueba UDP unicast y luego HTTP /api/info. */
    @JavascriptInterface
    public void probe(final String address) {
        final String a = address == null ? "" : address.trim();
        Matcher m = ADDRESS.matcher(a);
        if (!m.matches()) {
            activity.emit("probe", "{\"address\":" + ar.com.inkfusion.misionenergia.remote.Json.quote(a) + ",\"tv\":null,\"error\":\"invalid\"}");
            return;
        }
        final String host = m.group(1);
        int p = Protocol.HTTP_PORT;
        if (m.group(2) != null) p = Integer.parseInt(m.group(2));
        final int port = p;
        worker.execute(new Runnable() {
            @Override public void run() {
                TvInfo tv = null;
                if (port > 0 && port <= 65535) tv = DiscoveryClient.probe(host, port, Protocol.DISCOVERY_PORT, 2000);
                activity.emit("probe", "{\"address\":" + ar.com.inkfusion.misionenergia.remote.Json.quote(a)
                        + ",\"tv\":" + (tv == null ? "null" : tv.toJson()) + "}");
            }
        });
    }

    /** Elige un tele (JSON TvInfo, tal como vino en "scan"/"probe"). */
    @JavascriptInterface
    public void connect(String tvJson) {
        final TvInfo tv = TvInfo.parse(tvJson == null ? "" : tvJson);
        if (tv == null) return;
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { activity.connect(tv); }
        });
    }

    /** Último tele usado (JSON TvInfo) o "". */
    @JavascriptInterface
    public String getLast() {
        TvInfo t = activity.lastTv();
        return t == null ? "" : t.toJson();
    }

    @JavascriptInterface
    public void forget() {
        activity.forgetLastTv();
    }

    /** IP de esta tablet (para mostrar y diagnosticar), o "". */
    @JavascriptInterface
    public String getLocalIp() {
        InetAddress a = NetUtils.preferredIPv4();
        return a == null ? "" : a.getHostAddress();
    }

    @JavascriptInterface
    public String getVersion() {
        return activity.versionName();
    }
}
