"""Genera los recursos del cartel 3D de EPSE a partir del logo oficial (epse_logo_source.png):

  assets/textures/epse_logo.png        frente del cartel: el logo tal cual, 4 veces más grande,
                                       con el arco del disco relleno de blanco (en el PNG es
                                       transparente) y fondo transparente.
  assets/models/epse_logo_outline.json contornos de la silueta (disco entero + letras, con sus
                                       huecos) para extruir los cantos en Godot.

Uso (desde godot/):  python tools/epse_logo/build_logo.py
Requiere opencv-python y numpy. No cambia la tipografía ni el dibujo: todo sale del PNG.
"""
import json
import os

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(HERE, "epse_logo_source.png")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "epse_logo.png")
OUT_JSON = os.path.join(ROOT, "assets", "models", "epse_logo_outline.json")
SCALE = 4
PAD = 8  # px de margen transparente alrededor (después de escalar)


def main() -> None:
    src = cv2.imread(SRC, cv2.IMREAD_UNCHANGED)
    alpha = src[:, :, 3]
    # Color del logo: el promedio de los píxeles opacos (naranja EPSE).
    solid = alpha > 250
    orange = np.array([np.median(src[:, :, c][solid]) for c in range(3)], dtype=np.float32)

    h, w = alpha.shape
    a = cv2.resize(alpha, (w * SCALE, h * SCALE), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255.0
    a = np.pad(a, PAD)
    H, W = a.shape

    # Disco: la mancha opaca que toca el borde izquierdo; su círculo envolvente.
    n, labels, stats, _ = cv2.connectedComponentsWithStats((a > 0.5).astype(np.uint8))
    disc_label = min(range(1, n), key=lambda i: stats[i, cv2.CC_STAT_LEFT])
    ys, xs = np.nonzero(labels == disc_label)
    (cx, cy), r = cv2.minEnclosingCircle(np.column_stack([xs, ys]).astype(np.float32))
    circle = np.zeros((H, W), np.uint8)
    cv2.circle(circle, (int(round(cx * 16)), int(round(cy * 16))), int(round((r - 0.5) * 16)), 255, -1, cv2.LINE_AA, 4)
    c = circle.astype(np.float32) / 255.0

    # Frente: naranja donde el logo es opaco; blanco en el arco (dentro del disco).
    out_a = np.maximum(a, c)
    white = np.full(3, 255.0, np.float32)
    rgb = orange[None, None, :] * a[..., None] + white[None, None, :] * (1.0 - a[..., None])
    tex = np.dstack([np.clip(rgb, 0, 255), np.clip(out_a * 255.0, 0, 255)]).astype(np.uint8)
    os.makedirs(os.path.dirname(OUT_TEX), exist_ok=True)
    cv2.imwrite(OUT_TEX, tex)

    # Contornos de la silueta (con huecos: la panza de la P). Coordenadas con alto 1, y hacia
    # arriba, origen abajo a la izquierda. Externos antihorarios y huecos horarios: así la
    # normal de cada canto es siempre (dy, -dx).
    mask = (out_a > 0.5).astype(np.uint8)
    contours, hier = cv2.findContours(mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    loops = []
    for i, cnt in enumerate(contours):
        approx = cv2.approxPolyDP(cnt, 0.8, True).reshape(-1, 2).astype(np.float64)
        if len(approx) < 3:
            continue
        pts = [((x) / H, (H - y) / H) for x, y in approx]
        area = sum(pts[k][0] * pts[(k + 1) % len(pts)][1] - pts[(k + 1) % len(pts)][0] * pts[k][1] for k in range(len(pts))) / 2.0
        is_hole = hier[0][i][3] >= 0
        if (area > 0) == is_hole:
            pts.reverse()
        loops.append({"hole": bool(is_hole), "points": [round(v, 5) for p in pts for v in p]})
    data = {
        "source": "epse_logo_source.png",
        "aspect": W / H,
        "color": "#%02x%02x%02x" % (int(orange[2]), int(orange[1]), int(orange[0])),
        "loops": loops,
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    print("textura", tex.shape, "contornos", len(loops), "color", data["color"], "aspecto %.3f" % data["aspect"])


if __name__ == "__main__":
    main()
