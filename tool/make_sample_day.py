"""assets/images/sample_day.webp: the made-up day on Home's My Day widget
preview, and in the widget's own preview image (widget_preview_my_day).

Together's couple at sunset is a cut-out, about 40% transparent, which
reads as a sticker rather than a day someone shared. Its sky is filled from
the sky only (their hair borders it, and pulled into the fill it turns the
sunset muddy brown), by push-pull: each level of a pyramid fills its holes
from the coarser one. Then a 4:5 crop with both of them in it.

    python tool/make_sample_day.py
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/images/together/couple_sunset.webp')
OUT = os.path.join(ROOT, 'assets/images/sample_day.webp')


def push_pull(rgb, a):
    if min(a.shape[:2]) <= 2:
        mean = (rgb * a).sum((0, 1)) / max(a.sum(), 1e-6)
        return np.broadcast_to(mean, rgb.shape).copy()
    h, w = a.shape[:2]
    size = ((w + 1) // 2, (h + 1) // 2)
    small_rgb = cv2.resize(rgb * a, size, interpolation=cv2.INTER_AREA)
    small_a = cv2.resize(a[:, :, 0], size, interpolation=cv2.INTER_AREA)[:, :, None]
    small = np.where(small_a > 1e-4, small_rgb / np.maximum(small_a, 1e-4), 0)
    coarse = push_pull(small, np.minimum(small_a * 4, 1))
    up = cv2.resize(coarse, (w, h), interpolation=cv2.INTER_LINEAR)
    return rgb * a + up * (1 - a)


def main():
    im = np.asarray(Image.open(SRC).convert('RGBA')).astype(np.float32) / 255
    rgb, a = im[:, :, :3], im[:, :, 3:4]
    h0 = rgb.shape[0]
    lum = rgb.mean(2, keepdims=True)
    upper = np.arange(h0)[:, None, None] < h0 * 0.6
    source = a * np.where(upper & (lum < 0.55), 0.0, 1.0)
    fill = cv2.GaussianBlur(push_pull(rgb, source), (0, 0), 10)
    hole = cv2.GaussianBlur(1 - a[:, :, 0], (0, 0), 2)[:, :, None]
    out = np.clip((rgb * (1 - hole) + fill * hole) * 255, 0, 255).astype(np.uint8)

    h, w = out.shape[:2]
    cw = int(h * 4 / 5)
    x0 = max(0, min(w - cw, int(w * 0.53) - cw // 2))
    crop = Image.fromarray(out[:h - 2, x0:x0 + cw])
    crop.resize((432, 540), Image.LANCZOS).save(OUT, quality=80, method=6)
    print(OUT, os.path.getsize(OUT))


if __name__ == '__main__':
    main()
