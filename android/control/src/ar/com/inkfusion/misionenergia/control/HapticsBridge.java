package ar.com.inkfusion.misionenergia.control;

import android.content.Context;
import android.os.Vibrator;
import android.webkit.JavascriptInterface;

/**
 * {@code window.Haptics}: vibración nativa, respaldo por si navigator.vibrate no existe o no hace
 * nada en la WebView. Valores acotados (nunca más de 1 s por pulso ni más de 20 pasos).
 */
public final class HapticsBridge {
    private final Vibrator vibrator;

    HapticsBridge(Context ctx) {
        vibrator = (Vibrator) ctx.getApplicationContext().getSystemService(Context.VIBRATOR_SERVICE);
    }

    @JavascriptInterface
    public void vibrate(int ms) {
        if (vibrator == null || ms <= 0) return;
        try {
            vibrator.vibrate(Math.min(ms, 1000));
        } catch (RuntimeException ignored) { }
    }

    /** Patrón como navigator.vibrate: "[vibra, pausa, vibra, ...]" en ms. */
    @JavascriptInterface
    public void pattern(String json) {
        if (vibrator == null || json == null || json.length() > 400) return;
        String s = json.trim();
        if (s.startsWith("[")) s = s.substring(1);
        if (s.endsWith("]")) s = s.substring(0, s.length() - 1);
        String[] parts = s.split(",");
        if (parts.length == 0 || parts.length > 20) return;
        long[] p = new long[parts.length + 1]; // Vibrator: [espera inicial, vibra, pausa, ...]
        try {
            for (int i = 0; i < parts.length; i++) {
                long v = Math.round(Double.parseDouble(parts[i].trim()));
                p[i + 1] = Math.max(0, Math.min(1000, v));
            }
        } catch (NumberFormatException e) {
            return;
        }
        try {
            vibrator.vibrate(p, -1);
        } catch (RuntimeException ignored) { }
    }

    @JavascriptInterface
    public void cancel() {
        if (vibrator != null) vibrator.cancel();
    }
}
