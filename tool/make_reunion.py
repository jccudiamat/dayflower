"""Cuts the reunion illustration out of the supplied reference card.

The artwork sits on the card's own pink gradient with no hard edge, so a
plain crop would show a seam wherever the card's gradient did not match the
one baked into the JPEG. The left edge gets an alpha ramp instead: the
illustration fades into whatever is behind it, at any card width.
"""
from PIL import Image
import os
from pathlib import Path

SRC = r'C:\Users\jccud\.claude\uploads\ce9fdc26-434d-4f06-b877-0f0350378016\733a755c-image.jpg'
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'images' / 'reunion.png'

im = Image.open(SRC).convert('RGBA')

# ⚠️ Below the date line and inside the rounded corners. A crop taken from
# the card's top edge brings "Tokyo · May 12, 2025" and a corner arc with it
# — the app draws both of those itself, so baking them into the artwork would
# show the reference's own text under the real one.
card = im.crop((232, 95, 505, 303))
w, h = card.size

px = card.load()
# Fade the left 40% to nothing, and take the top and bottom few rows down as
# well so the artwork does not butt against the card's padding.
ramp = int(w * 0.40)
for y in range(h):
    edge = 1.0
    if y < 8:
        edge = y / 8
    elif y > h - 10:
        edge = max(0.0, (h - y) / 10)
    for x in range(w):
        a = 1.0 if x >= ramp else (x / ramp) ** 1.6
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, int(255 * a * edge))

card = card.resize((w * 2, h * 2), Image.LANCZOS)
card.save(OUT, optimize=True)
print(OUT, card.size, os.path.getsize(OUT), 'bytes')
