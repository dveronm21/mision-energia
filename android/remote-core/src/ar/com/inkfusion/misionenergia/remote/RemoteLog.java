package ar.com.inkfusion.misionenergia.remote;

/** Registro de diagnóstico (en Android se conecta a android.util.Log). */
public interface RemoteLog {
    void log(String msg);

    RemoteLog NONE = new RemoteLog() {
        @Override public void log(String msg) { }
    };

    RemoteLog STDERR = new RemoteLog() {
        @Override public void log(String msg) { System.err.println("[remote] " + msg); }
    };
}
