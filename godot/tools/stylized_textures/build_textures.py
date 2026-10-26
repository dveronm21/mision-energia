"""Texturas estilizadas del mundo (look de juego móvil: pintado a mano, colores limpios, sin ruido fino).

Fuentes (CC0, pintadas a mano en GIMP) en src/: ver CREDITOS.md.
El color lo siguen poniendo los colores por vértice de cada modelo: acá se arman "mapas de detalle"
casi blancos (promedio ~0,93) que sólo agregan las pinceladas y el volumen.

  python godot/tools/stylized_textures/build_textures.py

Salida en assets/textures/stylized/:
  sand_detail.png    médanos pintados (terreno)
  cracks_detail.png  tierra agrietada de barreal (manchas en el terreno)
  slab_tiles.png     baldosas de hormigón con bisel (platea de la sala), 2×2 baldosas
  canopy_sheet.png   chapa acanalada con brillo suave (techo de la sala)
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "textures", "stylized")


def detail_map(src: str, size: int, mean: float, contrast: float, blur: float = 0.0) -> Image.Image:
    """Luminancia de `src` re-centrada en `mean`, con el contraste de las pinceladas escalado."""
    im = Image.open(os.path.join(HERE, "src", src)).convert("RGB").resize((size, size), Image.LANCZOS)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    d = (lum - lum.mean()) * contrast + mean
    d = np.clip(d, 0.0, 1.0)
    return Image.fromarray((np.stack([d, d, d], -1) * 255).astype(np.uint8))


def tileable_noise(size: int, cells: int, seed: int) -> np.ndarray:
    """Ruido suave que repite en los bordes (bicúbico sobre una grilla aleatoria periódica)."""
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells)).astype(np.float32)
    big = np.tile(g, (3, 3))
    im = Image.fromarray((big * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
    a = np.asarray(im).astype(np.float32)[size:2 * size, size:2 * size] / 255.0
    return a


def slab_tiles(size: int = 512) -> Image.Image:
    """2×2 baldosas: centro liso con manchas suaves, bisel claro arriba-izquierda y oscuro abajo-derecha,
    junta oscura de 3 px. Todo cerca del blanco (el gris lo da el color por vértice)."""
    t = size // 2
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    lx, ly = x % t, y % t
    base = 0.93 + (tileable_noise(size, 6, 3) - 0.5) * 0.06 + (tileable_noise(size, 20, 4) - 0.5) * 0.025
    bev = 7.0
    hl = np.clip(1.0 - np.minimum(lx, ly) / bev, 0, 1)
    sh = np.clip(1.0 - np.minimum(t - 1 - lx, t - 1 - ly) / bev, 0, 1)
    v = base + hl * 0.07 - sh * 0.1
    joint = (np.minimum(lx, t - 1 - lx) < 1.5) | (np.minimum(ly, t - 1 - ly) < 1.5)
    v = np.where(joint, 0.62, v)
    v = np.clip(v, 0, 1)
    rgb = np.stack([v, v * 0.995, v * 0.985], -1)
    return Image.fromarray((rgb * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def canopy_sheet(size: int = 256, waves: int = 8) -> Image.Image:
    """Chapa acanalada: ondas suaves en x con un brillo marcado en cada cresta (estilo cartoon)."""
    x = np.arange(size, dtype=np.float32)
    ph = (x / size) * waves * 2 * np.pi
    s = np.sin(ph)
    v = 0.78 + 0.12 * s + 0.12 * np.clip((s - 0.75) / 0.25, 0, 1)
    col = np.tile(v[None, :], (size, 1))
    col = col + (tileable_noise(size, 5, 9) - 0.5) * 0.04
    col = np.clip(col, 0, 1)
    rgb = np.stack([col, col, col * 1.01], -1).clip(0, 1)
    return Image.fromarray((rgb * 255).astype(np.uint8))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    detail_map("sand_drummyfish.png", 512, 0.93, 1.25).save(os.path.join(OUT, "sand_detail.png"))
    detail_map("dirt_drummyfish.png", 512, 0.9, 1.1, 0.4).save(os.path.join(OUT, "cracks_detail.png"))
    slab_tiles().save(os.path.join(OUT, "slab_tiles.png"))
    canopy_sheet().save(os.path.join(OUT, "canopy_sheet.png"))
    print("listo:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
