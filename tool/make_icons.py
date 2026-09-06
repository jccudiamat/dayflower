"""Builds the launcher-icon layers from the brand artwork.

    python tool/make_icons.py && dart run flutter_launcher_icons

Reads assets/icon/src/ and writes the derived layers beside it. The supplied
artwork is brand art, not icon assets — the cutout fills 91% of its canvas,
which an adaptive-icon mask would shave the edges off. Nothing here redraws
anything; it is all geometry.

Requires Pillow (`pip install pillow`). Not part of the Flutter build: these
outputs are committed, so this only runs when the artwork changes.
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'icon', 'src')
OUT = os.path.join(ROOT, 'assets', 'icon')
IMAGES = os.path.join(ROOT, 'assets', 'images')

CANVAS = 1024

# How much of the adaptive canvas the mark occupies.
#
# Derived from the artwork rather than picked. appicon.png composes the mark
# at 71% of its square with even margins, and on an adaptive icon the square
# a person actually sees is the inner 72dp of the 108dp canvas — the outer
# 18dp on each side exists for masking and parallax and is never all visible.
# So the mark is 71% of that 72dp, which is 47% of the canvas.
#
# ⚠️ Sizing against the full 108dp instead puts the mark at 96% of the
# visible window, touching the mask edge on every launcher. The canvas is not
# the icon.
MARK_FRACTION = 0.71 * (72 / 108)

appicon = Image.open(os.path.join(SRC, 'appicon.png')).convert('RGB')
cutout = Image.open(os.path.join(SRC, 'cutout.png')).convert('RGBA')

# ── The in-app logo, on the welcome screen. ─────────────────────────
# Small on purpose: it draws at 96dp and this one *is* bundled in the APK.
appicon.resize((512, 512), Image.LANCZOS).save(
    os.path.join(IMAGES, 'logo.png'), optimize=True)

# ── Adaptive foreground: the mark, centred, with its margin. ────────
# Bounds on alpha > 32 rather than > 0: the antialiased fringe reaches a few
# pixels further out and would bias the centring.
solid = cutout.getchannel('A').point(lambda v: 255 if v > 32 else 0)
box = solid.getbbox()
mark = cutout.crop(box)
scale = (CANVAS * MARK_FRACTION) / max(mark.size)
mark = mark.resize(
    (max(1, int(mark.width * scale)), max(1, int(mark.height * scale))),
    Image.LANCZOS,
)
at = ((CANVAS - mark.width) // 2, (CANVAS - mark.height) // 2)

fg = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
fg.paste(mark, at, mark)
fg.save(os.path.join(OUT, 'foreground.png'))

# ── Adaptive background: the artwork's own peach gradient. ──────────
# Sampled rather than chosen, so the adaptive icon and the legacy one are the
# same picture. x=5 is clear of the mark, whose bounds start at x=183.
w, h = appicon.size
bg = Image.new('RGB', (CANVAS, CANVAS))
px = bg.load()
for y in range(CANVAS):
    c = appicon.getpixel((5, min(h - 1, y * h // CANVAS)))
    for x in range(CANVAS):
        px[x, y] = c
bg.save(os.path.join(OUT, 'background.png'))

# ── Monochrome, for Android 13+ themed icons. ───────────────────────
# The system tints this and reads only its alpha, so it is the silhouette and
# nothing else. Same geometry as the foreground, or the themed icon would sit
# at a different size from the normal one.
mono = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
white = Image.new('RGBA', mark.size, (255, 255, 255, 255))
white.putalpha(mark.getchannel('A'))
mono.paste(white, at, white)
mono.save(os.path.join(OUT, 'monochrome.png'))

print('mark %s in source -> %s on %d (%.0f%% of canvas)'
      % (box, mark.size, CANVAS, 100 * max(mark.size) / CANVAS))
for f in sorted(os.listdir(OUT)):
    p = os.path.join(OUT, f)
    if os.path.isfile(p):
        print('  %-18s %8d bytes  %s' % (f, os.path.getsize(p), Image.open(p).size))
