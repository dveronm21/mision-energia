package ar.com.inkfusion.misionenergia.remote;

import java.util.HashMap;
import java.util.Map;

/**
 * JSON mínimo, sin dependencias: escape de strings y lectura de objetos planos
 * (valores string, número, booleano o null; los anidados se saltean).
 * Alcanza para DiscoveryReply; el resto de los mensajes los interpreta el JS.
 */
public final class Json {
    private Json() { }

    /** Devuelve el string entre comillas, escapado para JSON y seguro para incrustar en JS. */
    public static String quote(String s) {
        if (s == null) return "null";
        StringBuilder b = new StringBuilder(s.length() + 16);
        b.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': b.append("\\\""); break;
                case '\\': b.append("\\\\"); break;
                case '\n': b.append("\\n"); break;
                case '\r': b.append("\\r"); break;
                case '\t': b.append("\\t"); break;
                case '<': b.append("\\u003c"); break; // evita "</script>" si se incrusta en HTML
                case ' ': b.append("\\u2028"); break;
                case ' ': b.append("\\u2029"); break;
                default:
                    if (c < 0x20) {
                        b.append(String.format("\\u%04x", (int) c));
                    } else {
                        b.append(c);
                    }
            }
        }
        b.append('"');
        return b.toString();
    }

    /** Parsea un objeto JSON plano. Lanza IllegalArgumentException si no es un objeto válido. */
    public static Map<String, Object> parseObject(String text) {
        Parser p = new Parser(text);
        p.ws();
        Object o = p.value(0);
        p.ws();
        if (p.i != text.length()) throw new IllegalArgumentException("basura al final");
        if (!(o instanceof Map)) throw new IllegalArgumentException("no es un objeto");
        @SuppressWarnings("unchecked")
        Map<String, Object> m = (Map<String, Object>) o;
        return m;
    }

    /** Parsea un array de objetos planos (ej. la salida de EventQueue.poll()). */
    public static java.util.List<Map<String, Object>> parseObjectArray(String text) {
        Parser p = new Parser(text);
        p.ws();
        java.util.List<Object> items = new java.util.ArrayList<Object>();
        p.array(0, items);
        p.ws();
        if (p.i != text.length()) throw new IllegalArgumentException("basura al final");
        java.util.List<Map<String, Object>> out = new java.util.ArrayList<Map<String, Object>>();
        for (Object o : items) {
            if (!(o instanceof Map)) throw new IllegalArgumentException("elemento no es objeto");
            @SuppressWarnings("unchecked")
            Map<String, Object> m = (Map<String, Object>) o;
            out.add(m);
        }
        return out;
    }

    public static String str(Map<String, Object> m, String k, String def) {
        Object v = m.get(k);
        return v instanceof String ? (String) v : def;
    }

    public static int num(Map<String, Object> m, String k, int def) {
        Object v = m.get(k);
        return v instanceof Double ? (int) Math.round((Double) v) : def;
    }

    private static final class Parser {
        final String s;
        int i;
        Parser(String s) { this.s = s; }

        void ws() {
            while (i < s.length()) {
                char c = s.charAt(i);
                if (c == ' ' || c == '\n' || c == '\r' || c == '\t') i++; else break;
            }
        }

        char peek() {
            if (i >= s.length()) throw new IllegalArgumentException("fin inesperado");
            return s.charAt(i);
        }

        void expect(char c) {
            if (peek() != c) throw new IllegalArgumentException("se esperaba " + c + " en " + i);
            i++;
        }

        Object value(int depth) {
            if (depth > 16) throw new IllegalArgumentException("demasiado anidado");
            ws();
            char c = peek();
            if (c == '{') return object(depth);
            if (c == '[') { array(depth, null); return null; }
            if (c == '"') return string();
            if (s.startsWith("true", i)) { i += 4; return Boolean.TRUE; }
            if (s.startsWith("false", i)) { i += 5; return Boolean.FALSE; }
            if (s.startsWith("null", i)) { i += 4; return null; }
            return number();
        }

        Map<String, Object> object(int depth) {
            Map<String, Object> m = new HashMap<String, Object>();
            expect('{');
            ws();
            if (peek() == '}') { i++; return m; }
            while (true) {
                ws();
                String k = string();
                ws();
                expect(':');
                Object v = value(depth + 1);
                if (!(v instanceof Map)) m.put(k, v); // objeto plano: los anidados se descartan
                ws();
                char c = peek();
                i++;
                if (c == '}') return m;
                if (c != ',') throw new IllegalArgumentException("se esperaba , o }");
            }
        }

        void array(int depth, java.util.List<Object> sink) {
            expect('[');
            ws();
            if (peek() == ']') { i++; return; }
            while (true) {
                Object v = value(depth + 1);
                if (sink != null) sink.add(v);
                ws();
                char c = peek();
                i++;
                if (c == ']') return;
                if (c != ',') throw new IllegalArgumentException("se esperaba , o ]");
            }
        }

        String string() {
            expect('"');
            StringBuilder b = new StringBuilder();
            while (true) {
                char c = peek();
                i++;
                if (c == '"') return b.toString();
                if (c == '\\') {
                    char e = peek();
                    i++;
                    switch (e) {
                        case '"': b.append('"'); break;
                        case '\\': b.append('\\'); break;
                        case '/': b.append('/'); break;
                        case 'b': b.append('\b'); break;
                        case 'f': b.append('\f'); break;
                        case 'n': b.append('\n'); break;
                        case 'r': b.append('\r'); break;
                        case 't': b.append('\t'); break;
                        case 'u':
                            if (i + 4 > s.length()) throw new IllegalArgumentException("\\u corto");
                            b.append((char) Integer.parseInt(s.substring(i, i + 4), 16));
                            i += 4;
                            break;
                        default: throw new IllegalArgumentException("escape inválido");
                    }
                } else if (c < 0x20) {
                    throw new IllegalArgumentException("control en string");
                } else {
                    b.append(c);
                }
            }
        }

        Double number() {
            int start = i;
            while (i < s.length() && "+-0123456789.eE".indexOf(s.charAt(i)) >= 0) i++;
            if (start == i) throw new IllegalArgumentException("valor inválido en " + i);
            try {
                return Double.valueOf(s.substring(start, i));
            } catch (NumberFormatException ex) {
                throw new IllegalArgumentException("número inválido");
            }
        }
    }
}
