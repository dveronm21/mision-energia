package ar.com.inkfusion.misionenergia.control;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.Toast;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import ar.com.inkfusion.misionenergia.remote.DiscoveryClient;
import ar.com.inkfusion.misionenergia.remote.Json;
import ar.com.inkfusion.misionenergia.remote.TvInfo;

/**
 * Misión Energía Control: tablet fija de feria.
 *
 * 1. Muestra assets/discovery.html (búsqueda de teles por UDP, conexión manual, último tele).
 * 2. Al elegir un tele navega a http://IP:PUERTO/?app=1 (la página de control la sirve el tele).
 * 3. Un vigilante consulta /api/info cada 2 s; si el tele deja de responder (o la carga falla),
 *    vuelve a discovery.html?auto=1, que busca de nuevo y se reconecta sola al mismo tele.
 *
 * Kiosco liviano: inmersivo, pantalla siempre encendida, BACK no sale. Salida oculta: mantener
 * apretada la esquina superior izquierda 5 s y escribir el PIN (1234 por defecto, se cambia ahí).
 */
public class ControlActivity extends Activity {
    private static final String PREFS = "control";
    private static final String DISCOVERY_URL = "file:///android_asset/discovery.html";
    private static final long WATCHDOG_MS = 2000;
    private static final int WATCHDOG_FAILS = 2;
    private static final long HOLD_MS = 5000;
    private static final float CORNER_DP = 96;

    private WebView web;
    private SharedPreferences prefs;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final ExecutorService watchdogWorker = Executors.newSingleThreadExecutor();
    private WifiManager.MulticastLock multicastLock;

    private volatile TvInfo current;   // tele al que estamos conectados (null = en búsqueda)
    private int watchdogFails;
    private boolean watchdogRunning;
    private float holdX, holdY;
    private boolean holding;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // el token de asiento vive en localStorage
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setCacheMode(WebSettings.LOAD_NO_CACHE);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setBackgroundColor(0xFF0E2420);
        web.setWebViewClient(new Client());
        web.addJavascriptInterface(new DiscoveryBridge(this, worker), "Discovery");
        web.addJavascriptInterface(new HapticsBridge(this), "Haptics");
        web.addJavascriptInterface(new AppBridge(), "ControlApp");
        setContentView(web);
        hideSystemUi();
        web.loadUrl(DISCOVERY_URL);
    }

    /* ------------------------------------------------------------ navegación */

    void connect(TvInfo tv) {
        prefs.edit().putString("lastTv", tv.toJson()).apply();
        current = tv;
        watchdogFails = 0;
        web.loadUrl("http://" + tv.ip + ":" + tv.port + "/?app=1");
        startWatchdog();
    }

    void goToDiscovery(String reason) {
        boolean wasConnected = current != null;
        current = null;
        stopWatchdog();
        web.loadUrl(DISCOVERY_URL + "?auto=" + (wasConnected ? "1" : "0") + "&reason=" + reason);
    }

    TvInfo lastTv() {
        String j = prefs.getString("lastTv", null);
        return j == null ? null : TvInfo.parse(j);
    }

    void forgetLastTv() {
        prefs.edit().remove("lastTv").apply();
    }

    String versionName() {
        try {
            return getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "";
        }
    }

    /** Entrega un evento a discovery.html: window.onNativeEvent(tipo, datosJSON). */
    void emit(final String type, final String json) {
        ui.post(new Runnable() {
            @Override public void run() {
                if (web == null || current != null) return; // ya no estamos en la búsqueda
                web.evaluateJavascript("window.onNativeEvent&&window.onNativeEvent(" + Json.quote(type) + "," + json + ")", null);
            }
        });
    }

    /* ------------------------------------------------------------ vigilante de conexión */

    private final Runnable watchdogTick = new Runnable() {
        @Override public void run() {
            final TvInfo tv = current;
            if (!watchdogRunning || tv == null) return;
            watchdogWorker.execute(new Runnable() {
                @Override public void run() {
                    final TvInfo info = DiscoveryClient.fetchInfo(tv.ip, tv.port, 1500);
                    ui.post(new Runnable() {
                        @Override public void run() {
                            if (!watchdogRunning || current != tv) return;
                            if (info != null) watchdogFails = 0; else watchdogFails++;
                            if (watchdogFails >= WATCHDOG_FAILS) goToDiscovery("lost");
                            else ui.postDelayed(watchdogTick, WATCHDOG_MS);
                        }
                    });
                }
            });
        }
    };

    private void startWatchdog() {
        stopWatchdog();
        watchdogRunning = true;
        ui.postDelayed(watchdogTick, WATCHDOG_MS);
    }

    private void stopWatchdog() {
        watchdogRunning = false;
        ui.removeCallbacks(watchdogTick);
    }

    /* ------------------------------------------------------------ multicast */

    synchronized void acquireMulticastLock() {
        try {
            if (multicastLock == null) {
                WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                if (wm == null) return;
                multicastLock = wm.createMulticastLock("mision-energia-control");
                multicastLock.setReferenceCounted(false);
            }
            if (!multicastLock.isHeld()) multicastLock.acquire();
        } catch (RuntimeException ignored) { }
    }

    synchronized void releaseMulticastLock() {
        try {
            if (multicastLock != null && multicastLock.isHeld()) multicastLock.release();
        } catch (RuntimeException ignored) { }
    }

    /* ------------------------------------------------------------ WebView */

    private final class Client extends WebViewClient {
        /** Kiosco: solo se navega a los assets propios o al tele elegido. */
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            if (url.startsWith("file:///android_asset/")) return false;
            TvInfo tv = current;
            return tv == null || !url.startsWith("http://" + tv.ip + ":" + tv.port + "/");
        }

        /** Falla de carga de la página principal (tele apagado, IP vieja) → volver a buscar. */
        @Override
        @SuppressWarnings("deprecation")
        public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
            if (current != null && failingUrl != null && failingUrl.startsWith("http://")) {
                goToDiscovery("error");
            }
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            if (url != null && url.startsWith("http://")) {
                // Respaldo de vibración: si la WebView no trae navigator.vibrate, lo cubre Haptics.
                view.evaluateJavascript("(function(){if(typeof navigator.vibrate!=='function'&&window.Haptics){"
                        + "navigator.vibrate=function(p){if(Array.isArray(p))Haptics.pattern(JSON.stringify(p));"
                        + "else Haptics.vibrate(Number(p)||0);return true;};}})()", null);
            }
        }
    }

    /** {@code window.ControlApp}: la página de control puede pedir volver a la búsqueda. */
    public final class AppBridge {
        @JavascriptInterface
        public void backToDiscovery() {
            ui.post(new Runnable() {
                @Override public void run() { goToDiscovery("page"); }
            });
        }

        /** Tele actual (JSON TvInfo) o "". */
        @JavascriptInterface
        public String getTv() {
            TvInfo t = current;
            return t == null ? "" : t.toJson();
        }

        @JavascriptInterface
        public boolean isApp() {
            return true;
        }
    }

    /* ------------------------------------------------------------ kiosco */

    /** Salida oculta: esquina superior izquierda apretada 5 s sin moverse. Los toques siguen llegando a la página. */
    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        float corner = CORNER_DP * getResources().getDisplayMetrics().density;
        switch (ev.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                if (ev.getX() < corner && ev.getY() < corner) {
                    holding = true;
                    holdX = ev.getX();
                    holdY = ev.getY();
                    ui.postDelayed(holdDone, HOLD_MS);
                }
                break;
            case MotionEvent.ACTION_MOVE:
                if (holding && Math.hypot(ev.getX() - holdX, ev.getY() - holdY) > corner / 2) cancelHold();
                break;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
                cancelHold();
                break;
            default:
                break;
        }
        return super.dispatchTouchEvent(ev);
    }

    private final Runnable holdDone = new Runnable() {
        @Override public void run() {
            holding = false;
            askPin();
        }
    };

    private void cancelHold() {
        holding = false;
        ui.removeCallbacks(holdDone);
    }

    private String pin() { return prefs.getString("pin", "1234"); }

    private void askPin() {
        final EditText in = new EditText(this);
        in.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        in.setHint("PIN");
        new AlertDialog.Builder(this)
                .setTitle("Menú de operador")
                .setView(in)
                .setPositiveButton("Entrar", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        if (pin().equals(in.getText().toString().trim())) operatorMenu();
                        else Toast.makeText(ControlActivity.this, "PIN incorrecto", Toast.LENGTH_SHORT).show();
                        hideSystemUi();
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void operatorMenu() {
        String[] items = {"Volver a buscar teles", "Olvidar el último tele", "Cambiar PIN", "Salir de la app"};
        new AlertDialog.Builder(this)
                .setTitle("Operador")
                .setItems(items, new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        if (which == 0) goToDiscovery("operator");
                        else if (which == 1) { forgetLastTv(); goToDiscovery("operator"); }
                        else if (which == 2) changePin();
                        else if (which == 3) finishAndExit();
                        hideSystemUi();
                    }
                })
                .show();
    }

    private void changePin() {
        final EditText in = new EditText(this);
        in.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        in.setHint("Nuevo PIN (4 a 8 dígitos)");
        new AlertDialog.Builder(this)
                .setTitle("Cambiar PIN")
                .setView(in)
                .setPositiveButton("Guardar", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        String p = in.getText().toString().trim();
                        if (p.matches("\\d{4,8}")) {
                            prefs.edit().putString("pin", p).apply();
                            Toast.makeText(ControlActivity.this, "PIN guardado", Toast.LENGTH_SHORT).show();
                        } else {
                            Toast.makeText(ControlActivity.this, "El PIN debe tener de 4 a 8 dígitos", Toast.LENGTH_LONG).show();
                        }
                        hideSystemUi();
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void finishAndExit() {
        stopWatchdog();
        finish();
    }

    /** Kiosco: BACK no sale de la app (la salida es por el menú de operador). */
    @Override
    public void onBackPressed() {
        // nada
    }

    /* ------------------------------------------------------------ pantalla y ciclo de vida */

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
        if (hasFocus) hideSystemUi();
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopWatchdog();
        if (web != null) web.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) web.onResume();
        if (current != null) startWatchdog();
        hideSystemUi();
    }

    @Override
    protected void onDestroy() {
        stopWatchdog();
        cancelHold();
        worker.shutdownNow();
        watchdogWorker.shutdownNow();
        releaseMulticastLock();
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
