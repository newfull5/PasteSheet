#!/usr/bin/env python3
"""Generate PasteSheet icon variants from the original line-art "P".

Source: ../_deprecated/src-tauri/icons/icon.png  (black P, 512px)
Output: this brand/ folder.

The "P" alpha mask is extracted from darkness (gated by the source alpha), so
it works whether the source background is opaque-white or transparent. From
that single mask we render: bare black/white P (transparent), and self-contained
app-icon tiles (light / dark / accent backgrounds).

    python3 -m venv .venv && .venv/bin/pip install Pillow
    .venv/bin/python brand/generate.py
"""
import os
from PIL import Image, ImageDraw, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "_deprecated", "src-tauri", "icons", "icon.png")
OUT = HERE
CANVAS = 512

src = Image.open(SRC).convert("RGBA").resize((CANVAS, CANVAS), Image.LANCZOS)
r, g, b, a = src.split()
dark = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 255 - v)
mask = ImageChops.multiply(dark, a)
BBOX = mask.getbbox()

def centered_p(color, scale, canvas=CANVAS):
    m = mask.crop(BBOX)
    w, h = m.size
    ratio = int(canvas * scale) / max(w, h)
    m2 = m.resize((max(1, int(w * ratio)), max(1, int(h * ratio))), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", m2.size, color),
              ((canvas - m2.size[0]) // 2, (canvas - m2.size[1]) // 2), m2)
    return out

def tile(bg, p_color, scale=0.60, canvas=CANVAS):
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle(
        [0, 0, canvas - 1, canvas - 1], radius=int(canvas * 0.225), fill=bg)
    out.alpha_composite(centered_p(p_color, scale, canvas))
    return out

BLACK, WHITE, DARKBG, ACCENT = (17, 17, 17, 255), (244, 244, 242, 255), (28, 28, 28, 255), (220, 220, 87, 255)
variants = {
    "p-black": centered_p(BLACK, 0.88),
    "p-white": centered_p(WHITE, 0.88),
    "tile-light": tile(WHITE, BLACK),
    "tile-dark": tile(DARKBG, WHITE),
    "tile-accent": tile(ACCENT, BLACK),
}
for name, im in variants.items():
    im.save(os.path.join(OUT, f"{name}.png"))
    print("saved", name)
