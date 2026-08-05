#!/usr/bin/env python3
"""Generate AI Credits macOS app icon (G/H/C triangle) → assets/AppIcon.icns."""
from __future__ import annotations

import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets")
SIZE = 1024

# Colors matching menubar chip
G_DISC = (245, 245, 245, 255)
G_INK = (20, 20, 20, 255)
H_DISC = (89, 102, 199, 255)
H_INK = (255, 255, 255, 255)
C_DISC = (235, 173, 56, 255)
C_INK = (26, 26, 26, 255)
BG_TOP = (28, 30, 38, 255)
BG_BOT = (14, 15, 20, 255)
RIM_G = (120, 120, 125, 255)
RIM_H = (55, 65, 140, 255)
RIM_C = (180, 120, 30, 255)


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for y in range(SIZE):
        t = y / (SIZE - 1)
        r = int(BG_TOP[0] * (1 - t) + BG_BOT[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOT[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOT[2] * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = SIZE // 2, int(SIZE * 0.52)
    gd.ellipse([cx - 340, cy - 300, cx + 340, cy + 300], fill=(90, 100, 160, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.alpha_composite(img, glow)

    d = 340
    overlap = 0.30
    dist = d * (1 - overlap)
    radius = d / 2
    half = dist / 2
    rise = math.sqrt(dist * dist - half * half)
    base_y = cy + rise * 0.28
    h_cx, c_cx, g_cx = cx - half, cx + half, cx
    h_cy = c_cy = base_y
    g_cy = base_y - rise

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for x, y in ((g_cx, g_cy), (h_cx, h_cy), (c_cx, c_cy)):
        sd.ellipse(
            [x - radius + 8, y - radius + 14, x + radius + 8, y + radius + 14],
            fill=(0, 0, 0, 90),
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, shadow)

    font_path = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"
    font = ImageFont.truetype(font_path, int(d * 0.48))

    def draw_disc(center, fill, rim, letter, ink):
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        x, y = center
        pad = 2
        bbox = [x - radius + pad, y - radius + pad, x + radius - pad, y + radius - pad]
        ld.ellipse(bbox, fill=fill)
        ld.ellipse(bbox, outline=rim, width=8)
        tb = ld.textbbox((0, 0), letter, font=font)
        tw, th = tb[2] - tb[0], tb[3] - tb[1]
        tx = x - tw / 2 - tb[0]
        ty = y - th / 2 - tb[1] - font.size * 0.04
        ld.text((tx, ty), letter, font=font, fill=ink)
        return layer

    img = Image.alpha_composite(img, draw_disc((h_cx, h_cy), H_DISC, RIM_H, "H", H_INK))
    img = Image.alpha_composite(img, draw_disc((c_cx, c_cy), C_DISC, RIM_C, "C", C_INK))
    img = Image.alpha_composite(img, draw_disc((g_cx, g_cy), G_DISC, RIM_G, "G", G_INK))

    rgb = Image.new("RGB", (SIZE, SIZE), (14, 15, 20))
    rgb.paste(img, mask=img.split()[3])
    master = os.path.join(OUT_DIR, "AppIcon-1024.png")
    rgb.save(master, "PNG")

    iconset = os.path.join(OUT_DIR, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "diana.k@example.org": 32,
        "icon_32x32.png": 32,
        "ivan.p@example.net": 64,
        "icon_128x128.png": 128,
        "wendy.h@example.net": 256,
        "icon_256x256.png": 256,
        "wendy.h@example.net": 512,
        "icon_512x512.png": 512,
        "walt.e@example.net": 1024,
    }
    for name, s in sizes.items():
        rgb.resize((s, s), Image.Resampling.LANCZOS).save(
            os.path.join(iconset, name), "PNG"
        )

    icns = os.path.join(OUT_DIR, "AppIcon.icns")
    subprocess.check_call(["iconutil", "-c", "icns", iconset, "-o", icns])
    print(f"✓ {master}")
    print(f"✓ {icns}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
