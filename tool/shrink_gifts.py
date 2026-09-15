"""Re-encode the bundled gift photography to the size it is actually drawn at.

The nine files in `assets/images/gifts/` shipped as 1024x1024 JPEGs straight
from wherever they were sourced -- two of them over 1.2 MB each, 4.5 MB in
total, inside an APK with a hard 50 MiB ceiling. They render in a square grid
card about 190pt wide, so ~570px on a 3x screen. Everything above that was
paid for by every phone on every update and seen by nobody.

    python tool/shrink_gifts.py            # re-encode in place
    python tool/shrink_gifts.py --dry-run  # report what it would save

! Deleting them instead is NOT an option, and this script exists because that
  was the first idea. `GiftProduct.asset` is derived from the id and the
  bundled file is the *primary* artwork -- `image_url` is only a fallback for
  products added from the dashboard later. Checked 2026-09-15: all nine rows
  in `gift_products` have image_url NULL, so the bundle is the only source of
  a picture any of them has. Removing it would leave the whole gift screen on
  the placeholder icon, and take its offline behaviour with it.

! Same filenames, same .jpg extension, deliberately. `asset` builds the path
  from the id, so changing the extension means touching Dart and a test for
  no gain the eye can see.
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GIFTS = ROOT / "assets" / "images" / "gifts"

# 640 rather than 512: the card is ~190pt and a 3x screen wants ~570px, so
# 512 is visibly soft on the exact devices this app is for and 640 is the
# first round number that clears it.
EDGE = 640
QUALITY = 82


def verify(path):
    """A write is not done until it reads back -- see slice_stems.py.

    🔴 That script once reported "Wrote 54 stems" and left 25 of them zero
    bytes, and nothing failed loudly because Image.asset falls back to an
    icon. This one overwrites its own source, so a silent failure here is
    not recoverable from the filesystem -- only from git.
    """
    try:
        if path.stat().st_size == 0:
            raise OSError("zero bytes")
        with Image.open(path) as check:
            check.load()
            if not check.getbbox():
                raise OSError("decoded blank")
    except Exception as error:
        sys.exit(f"{path.name} did not survive the write: {error}\n"
                 f"  Restore with: git checkout -- {GIFTS.relative_to(ROOT)}")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    dry_run = "--dry-run" in sys.argv
    if not GIFTS.is_dir():
        sys.exit(f"Missing {GIFTS}")

    before = after = 0
    for path in sorted(GIFTS.glob("*.jpg")):
        was = path.stat().st_size
        before += was

        with Image.open(path) as image:
            art = image.convert("RGB")
            # Only ever downward. A small source stays its own size rather
            # than being blown up into a bigger, blurrier file.
            if max(art.size) > EDGE:
                art.thumbnail((EDGE, EDGE), Image.LANCZOS)
            if not dry_run:
                art.save(path, "JPEG", quality=QUALITY, optimize=True,
                         progressive=True)

        if not dry_run:
            verify(path)
        now = path.stat().st_size
        after += now
        print(f"  {path.name:28s} {was/1024:7.0f} KB → {now/1024:6.0f} KB")

    verb = "would free" if dry_run else "freed"
    print(f"\n{before/1024/1024:.2f} MB → {after/1024/1024:.2f} MB "
          f"({verb} {(before-after)/1024/1024:.2f} MB)")


if __name__ == "__main__":
    main()
