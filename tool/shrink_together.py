"""Turn the Together illustrations into what the app actually ships.

The originals are 1254px (and one 1672px) transparent PNGs, 8 MB for nine of
them -- inside an APK that sits under 1 MB from Supabase's 50 MiB object cap,
past which the in-app updater cannot publish at all. They are drawn at 36pt
to about 270pt. So each is trimmed to its artwork, scaled to 3x the largest
size it is ever drawn at, and written as lossy WebP with its alpha kept.

    python tool/shrink_together.py                  # from ../twolip/design/together
    python tool/shrink_together.py <source-dir>     # from elsewhere
    python tool/shrink_together.py --dry-run        # report only

! The originals stay in `design/together/` in the main checkout, which git
  ignores for the flower sources but not for these -- keep them there. This
  script is one-way; re-running it on its own output would compound the loss.

! Specks. The cut-outs carry stray near-transparent pixels far from the art
  (visible as dots on a dark background). Left in, they stretch the trim box
  to the whole canvas and every icon renders small inside empty margin.
  Alpha below SPECK is cleared before trimming.
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "together"
DEFAULT_SOURCE = ROOT.parent / "twolip" / "design" / "together"

SPECK = 10
QUALITY = 84

# source name -> (output name, longest edge in px). The edge is 3x the
# largest size the art is drawn at, from the widget that draws it.
PLAN = {
    # Hero: fills the card's height, ~270pt on a narrow phone.
    "couple_sunset": ("couple_sunset", 1400),
    # Row and goal icons: drawn at 36-48pt.
    "airplane": ("airplane", 192),
    "island": ("island", 192),
    "piggy_bank": ("piggy_bank", 192),
    # Card art: 90-120pt.
    "calendar_hearts": ("calendar_hearts", 360),
    "gift_for_you": ("gift_for_you", 360),
    "game_controller": ("game_controller", 320),
    "headphones": ("headphones", 320),
    "popcorn_tv": ("popcorn_tv", 320),
}


# 🔴 The calendar's month is printed on the art as "OCT", which would be
# wrong eleven months of the year. The band it sits on is erased here and
# the app draws the real month in its place. Coordinates are in the 1254px
# original: the word sits between the two hearts (449-492 and 730-788).
CALENDAR_WORD = (536, 322, 712, 397)   # left, top, right, bottom


def erase_calendar_month(image):
    """Fill each row across the word by blending the band either side of it.

    Row by row, not one flat patch: the band is shaded top to bottom, and a
    single colour would show as a lighter rectangle where the word was.
    """
    image = image.convert("RGBA")
    px = image.load()
    left, top, right, bottom = CALENDAR_WORD

    def sample(x, y):
        # A few pixels averaged, so one noisy pixel cannot tint a whole row.
        cols = [px[x + dx, y] for dx in (-2, -1, 0, 1, 2)]
        return tuple(sum(c[i] for c in cols) / len(cols) for i in range(4))

    for y in range(top, bottom):
        a = sample(left - 4, y)
        b = sample(right + 4, y)
        span = right - left
        for x in range(left, right):
            t = (x - left) / span
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))
    return image


def label_box(original_size, trim_box):
    """Where the word was, as fractions of the shipped (trimmed) image."""
    left, top, right, bottom = CALENDAR_WORD
    tl, tt, tr, tb = trim_box
    w, h = tr - tl, tb - tt
    return (
        ((left + right) / 2 - tl) / w,   # centre x
        ((top + bottom) / 2 - tt) / h,   # centre y
        (right - left) / w,              # width
        (bottom - top) / h,              # height
    )


def clean(image):
    """Clear the specks, then trim to what is left, with a little air.

    Returns the trimmed image and the box it was cut from.
    """
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 0 if a < SPECK else a)
    image.putalpha(alpha)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("an illustration with no visible pixels")
    left, top, right, bottom = box
    pad = round(max(right - left, bottom - top) * 0.02)
    box = (
        max(0, left - pad),
        max(0, top - pad),
        min(image.width, right + pad),
        min(image.height, bottom + pad),
    )
    return image.crop(box), box


def main(argv):
    dry = "--dry-run" in argv
    args = [a for a in argv if not a.startswith("--")]
    source = Path(args[0]) if args else DEFAULT_SOURCE
    if not source.is_dir():
        raise SystemExit(f"no such folder: {source}")
    OUT.mkdir(parents=True, exist_ok=True)

    total_in = total_out = 0
    for name, (out_name, edge) in PLAN.items():
        src = source / f"{name}.png"
        if not src.exists():
            print(f"  skip {name}.png (not in {source})")
            continue
        original = Image.open(src)
        if name == "calendar_hearts":
            original = erase_calendar_month(original)
        image, trim = clean(original)
        if name == "calendar_hearts":
            cx, cy, lw, lh = label_box(original.size, trim)
            print(f"  calendar month label: centre ({cx:.4f}, {cy:.4f}) "
                  f"size ({lw:.4f} x {lh:.4f}) -- keep TogetherCalendar in step")
        scale = min(1.0, edge / max(image.size))
        size = (round(image.width * scale), round(image.height * scale))
        image = image.resize(size, Image.LANCZOS)

        dst = OUT / f"{out_name}.webp"
        total_in += src.stat().st_size
        if dry:
            print(f"  {name}.png -> {dst.name} {size[0]}x{size[1]}")
            continue
        image.save(dst, "WEBP", quality=QUALITY, method=6)
        total_out += dst.stat().st_size
        print(f"  {name}.png {src.stat().st_size // 1024}KB -> "
              f"{dst.name} {size[0]}x{size[1]} {dst.stat().st_size // 1024}KB")

    if not dry:
        print(f"total {total_in // 1024}KB -> {total_out // 1024}KB")


if __name__ == "__main__":
    main(sys.argv[1:])
