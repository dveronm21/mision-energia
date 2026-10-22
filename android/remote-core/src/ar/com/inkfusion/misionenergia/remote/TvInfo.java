package ar.com.inkfusion.misionenergia.remote;

import java.util.Map;

/** DiscoveryReply: un tele encontrado en la red. */
public final class TvInfo {
    public final String app;
    public final int v;
    public final String name;
    public final String ip;
    public final int port;
    public final int players;
    public final int max;

    public TvInfo(String app, int v, String name, String ip, int port, int players, int max) {
        this.app = app;
        this.v = v;
        this.name = name;
        this.ip = ip;
        this.port = port;
        this.players = players;
        this.max = max;
    }

    /** Parsea un DiscoveryReply. Devuelve null si no es de nuestra app o le faltan datos. */
    public static TvInfo parse(String json) {
        try {
            Map<String, Object> m = Json.parseObject(json);
            String app = Json.str(m, "app", null);
            String ip = Json.str(m, "ip", null);
            int port = Json.num(m, "port", -1);
            if (!Protocol.APP_ID.equals(app) || ip == null || port <= 0 || port > 65535) return null;
            String name = Json.str(m, "name", "Tele");
            if (name.length() > 64) name = name.substring(0, 64);
            return new TvInfo(app, Json.num(m, "v", 0), name, ip, port,
                    Json.num(m, "players", 0), Json.num(m, "max", Protocol.MAX_PLAYERS));
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    public String toJson() {
        return "{\"app\":" + Json.quote(app) + ",\"v\":" + v + ",\"name\":" + Json.quote(name)
                + ",\"ip\":" + Json.quote(ip) + ",\"port\":" + port + ",\"players\":" + players
                + ",\"max\":" + max + "}";
    }

    public String key() { return ip + ":" + port; }
}
