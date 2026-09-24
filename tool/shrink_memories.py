"""Turn the Memories artwork into what the app actually ships.

The originals are 1086x1448 and 1448x1086 PNG mockups, ~30 MB for sixteen,
and the APK sits about half a megabyte under Supabase's 50 MiB object cap,
past which the in-app updater cannot publish at all. So each piece is cut
out of its mockup, scaled to what it is drawn at, and written as WebP.

    python tool/shrink_memories.py                  # from ../twolip/design/memories
    python tool/shrink_memories.py <source-dir>     # from elsewhere
    python tool/shrink_memories.py --dry-run        # report only

What ships, and what is left in design/:
  * journal_<month>.webp: each month's cover, cut from its page, with the
    painted "goals · highlights" line erased. The app writes the real
    counts there, at a size a 110pt book can be read at (the painted line
    would be 3pt tall on the shelf). Prints the line's position and ink for
    JournalCovers in memories_assets.dart.
  * garden_hero.webp: the Flowers header, cut from garden_and_flowers.png.
  * timeline_journal / timeline_card / timeline_bouquet: square thumbnails
    for memories with no picture of their own.
  * NOT shipped: the sample photos, the illustrated map and the place
    photos. They are example content; Memories shows the couple's own.

! The originals stay in `design/memories/` in the main checkout. This script
  is one-way; re-running it on its own output would compound the loss.
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "memories"
DEFAULT_SOURCE = ROOT.parent / "twolip" / "design" / "memories"

# A book is drawn at most ~113pt wide (three to a row on a 390pt phone);
# 300px covers that at 2.6x, which is what most of these phones are.
COVER_WIDTH = 300
COVER_QUALITY = 70
# The garden spans the content width, ~360pt: 1000px is ~2.8x.
GARDEN_WIDTH = 1000
GARDEN_QUALITY = 72
# Timeline thumbnails are drawn at 58pt.
THUMB = 180
THUMB_QUALITY = 70

# The painted "goals · highlights" line on each cover, in the original's
# pixels: (centre y, left x, right x). July's includes the dashes either
# side, which would collide with the wider line written in its place.
LABELS = {
    "january": (1138, 410, 685),
    "february": (1067, 430, 710),
    "march": (682, 415, 690),
    "april": (748, 415, 672),
    "may": (688, 436, 695),
    "june": (762, 428, 708),
    "july": (1166, 345, 740),
    "august": (651, 420, 707),
    "september": (710, 422, 710),
    "october": (563, 415, 705),
    "november": (1107, 413, 687),
    "december": (1122, 413, 687),
}
HALF_HEIGHT = 22


def content_box(im, inset=0, threshold=48, share=0.5):
    """The box of whatever is not the page it was photographed on."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    bg = rgb.getpixel((4, 4))
    px = rgb.load()

    def differs(x, y):
        r, g, b = px[x, y]
        return abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > threshold

    cols = [x for x in range(w)
            if sum(differs(x, y) for y in range(0, h, 4)) > share * h / 4]
    rows = [y for y in range(h)
            if sum(differs(x, y) for x in range(0, w, 4)) > share * w / 4]
    return (cols[0] + inset, rows[0] + inset, cols[-1] - inset,
            rows[-1] - inset)


def painted_box(im, inset=0, chroma=18, share=0.3):
    """The box of the painted artwork, found by colour rather than by
    difference from the page: the page and the mockup's drop shadow are
    neutral (grey, cream), the painting is not. Brightness alone took the
    shadow for part of the book, and the pale garden sky for page."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()

    def painted(x, y):
        r, g, b = px[x, y]
        return max(r, g, b) - min(r, g, b) > chroma

    cols = [x for x in range(w)
            if sum(painted(x, y) for y in range(0, h, 4)) > share * h / 4]
    rows = [y for y in range(h)
            if sum(painted(x, y) for x in range(0, w, 4)) > share * w / 4]
    return (cols[0] + inset, rows[0] + inset, cols[-1] - inset,
            rows[-1] - inset)


def erase(im, box):
    """Paint over [box] by blending the rows just above and below it, then
    soften the patch into its surroundings. The labels sit on sky, water or
    snow, which is what this can repair."""
    x0, y0, x1, y1 = box
    px = im.load()
    for x in range(x0, x1):
        top = px[x, y0 - 3]
        bottom = px[x, y1 + 3]
        for y in range(y0, y1):
            t = (y - y0) / max(1, y1 - y0)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    pad = 6
    area = (x0 - pad, y0 - pad, x1 + pad, y1 + pad)
    soft = im.crop(area).filter(ImageFilter.GaussianBlur(3))
    mask = Image.new("L", soft.size, 0)
    inner = Image.new("L", (x1 - x0, y1 - y0), 255)
    mask.paste(inner, (pad, pad))
    mask = mask.filter(ImageFilter.GaussianBlur(pad / 2))
    im.paste(soft, area[:2], mask)


def ink(im, box):
    """The painted line's colour: the average of its darkest pixels."""
    pixels = list(im.crop(box).getdata())
    pixels.sort(key=lambda p: sum(p))
    darkest = pixels[: max(1, len(pixels) // 12)]
    return tuple(round(sum(p[i] for p in darkest) / len(darkest)) for i in range(3))


def save(im, path, quality, dry):
    if dry:
        return 0
    im.save(path, "WEBP", quality=quality, method=6)
    return path.stat().st_size


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    source = Path(args[0]) if args else DEFAULT_SOURCE
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    lines = []

    for month, (cy, lx, rx) in LABELS.items():
        im = Image.open(source / f"journal_{month}.png").convert("RGB")
        label = (lx - 6, cy - HALF_HEIGHT, rx + 6, cy + HALF_HEIGHT)
        colour = ink(im, label)
        erase(im, label)
        left, top, right, bottom = painted_box(im, inset=10)
        book = im.crop((left, top, right, bottom))
        y_share = (cy - top) / (bottom - top)
        height = round(COVER_WIDTH * book.size[1] / book.size[0])
        book = book.resize((COVER_WIDTH, height), Image.LANCZOS)
        size = save(book, OUT / f"journal_{month}.webp", COVER_QUALITY, dry)
        total += size
        hex_ink = "0xFF%02X%02X%02X" % colour
        lines.append(f"    '{month}': ({y_share:.3f}, Color({hex_ink})),")
        print(f"journal_{month}.webp  {book.size}  {size // 1024} KB")

    garden = Image.open(source / "garden_and_flowers.png").convert("RGB")
    # Down to the gap above the flower tiles, which start at ~510 of 1086:
    # any lower and the page between them comes along as a cream band.
    top_half = garden.crop((0, 0, garden.size[0], 490))
    box = painted_box(top_half, inset=10)
    panel = top_half.crop(box)
    panel = panel.resize(
        (GARDEN_WIDTH, round(GARDEN_WIDTH * panel.size[1] / panel.size[0])),
        Image.LANCZOS)
    size = save(panel, OUT / "garden_hero.webp", GARDEN_QUALITY, dry)
    total += size
    print(f"garden_hero.webp  {panel.size}  aspect {panel.size[0] / panel.size[1]:.3f}  {size // 1024} KB")

    sheet = Image.open(source / "timeline_thumbnails.png").convert("RGB")
    w, h = sheet.size
    # The four panels of the sheet: top-left tulips, bottom-left envelope,
    # bottom-right journal. The couple photo, top right, is sample content.
    quads = {
        "timeline_bouquet": (0, 0, w // 2, h // 2),
        "timeline_card": (0, h // 2, w // 2, h),
        "timeline_journal": (w // 2, h // 2, w, h),
    }
    for name, area in quads.items():
        quad = sheet.crop(area)
        panel = quad.crop(content_box(quad, inset=10, share=0.3))
        side = min(panel.size)
        # The journal's photo sits right of centre; keep it in the square.
        shift = 0.62 if name == "timeline_journal" else 0.5
        cx = round(panel.size[0] * shift)
        left = max(0, min(panel.size[0] - side, cx - side // 2))
        square = panel.crop((left, 0, left + side, side)).resize(
            (THUMB, THUMB), Image.LANCZOS)
        size = save(square, OUT / f"{name}.webp", THUMB_QUALITY, dry)
        total += size
        print(f"{name}.webp  {size // 1024} KB")

    print(f"\ntotal {total // 1024} KB")
    print("\n// JournalCovers.labels, from tool/shrink_memories.py")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
