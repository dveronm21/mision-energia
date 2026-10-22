package ar.com.inkfusion.misionenergia.remote.test;

import ar.com.inkfusion.misionenergia.remote.DirectoryAssetSource;
import ar.com.inkfusion.misionenergia.remote.Json;
import ar.com.inkfusion.misionenergia.remote.RemoteLog;
import ar.com.inkfusion.misionenergia.remote.RemoteServer;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.util.List;
import java.util.Map;

/**
 * Servidor de prueba para los tests de escritorio. Hace de "juego": vacía poll() cada 0,2 ms (el juego real lo
 * hace una vez por frame, ~16 ms) y devuelve cada mensaje (eco). Comandos especiales por mensaje:
 * "__close__" → el servidor cierra esa conexión; "__stats__" → responde contadores.
 * Por stdin: "quit" para apagar; al final informa los hilos "me-*" vivos (fuga = falla).
 *
 * Uso: java -cp ... TestServerMain <www> <httpPort> <udpPort>
 */
public final class TestServerMain {
    public static void main(String[] args) throws Exception {
        File www = new File(args.length > 0 ? args[0] : "www");
        RemoteServer.Options o = new RemoteServer.Options();
        o.httpPort = args.length > 1 ? Integer.parseInt(args[1]) : 18765;
        o.fallbackHttpPorts = new int[0];
        o.discoveryPort = args.length > 2 ? Integer.parseInt(args[2]) : 18766;
        o.tvName = "Tele de prueba";
        o.log = System.getenv("ME_VERBOSE") != null ? RemoteLog.STDERR : RemoteLog.NONE;
        final RemoteServer server = new RemoteServer(new DirectoryAssetSource(www), o);
        server.setAddressProvider(new RemoteServer.AddressProvider() {
            @Override public InetAddress lanAddress() { return InetAddress.getLoopbackAddress(); }
        });
        server.start();
        final boolean[] stop = {false};
        final long[] counters = new long[3]; // open, msg, close
        Thread game = new Thread(new Runnable() {
            @Override public void run() {
                while (!stop[0]) {
                    String batch = server.poll();
                    if (!"[]".equals(batch)) {
                        List<Map<String, Object>> evs = Json.parseObjectArray(batch);
                        for (Map<String, Object> e : evs) {
                            String kind = Json.str(e, "e", "");
                            int id = Json.num(e, "id", -1);
                            if ("open".equals(kind)) {
                                counters[0]++;
                                System.out.println("EVT open " + id + " " + Json.str(e, "addr", ""));
                            } else if ("close".equals(kind)) {
                                counters[2]++;
                                System.out.println("EVT close " + id);
                            } else if ("msg".equals(kind)) {
                                counters[1]++;
                                String data = Json.str(e, "data", "");
                                if ("__close__".equals(data)) server.close(id, "cerrado por el juego");
                                else if ("__stats__".equals(data)) server.send(id, "{\"open\":" + counters[0]
                                        + ",\"msg\":" + counters[1] + ",\"close\":" + counters[2]
                                        + ",\"conns\":" + server.connectionCount()
                                        + ",\"url\":" + Json.quote(server.getControllerUrl()) + "}");
                                else server.send(id, data);
                            }
                        }
                        System.out.flush();
                    }
                    java.util.concurrent.locks.LockSupport.parkNanos(200000L); // 0,2 ms: mide el transporte, no el frame
                }
            }
        }, "test-game");
        game.start();
        System.out.println("READY " + server.getHttpPort() + " " + server.getControllerUrl());
        System.out.flush();

        BufferedReader in = new BufferedReader(new InputStreamReader(System.in, "UTF-8"));
        String line;
        while ((line = in.readLine()) != null) {
            if (line.trim().equals("quit")) break;
        }
        long t0 = System.currentTimeMillis();
        server.stop();
        long stopMs = System.currentTimeMillis() - t0;
        stop[0] = true;
        game.join(1000);
        System.out.println("FINAL " + server.poll());
        Thread.sleep(200);
        int leaked = 0;
        StringBuilder names = new StringBuilder();
        for (Thread t : Thread.getAllStackTraces().keySet()) {
            if (t.getName().startsWith("me-") && t.isAlive()) {
                leaked++;
                names.append(t.getName()).append(' ');
            }
        }
        System.out.println("STOPPED stopMs=" + stopMs + " leakedThreads=" + leaked + " " + names);
        System.out.flush();
        System.exit(leaked == 0 ? 0 : 3);
    }
}
