"""Builds the heartbeat widget's scenes from the supplied card designs.

    python tool/make_heartbeat_art.py

Reads assets/heartbeat/src/<theme>.png, one whole widget design per theme (a
card with "HEARTBEAT" at the top, an illustration, and a "Tap to send"
button, on a cream page), and writes:

  android/app/src/main/res/drawable-nodpi/hb_art_<theme>.webp  (the widget)
  assets/images/heartbeat/<theme>.webp                          (Settings)

The widget draws the title and the button itself, so they stay crisp and in
place at any size. Here they are painted out, along with the card's rounded
corners, and each illustration is laid into a 4:5 canvas:

- 🔴 **Its big heart at the exact centre.** The widget shows the scene
  centre-cropped and draws its ripple from its own middle, so a centred heart
  is the one place that stays under the ripple at every widget shape.
- **Every heart the same size** (HEART of the canvas's width), so no theme
  looks zoomed in beside another, and the ripple starts at the heart's edge
  on all of them.

Everything is found in the image rather than measured by hand, so a new or
redrawn design is one more file in src/ and a run of this. Requires Pillow,
numpy and opencv-python-headless. Not part of the Flutter build: the outputs
are committed.
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'heartbeat', 'src')
WIDGET_OUT = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'drawable-nodpi')
APP_OUT = os.path.join(ROOT, 'assets', 'images', 'heartbeat')

# In the order Settings shows them. HeartbeatTheme in Dart and artFor in
# HeartbeatWidget.kt name the same five.
THEMES = ['moon', 'cat', 'tulips', 'puppy', 'capybara']

W, H = 720, 900        # 4:5, and sharp on a widget up to ~260dp wide
HEART = 0.36           # the heart's width, as a share of the canvas's
THUMB = (360, 450)


def find_card(im):
    """The dark card on the cream page."""
    dark = im.mean(axis=2) < 120
    h, w = dark.shape
    rows = np.where(dark.sum(axis=1) > w * 0.3)[0]
    cols = np.where(dark.sum(axis=0) > h * 0.3)[0]
    return cols.min(), rows.min(), cols.max(), rows.max()


def find_heart(card):
    """The big pink heart: the largest patch of saturated pink."""
    R, G, B = (card[..., i].astype(int) for i in range(3))
    pink = (R > 200) & (G < 150) & (B > 90) & (B < 200) & (R - G > 110)
    n, _, stats, _ = cv2.connectedComponentsWithStats(pink.astype(np.uint8), 4)
    k = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    x, y, w, h, _ = stats[k]
    return x, y, x + w - 1, y + h - 1


def find_title_and_button(card):
    h, w = card.shape[:2]
    R, G, B = (card[..., i].astype(int) for i in range(3))
    lum = card.mean(axis=2)

    # Title: pink letters in the top fifth, on one line.
    band = slice(0, int(h * 0.22))
    text = (lum[band] > 110) & (R[band] > 170) & (R[band] - G[band] > 40)
    text[:, : int(w * 0.18)] = False
    text[:, int(w * 0.82):] = False
    rows = np.where(text.sum(axis=1) >= 6)[0]
    runs, start = [], rows[0]
    for a, b in zip(rows, rows[1:]):
        if b != a + 1:
            runs.append((start, a))
            start = b
    runs.append((start, rows[-1]))
    y0, y1 = max(runs, key=lambda r: r[1] - r[0])
    cols = np.where(text[y0:y1 + 1].any(axis=0))[0]
    title = (cols.min(), y0, cols.max(), y1)

    # Button: the magenta pill (redder than blue, unlike the moon's purple
    # clouds) in the bottom third, its largest piece.
    top = int(h * 0.62)
    pill = (R[top:] > 95) & (R[top:] > B[top:] + 8) & (G[top:] < 90)
    n, _, stats, _ = cv2.connectedComponentsWithStats(pill.astype(np.uint8), 8)
    k = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    x, y, bw, bh, _ = stats[k]
    return title, (x, y + top, x + bw - 1, y + top + bh - 1)


def pushpull(img, valid):
    """Fills where [valid] is 0 from everything around it, smoothly.

    A pyramid: averaged down with the holes left out, then back up, each
    level filling its holes from the one below. Every edge of a hole pulls
    on it, so a patch between dark sky and a cloud comes out a blend of both
    rather than whichever side had more pixels.
    """
    levels = []
    c = img.astype(np.float32) * valid[..., None]
    w = valid.astype(np.float32)
    while min(w.shape) > 4:
        levels.append((c, w))
        h2, w2 = (w.shape[0] + 1) // 2, (w.shape[1] + 1) // 2
        c = cv2.resize(c, (w2, h2), interpolation=cv2.INTER_AREA)
        w = cv2.resize(w, (w2, h2), interpolation=cv2.INTER_AREA)
    est = c / np.maximum(w, 1e-6)[..., None]
    for c, w in reversed(levels):
        up = cv2.resize(est, (w.shape[1], w.shape[0]), interpolation=cv2.INTER_LINEAR)
        own = c / np.maximum(w, 1e-6)[..., None]
        a = np.clip(w * 4, 0, 1)[..., None]
        est = own * a + up * (1 - a)
    return est


def outside_card(card):
    """The card's rounded corners (the cream past them) and its soft rim."""
    h, w = card.shape[:2]
    lum = card.mean(axis=2)
    mask = np.zeros((h, w), np.uint8)
    r = 130
    for ys, xs in ((slice(0, r), slice(0, r)), (slice(0, r), slice(w - r, w)),
                   (slice(h - r, h), slice(0, r)), (slice(h - r, h), slice(w - r, w))):
        mask[ys, xs] = (lum[ys, xs] > 90).astype(np.uint8)
    mask[:4, :] = 1
    mask[-4:, :] = 1
    mask[:, :4] = 1
    mask[:, -4:] = 1
    return cv2.dilate(mask, np.ones((9, 9), np.uint8))


def with_glow(card, box, margin, bg, pinkish):
    """[box] and the soft glow round it: anything within [margin] that is
    brighter than the background there. For the button, only what is
    pinker than blue, so the moon's purple clouds beside it stay."""
    h, w = card.shape[:2]
    x0, y0, x1, y1 = box
    X0, Y0 = max(0, x0 - margin), max(0, y0 - margin)
    X1, Y1 = min(w, x1 + margin + 1), min(h, y1 + margin + 1)
    lit = card[Y0:Y1, X0:X1].mean(axis=2) > bg[Y0:Y1, X0:X1].mean(axis=2) + 2.5
    if pinkish:
        R = card[Y0:Y1, X0:X1, 0].astype(int)
        B = card[Y0:Y1, X0:X1, 2].astype(int)
        lit &= R >= B - 2
    mask = np.zeros((h, w), np.uint8)
    mask[Y0:Y1, X0:X1] = lit
    mask[max(0, y0 - 10):y1 + 11, max(0, x0 - 10):x1 + 11] = 1
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    return cv2.dilate(mask, np.ones((11, 11), np.uint8))


def grain_sd(card):
    """The card's grain, off a quiet stretch of background near the top."""
    f = card.astype(np.float32)
    hp = f - cv2.GaussianBlur(f, (0, 0), 2)
    quiet = hp[40:120, card.shape[1] // 2 - 200:card.shape[1] // 2 + 200]
    return float(np.clip(quiet.std(), 0.5, 4.0))


def clean(card):
    """The card with its title, button and corners painted out."""
    title, button = find_title_and_button(card)
    corners = outside_card(card)
    boxes = np.zeros(card.shape[:2], np.uint8)
    for (x0, y0, x1, y1) in (title, button):
        boxes[max(0, y0 - 12):y1 + 13, max(0, x0 - 12):x1 + 13] = 1
    # The background as it would be without them: what a glow is measured
    # against.
    bg = pushpull(card, 1 - np.maximum(corners, cv2.dilate(boxes, np.ones((61, 61), np.uint8))))
    bg = cv2.GaussianBlur(bg, (0, 0), 12)
    mask = np.maximum(corners, np.maximum(
        with_glow(card, title, 50, bg, pinkish=False),
        with_glow(card, button, 70, bg, pinkish=True)))
    filled = pushpull(card, 1 - mask)
    # The grain put back, or every filled patch is the one clean, flat area
    # on a grainy card.
    rng = np.random.default_rng(7)
    filled = filled + rng.normal(0, grain_sd(card), filled.shape).astype(np.float32)
    soft = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 3)[..., None]
    out = card.astype(np.float32) * (1 - soft) + filled * soft
    return np.clip(out, 0, 255).astype(np.uint8)


def scene(path):
    im = np.asarray(Image.open(path).convert('RGB'))
    l, t, r, b = find_card(im)
    raw = im[t:b + 1, l:r + 1]
    hx0, hy0, hx1, hy1 = find_heart(raw)
    card = clean(raw)
    h, w = card.shape[:2]

    s = HEART * W / (hx1 - hx0 + 1)
    scaled = cv2.resize(card, (round(w * s), round(h * s)),
                        interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)
    cx, cy = (hx0 + hx1 + 1) / 2 * s, (hy0 + hy1 + 1) / 2 * s
    ox, oy = round(W / 2 - cx), round(H / 2 - cy)
    sh, sw = scaled.shape[:2]

    # Past the card's edges: its edge colours carried outward.
    canvas = np.zeros((H, W, 3), np.float32)
    have = np.zeros((H, W), np.float32)
    y0, y1 = max(0, oy), min(H, oy + sh)
    x0, x1 = max(0, ox), min(W, ox + sw)
    canvas[y0:y1, x0:x1] = scaled[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    have[y0:y1, x0:x1] = 1
    # Smoothed without the black beyond the card leaking into its edge,
    # which drew a dark frame round it.
    num = cv2.GaussianBlur(canvas * have[..., None], (0, 0), 4)
    den = cv2.GaussianBlur(have, (0, 0), 4)[..., None]
    edge = num / np.maximum(den, 1e-6)
    around = pushpull(edge, (have > 0.5).astype(np.float32) * (den[..., 0] > 0.98))
    rng = np.random.default_rng(11)
    around = around + rng.normal(0, grain_sd(card) * 0.8, around.shape).astype(np.float32)
    # Blend over 24px at the card's own edges, not where it runs off.
    fade = np.clip(cv2.distanceTransform(have.astype(np.uint8), cv2.DIST_L2, 5) / 24.0, 0, 1)
    if oy <= 0:
        fade[:24] = np.maximum(fade[:24], have[:24])
    if oy + sh >= H:
        fade[-24:] = np.maximum(fade[-24:], have[-24:])
    if ox <= 0:
        fade[:, :24] = np.maximum(fade[:, :24], have[:, :24])
    if ox + sw >= W:
        fade[:, -24:] = np.maximum(fade[:, -24:], have[:, -24:])
    out = canvas * fade[..., None] + around * (1 - fade[..., None])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)), s


if __name__ == '__main__':
    os.makedirs(WIDGET_OUT, exist_ok=True)
    os.makedirs(APP_OUT, exist_ok=True)
    for theme in THEMES:
        img, s = scene(os.path.join(SRC, theme + '.png'))
        widget = os.path.join(WIDGET_OUT, f'hb_art_{theme}.webp')
        thumb = os.path.join(APP_OUT, f'{theme}.webp')
        # q90: at 85 the grain smooths out of the dark sky.
        img.save(widget, 'WEBP', quality=90, method=6)
        img.resize(THUMB, Image.LANCZOS).save(thumb, 'WEBP', quality=82, method=6)
        print(f'{theme}: scale {s:.3f}, {os.path.getsize(widget) // 1024} KB widget, '
              f'{os.path.getsize(thumb) // 1024} KB thumbnail')
