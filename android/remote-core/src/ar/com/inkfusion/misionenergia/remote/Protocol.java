package ar.com.inkfusion.misionenergia.remote;

/**
 * Constantes del protocolo de control remoto. Espejo de app/src/remote/protocol.ts
 * (la fuente de verdad): si cambia algo allá, cambiarlo acá.
 */
public final class Protocol {
    private Protocol() { }

    public static final int VERSION = 1;
    public static final int HTTP_PORT = 8765;
    public static final int DISCOVERY_PORT = 8766;
    public static final String DISCOVERY_QUERY = "MISION-ENERGIA-DISCOVER-1";
    public static final int MAX_PLAYERS = 2;
    public static final String APP_ID = "mision-energia-tv";

    /** Ruta del WebSocket del protocolo. */
    public static final String WS_PATH = "/ws";
    /** Extensión compatible (documentada en docs/REMOTE_PROTOCOL.md): GET devuelve DiscoveryReply JSON. */
    public static final String INFO_PATH = "/api/info";

    /** Tamaño máximo de un mensaje WebSocket (entrante o saliente), en bytes. */
    public static final int MAX_MESSAGE_BYTES = 64 * 1024;
}
