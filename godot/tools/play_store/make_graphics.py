"""Arma los recursos gráficos de la ficha de Google Play en docs/play-store/ a partir de las
capturas reales del juego (tools/out/play_*.png y tab_*.png, que genera shot_app.gd):

  godot --path godot --rendering-driver opengl3 -s res://tools/shot_app.gd -- --size=1920x1080 --ui=1.7 --prefix=play
  godot --path godot --rendering-driver opengl3 --resolution 1344x1008 -s res://tools/shot_app.gd -- --size=1344x1008 --ui=1.333 --prefix=tab
  python godot/tools/play_store/make_graphics.py

Salida: icono-512.png, grafico-destacado.png (1024×500) y capturas/telefono-N.png, tablet-N.png
(las de tablet se capturan en 1344×1008, porque la ventana no puede ser más alta que el monitor,
y se agrandan a 2048×1536).
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT_SHOTS = os.path.join(GODOT, "tools", "out")
DOCS = os.path.join(os.path.dirname(GODOT), "docs", "play-store")
FONT = os.path.join(GODOT, "assets", "fonts", "fredoka-latin-700-normal.woff2")
BODY = os.path.join(GODOT, "assets", "fonts", "nunito-latin-800-normal.woff2")
ICON = os.path.join(GODOT, "assets", "textures", "icon.png")

# Capturas para la ficha, en el orden en que se muestran.
SHOTS = ["02_menu", "07_planta_activa", "04_taller", "07b_paneles_hud", "03_mapa", "08_resultado", "10_vestuario", "11_ajustes"]

SUN = (255, 184, 46)
WHITE = (255, 255, 255)
INK = (14, 36, 32)


def feature_graphic() -> None:
    bg = Image.open(os.path.join(OUT_SHOTS, "play_07z_limpia.png")).convert("RGB")
    # Recorte 1024×500 centrado en la sala y el campo solar.
    w, h = bg.size
    scale = 1024 / w * 1.25
    bg = bg.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    left = (bg.width - 1024) // 2 + 80
    top = (bg.height - 500) // 2 - 40
    bg = bg.crop((left, top, left + 1024, top + 500))

    # Degradé oscuro a la izquierda para el título.
    shade = Image.new("L", (1024, 500))
    sd = ImageDraw.Draw(shade)
    for x in range(1024):
        sd.line([(x, 0), (x, 500)], fill=int(max(0, 230 - x * 0.42)))
    dark = Image.new("RGB", (1024, 500), INK)
    img = Image.composite(dark, bg, shade)

    icon = Image.open(ICON).convert("RGBA").resize((150, 150), Image.LANCZOS)
    img.paste(icon, (52, 92), icon)
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(FONT, 66)
    sub = ImageFont.truetype(BODY, 26)
    d.text((52, 262), "MISIÓN", font=title, fill=WHITE)
    d.text((52, 326), "ENERGÍA", font=title, fill=SUN)
    d.text((54, 412), "Armá tu planta solar en San Juan", font=sub, fill=WHITE)
    img.save(os.path.join(DOCS, "grafico-destacado.png"))


def screenshots(prefix: str, name: str, size: tuple = None) -> int:
    out = os.path.join(DOCS, "capturas")
    os.makedirs(out, exist_ok=True)
    n = 0
    for shot in SHOTS:
        src = os.path.join(OUT_SHOTS, "%s_%s.png" % (prefix, shot))
        if not os.path.exists(src):
            continue
        n += 1
        im = Image.open(src).convert("RGB")
        if size is not None:
            im = im.resize(size, Image.LANCZOS)
        im.save(os.path.join(out, "%s-%d.png" % (name, n)))
    return n


def main() -> None:
    os.makedirs(DOCS, exist_ok=True)
    Image.open(ICON).convert("RGBA").resize((512, 512), Image.LANCZOS).save(os.path.join(DOCS, "icono-512.png"))
    feature_graphic()
    print("teléfono:", screenshots("play", "telefono"), "· tablet:", screenshots("tab", "tablet", (2048, 1536)))


if __name__ == "__main__":
    main()
