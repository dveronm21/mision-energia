package ar.com.inkfusion.misionenergia.tv;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.ValueCallback;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.net.InetAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import ar.com.inkfusion.misionenergia.remote.RemoteLog;
import ar.com.inkfusion.misionenergia.remote.RemoteServer;

/**
 * Misión Energía TV: el juego a pantalla completa en el tele (file:///android_asset/index.html?tv=1)
 * más el servidor de control remoto (HTTP + WebSocket + descubrimiento UDP) expuesto al JS como
 * {@code window.RemoteBridge}.
 *
 * Ciclo de vida del servidor: arranca en onStart y se detiene en onStop (las tablets se reconectan
 * solas con su token al volver). Arrancar/parar se hace en un hilo propio para no trabar la UI.
 */
public class TvActivity extends Activity {
    private static final String TAG = "MisionEnergiaTV";

    private WebView web;
    private RemoteServer server;
    private WifiManager.MulticastLock multicastLock;
    private final ExecutorService control = Executors.newSingleThreadExecutor();

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        RemoteServer.Options opt = new RemoteServer.Options();
        opt.tvName = tvName();
        opt.log = new RemoteLog() {
            @Override public void log(String msg) { Log.i(TAG, msg); }
        };
        server = new RemoteServer(new AndroidAssetSource(getAssets(), "controller/"), opt);
        server.setAddressProvider(new RemoteServer.AddressProvider() {
            @Override public InetAddress lanAddress() { return wifiAddress(); }
        });

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setBackgroundColor(0xFF0E2420);
        // D-pad: la WebView tiene que tener el foco para que las flechas lleguen al JS.
        web.setFocusable(true);
        web.setFocusableInTouchMode(true);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                view.requestFocus(View.FOCUS_DOWN);
            }
        });
        web.addJavascriptInterface(new RemoteBridgeImpl(server), "RemoteBridge");
        setContentView(web);
        web.requestFocus();
        hideSystemUi();

        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState);
        } else {
            web.loadUrl("file:///android_asset/index.html?tv=1");
        }
    }

    /* ------------------------------------------------------------ servidor */

    @Override
    protected void onStart() {
        super.onStart();
        control.execute(new Runnable() {
            @Override public void run() { startServer(); }
        });
    }

    @Override
    protected void onStop() {
        control.execute(new Runnable() {
            @Override public void run() { stopServer(); }
        });
        super.onStop();
    }

    private void startServer() {
        try {
            acquireMulticastLock();
            server.start();
            Log.i(TAG, "control remoto en " + server.getControllerUrl());
        } catch (IOException e) {
            Log.e(TAG, "no se pudo iniciar el servidor remoto", e);
            releaseMulticastLock();
        }
    }

    private void stopServer() {
        server.stop();
        releaseMulticastLock();
    }

    private void acquireMulticastLock() {
        try {
            if (multicastLock == null) {
                WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                if (wm == null) return;
                multicastLock = wm.createMulticastLock("mision-energia-discovery");
                multicastLock.setReferenceCounted(false);
            }
            if (!multicastLock.isHeld()) multicastLock.acquire();
        } catch (RuntimeException e) {
            Log.w(TAG, "sin multicast lock: " + e); // tele por Ethernet o permiso denegado
        }
    }

    private void releaseMulticastLock() {
        try {
            if (multicastLock != null && multicastLock.isHeld()) multicastLock.release();
        } catch (RuntimeException ignored) { }
    }

    /** Respaldo si NetworkInterface no devuelve nada (algunos firmwares): IP que informa WifiManager. */
    private InetAddress wifiAddress() {
        try {
            WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wm == null || wm.getConnectionInfo() == null) return null;
            int ip = wm.getConnectionInfo().getIpAddress(); // little-endian
            if (ip == 0) return null;
            byte[] b = {(byte) ip, (byte) (ip >> 8), (byte) (ip >> 16), (byte) (ip >> 24)};
            return InetAddress.getByAddress(b);
        } catch (Exception e) {
            return null;
        }
    }

    /** Nombre visible del tele: el nombre del dispositivo (Ajustes › Acerca de) o el modelo. */
    private String tvName() {
        String n = null;
        try {
            n = Settings.Global.getString(getContentResolver(), "device_name");
        } catch (RuntimeException ignored) { }
        if (n == null || n.trim().isEmpty()) n = Build.MODEL;
        if (n == null || n.trim().isEmpty()) n = "Misión Energía TV";
        return n.trim();
    }

    /* ------------------------------------------------------------ teclas */

    /**
     * Control remoto del tele / gamepad:
     *  - DPAD_CENTER, A, ENTER del teclado numérico → Enter (el JS ve key "Enter"; evita que la
     *    WebView lo interprete como pulsación larga/selección de texto).
     *  - MENU, START → Escape (abre Pausa o vuelve, igual que Esc en escritorio).
     *  - Flechas: pasan tal cual a la WebView (key "ArrowUp", etc.).
     *  - BACK (y B del gamepad, que Android traduce a BACK) → onBackPressed → window.meHandleBack.
     */
    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        if (web != null) {
            if (!web.hasFocus()) web.requestFocus();
            int k = e.getKeyCode();
            int mapped = 0;
            if (k == KeyEvent.KEYCODE_DPAD_CENTER || k == KeyEvent.KEYCODE_BUTTON_A
                    || k == KeyEvent.KEYCODE_NUMPAD_ENTER) {
                mapped = KeyEvent.KEYCODE_ENTER;
            } else if (k == KeyEvent.KEYCODE_MENU || k == KeyEvent.KEYCODE_BUTTON_START) {
                mapped = KeyEvent.KEYCODE_ESCAPE;
            }
            if (mapped != 0) {
                KeyEvent m = new KeyEvent(e.getDownTime(), e.getEventTime(), e.getAction(), mapped,
                        e.getRepeatCount(), e.getMetaState(), e.getDeviceId(), e.getScanCode(),
                        e.getFlags(), e.getSource());
                return web.dispatchKeyEvent(m);
            }
        }
        return super.dispatchKeyEvent(e);
    }

    /** Botón atrás: lo maneja el juego (cierra pantallas o abre Pausa); si devuelve false, sale. */
    @Override
    public void onBackPressed() {
        if (web == null) { super.onBackPressed(); return; }
        web.evaluateJavascript("(window.meHandleBack ? window.meHandleBack() : false) ? 'true' : 'false'",
                new ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String value) {
                        if (value == null || !value.contains("true")) finish();
                    }
                });
    }

    /* ------------------------------------------------------------ pantalla */

    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUi();
            if (web != null) web.requestFocus();
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (web != null) web.saveState(outState);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (web != null) web.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) {
            web.onResume();
            web.requestFocus();
        }
        hideSystemUi();
    }

    @Override
    protected void onDestroy() {
        control.execute(new Runnable() {
            @Override public void run() { stopServer(); }
        });
        control.shutdown();
        try {
            control.awaitTermination(3, TimeUnit.SECONDS);
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        }
        if (web != null) {
            web.removeJavascriptInterface("RemoteBridge");
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
