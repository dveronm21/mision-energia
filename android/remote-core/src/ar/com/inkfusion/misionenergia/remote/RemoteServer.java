package ar.com.inkfusion.misionenergia.remote;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.BindException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Servidor del tele: HTTP + WebSocket en un puerto TCP y descubrimiento UDP.
 * Implementa del lado Java lo que necesita {@code NativeRemoteBridge} (protocol.ts):
 * {@link #getControllerUrl()}, {@link #getTvName()}, {@link #poll()}, {@link #send} y {@link #close}.
 *
 * Hilo-seguro. {@link #start()}/{@link #stop()} se pueden repetir (onStart/onStop de la Activity).
 * Al parar se cierran todas las conexiones (close 1001) y {@code poll()} entrega sus eventos close.
 */
public final class RemoteServer {

    /** Configuración. Valores por defecto = protocol.ts. */
    public static final class Options {
        public int httpPort = Protocol.HTTP_PORT;
        /** Puertos alternativos si HTTP_PORT está ocupado (la URL del QR y el DiscoveryReply llevan el real). */
        public int[] fallbackHttpPorts = {Protocol.HTTP_PORT + 10, Protocol.HTTP_PORT + 20};
        public int discoveryPort = Protocol.DISCOVERY_PORT;
        public boolean discovery = true;
        public String tvName = "Misión Energía TV";
        /** Máximo de WebSockets simultáneos (2 jugadores + margen para reconexiones y "full"). */
        public int maxWebSockets = 8;
        /** Máximo de sockets TCP simultáneos (HTTP + WS). */
        public int maxSockets = 32;
        public int maxMessageBytes = Protocol.MAX_MESSAGE_BYTES;
        /** Si es false, se rechazan WebSockets con Origin http(s) de otro host. */
        public boolean allowAnyOrigin = false;
        /** Dirección donde escuchar (null = todas). Para tests: 127.0.0.1. */
        public InetAddress bindAddress = null;
        public RemoteLog log = RemoteLog.NONE;
    }

    /** Fuente de la IP local para la URL del QR (en Android se puede sumar WifiManager como respaldo). */
    public interface AddressProvider {
        InetAddress lanAddress();
    }

    private final AssetSource assets;
    private final Options opt;
    private final EventQueue events = new EventQueue();
    private final ConnectionRegistry registry = new ConnectionRegistry();
    private final Set<Socket> sockets = Collections.synchronizedSet(new HashSet<Socket>());
    private final AtomicInteger wsCount = new AtomicInteger();
    private final AtomicInteger threadSeq = new AtomicInteger();
    private volatile AddressProvider addressProvider;
    private volatile String tvName;

    private ServerSocket serverSocket;
    private Thread acceptThread;
    private DiscoveryResponder discovery;
    private volatile boolean running;
    private volatile int boundPort = -1;

    private final HttpServer http;

    public RemoteServer(AssetSource assets, Options options) {
        this.assets = assets;
        this.opt = options != null ? options : new Options();
        this.tvName = opt.tvName;
        this.http = new HttpServer(new HttpHost());
    }

    /* ------------------------------------------------------------------ ciclo de vida */

    /** Abre el puerto TCP (probando los alternativos) y el UDP. Lanza IOException si no hay TCP. */
    public synchronized void start() throws IOException {
        if (running) return;
        ServerSocket ss = null;
        IOException last = null;
        List<Integer> ports = new ArrayList<Integer>();
        ports.add(opt.httpPort);
        if (opt.fallbackHttpPorts != null) for (int p : opt.fallbackHttpPorts) ports.add(p);
        for (int p : ports) {
            ServerSocket s = new ServerSocket();
            try {
                s.setReuseAddress(true);
                s.bind(new InetSocketAddress(opt.bindAddress, p), 16);
                ss = s;
                break;
            } catch (BindException e) {
                last = e;
                s.close();
            }
        }
        if (ss == null) throw last != null ? last : new IOException("sin puerto");
        serverSocket = ss;
        boundPort = ss.getLocalPort();
        running = true;
        final ServerSocket accepting = ss;
        acceptThread = new Thread(new Runnable() {
            @Override public void run() { acceptLoop(accepting); }
        }, "me-accept");
        acceptThread.setDaemon(true);
        acceptThread.start();
        opt.log.log("HTTP/WS escuchando en el puerto " + boundPort);

        if (opt.discovery) {
            discovery = new DiscoveryResponder(opt.discoveryPort, new DiscoveryResponder.ReplyBuilder() {
                @Override public String reply(InetAddress local) { return infoJson(local); }
            }, opt.log);
            try {
                discovery.start();
                opt.log.log("descubrimiento UDP en el puerto " + opt.discoveryPort);
            } catch (SocketException e) {
                // Sin UDP igual se puede conectar por QR o IP: no es fatal.
                opt.log.log("no se pudo abrir UDP " + opt.discoveryPort + ": " + e.getMessage());
                discovery = null;
            }
        }
    }

    /** Cierra todo: UDP, puerto TCP, WebSockets (close 1001) y sockets HTTP. Espera hasta ~1,5 s. */
    public synchronized void stop() {
        if (!running) return;
        running = false;
        if (discovery != null) {
            discovery.stop();
            discovery = null;
        }
        try {
            serverSocket.close();
        } catch (IOException ignored) { }
        registry.closeAll(WebSocketConnection.CLOSE_GOING_AWAY, "el tele se apagó", WebSocketConnection.CLOSE_WAIT_MS);
        List<Socket> rest;
        synchronized (sockets) {
            rest = new ArrayList<Socket>(sockets);
        }
        for (Socket s : rest) HttpServer.closeQuietly(s);
        if (acceptThread != null) {
            try {
                acceptThread.join(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            acceptThread = null;
        }
        // Los hilos de conexión terminan solos al cerrarse sus sockets; esperarlos un poco.
        long deadline = System.currentTimeMillis() + 1500;
        while (!sockets.isEmpty() && System.currentTimeMillis() < deadline) {
            try {
                Thread.sleep(10);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        serverSocket = null;
        boundPort = -1;
        opt.log.log("servidor detenido");
    }

    public boolean isRunning() { return running; }

    public boolean isDiscoveryRunning() {
        DiscoveryResponder d = discovery;
        return d != null && d.isRunning();
    }

    /** Puerto TCP real (−1 si está parado). */
    public int getHttpPort() { return boundPort; }

    /* ------------------------------------------------------------------ NativeRemoteBridge */

    /** "http://192.168.0.23:8765/" o "" si no hay red o el servidor está parado. */
    public String getControllerUrl() {
        int port = boundPort;
        if (!running || port < 0) return "";
        InetAddress a = lanAddress();
        if (a == null) return "";
        return "http://" + a.getHostAddress() + ":" + port + "/";
    }

    public String getTvName() { return tvName; }

    public void setTvName(String name) {
        if (name != null && !name.trim().isEmpty()) {
            String n = name.trim();
            tvName = n.length() > 40 ? n.substring(0, 40) : n;
        }
    }

    /** JSON BridgeEvent[] acumulados desde el último poll. */
    public String poll() { return events.poll(); }

    /** Envía un ServerMsg (JSON) a una conexión. @return false si no existe o se rechazó. */
    public boolean send(int connId, String json) { return registry.send(connId, json); }

    /** Cierra una conexión (close 1000 con ese motivo). */
    public void close(int connId, String reason) { registry.close(connId, reason); }

    /* ------------------------------------------------------------------ extras */

    public int connectionCount() { return registry.size(); }

    public EventQueue events() { return events; }

    public void setAddressProvider(AddressProvider p) { addressProvider = p; }

    /** DiscoveryReply JSON para la IP local dada (o la preferida). */
    public String infoJson(InetAddress local) {
        InetAddress a = local;
        if (a == null || a.isAnyLocalAddress()) a = lanAddress();
        String ip = a != null ? a.getHostAddress() : "";
        int players = Math.min(registry.size(), Protocol.MAX_PLAYERS);
        return "{\"app\":" + Json.quote(Protocol.APP_ID) + ",\"v\":" + Protocol.VERSION
                + ",\"name\":" + Json.quote(tvName) + ",\"ip\":" + Json.quote(ip)
                + ",\"port\":" + boundPort + ",\"players\":" + players
                + ",\"max\":" + Protocol.MAX_PLAYERS + "}";
    }

    private InetAddress lanAddress() {
        if (opt.bindAddress != null && !opt.bindAddress.isAnyLocalAddress()) return opt.bindAddress;
        InetAddress a = NetUtils.preferredIPv4();
        if (a == null && addressProvider != null) a = addressProvider.lanAddress();
        return a;
    }

    /* ------------------------------------------------------------------ interno */

    private void acceptLoop(ServerSocket ss) {
        while (running && !ss.isClosed()) {
            final Socket s;
            try {
                s = ss.accept();
            } catch (IOException e) {
                break;
            }
            if (sockets.size() >= opt.maxSockets || !running) {
                HttpServer.closeQuietly(s);
                continue;
            }
            sockets.add(s);
            Thread t = new Thread(new Runnable() {
                @Override public void run() {
                    try {
                        http.handle(s);
                    } catch (RuntimeException e) {
                        opt.log.log("error atendiendo conexión: " + e);
                    } finally {
                        HttpServer.closeQuietly(s);
                        sockets.remove(s);
                    }
                }
            }, "me-conn-" + threadSeq.incrementAndGet());
            t.setDaemon(true);
            t.start();
        }
    }

    private final class HttpHost implements HttpServer.Host, WebSocketConnection.Listener {
        @Override public AssetSource assets() { return assets; }

        @Override public String infoJson(InetAddress local) { return RemoteServer.this.infoJson(local); }

        @Override public boolean allowAnyOrigin() { return opt.allowAnyOrigin; }

        @Override public RemoteLog log() { return opt.log; }

        @Override
        public WebSocketConnection newWebSocket(Socket s, InputStream in, OutputStream out) {
            if (!running) return null;
            if (wsCount.incrementAndGet() > opt.maxWebSockets) {
                wsCount.decrementAndGet();
                return null;
            }
            return new WebSocketConnection(registry.newId(), s, in, out, this, opt.log, opt.maxMessageBytes);
        }

        @Override
        public void onOpen(WebSocketConnection c) {
            registry.add(c);
            events.open(c.id(), c.remoteAddress());
            opt.log.log("ws#" + c.id() + " abierto desde " + c.remoteAddress());
        }

        @Override
        public void onMessage(WebSocketConnection c, String text) {
            events.message(c.id(), text);
        }

        @Override
        public void onClosed(WebSocketConnection c, boolean wasOpen) {
            registry.remove(c);
            wsCount.decrementAndGet();
            if (!wasOpen) return;
            events.closed(c.id());
            opt.log.log("ws#" + c.id() + " cerrado");
        }
    }
}
