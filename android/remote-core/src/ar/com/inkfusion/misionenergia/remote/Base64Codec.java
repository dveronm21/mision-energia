package ar.com.inkfusion.misionenergia.remote;

/** Base64 estándar (RFC 4648). java.util.Base64 no existe en Android antes de API 26. */
public final class Base64Codec {
    private Base64Codec() { }

    private static final char[] ALPHA =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toCharArray();

    public static String encode(byte[] data) {
        StringBuilder b = new StringBuilder((data.length + 2) / 3 * 4);
        int i = 0;
        while (i + 3 <= data.length) {
            int v = ((data[i] & 0xff) << 16) | ((data[i + 1] & 0xff) << 8) | (data[i + 2] & 0xff);
            b.append(ALPHA[(v >>> 18) & 63]).append(ALPHA[(v >>> 12) & 63])
             .append(ALPHA[(v >>> 6) & 63]).append(ALPHA[v & 63]);
            i += 3;
        }
        int rest = data.length - i;
        if (rest == 1) {
            int v = (data[i] & 0xff) << 16;
            b.append(ALPHA[(v >>> 18) & 63]).append(ALPHA[(v >>> 12) & 63]).append("==");
        } else if (rest == 2) {
            int v = ((data[i] & 0xff) << 16) | ((data[i + 1] & 0xff) << 8);
            b.append(ALPHA[(v >>> 18) & 63]).append(ALPHA[(v >>> 12) & 63])
             .append(ALPHA[(v >>> 6) & 63]).append('=');
        }
        return b.toString();
    }

    /** Decodifica; devuelve null si el texto no es Base64 válido. */
    public static byte[] decode(String s) {
        if (s == null || s.length() % 4 != 0) return null;
        int pad = 0;
        if (s.endsWith("==")) pad = 2; else if (s.endsWith("=")) pad = 1;
        int outLen = s.length() / 4 * 3 - pad;
        byte[] out = new byte[outLen];
        int o = 0;
        for (int i = 0; i < s.length(); i += 4) {
            int v = 0;
            for (int j = 0; j < 4; j++) {
                char c = s.charAt(i + j);
                int d;
                if (c == '=' && i + 4 == s.length() && j >= 4 - pad) d = 0;
                else {
                    d = indexOf(c);
                    if (d < 0) return null;
                }
                v = (v << 6) | d;
            }
            if (o < outLen) out[o++] = (byte) (v >>> 16);
            if (o < outLen) out[o++] = (byte) (v >>> 8);
            if (o < outLen) out[o++] = (byte) v;
        }
        return out;
    }

    private static int indexOf(char c) {
        if (c >= 'A' && c <= 'Z') return c - 'A';
        if (c >= 'a' && c <= 'z') return c - 'a' + 26;
        if (c >= '0' && c <= '9') return c - '0' + 52;
        if (c == '+') return 62;
        if (c == '/') return 63;
        return -1;
    }
}
