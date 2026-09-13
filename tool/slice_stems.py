"""Slice the website's stem artwork into individual app assets.

The bouquet builder draws single flowers by cropping four sprite sheets on the
fly. The app cannot: it renders one flower at a time, all over the place, and
loading a 1254x1254 sheet to show one 313px bloom would decode ~6 MB for each.
So the cells are cut once, here, into `assets/images/flowers/stem_<slug>.webp`.

Run from the repo root after changing the sheets or the catalogue:

    python tool/slice_stems.py
    python tool/slice_stems.py --no-images   # regenerate the Dart only

It prints the Dart catalogue entries to paste into `flower_catalog.dart`.
Re-encoding 54 webps takes minutes, so pass --no-images when the artwork is
already cut and only the catalogue text is wanted.

! The names and their order are read out of the website's `model.ts` rather
  than copied. Gift links store a flower's *index*, so that list can never be
  reordered, and a second hand-maintained copy of it would be a second thing
  to get wrong. If the parse fails, that is the script telling you the shape
  of the source changed -- fix it here, do not transcribe the list.
"""

import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "website" / "app" / "bouquet" / "model.ts"
SHEETS = ROOT / "website" / "public" / "bouquet"
OUT = ROOT / "assets" / "images" / "flowers"

# Mirrors `flowerSprite()` in model.ts: the first six live on the two-row
# botanical sheet, the rest on four three-row sheets, twelve to a sheet.
MAIN, MAIN_ROWS = "botanical-sprites.webp", 2
EXTRA, EXTRA_ROWS = ["flowers-a.webp", "flowers-b.webp", "flowers-c.webp", "flowers-d.webp"], 3
COLS = 4

ENTRY = re.compile(r'\{\s*name:\s*"([^"]+)",\s*detail:\s*"([^"]+)",\s*color:\s*"(#[0-9a-fA-F]{6})"\s*\}')


def catalogue():
    source = MODEL.read_text(encoding="utf-8")
    start = source.index("export const flowers = [")
    end = source.index("] as const;", start)
    found = ENTRY.findall(source[start:end])
    if len(found) < 6:
        sys.exit(f"Only parsed {len(found)} flowers from model.ts -- the source shape changed.")
    return found


def slug(name):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", name.lower().replace("’", ""))).strip("_")


def cell(index):
    """Which sheet, and which cell on it. Arithmetic copied from flowerSprite()."""
    if index < 6:
        return MAIN, index, MAIN_ROWS
    return EXTRA[(index - 6) // 12], (index - 6) % 12, EXTRA_ROWS


def crop(sheet, index, rows):
    """Integer bounds that tile the sheet exactly.

    ! Rounded, not floored. The three-row sheets are 1254 wide, so a column is
      313.5px: flooring every edge loses a column of pixels down the middle of
      the sheet and shaves a sliver off three of the four flowers in a row.
    """
    w, h = sheet.size
    col, row = index % COLS, index // COLS
    left, right = round(col * w / COLS), round((col + 1) * w / COLS)
    top, bottom = round(row * h / rows), round((row + 1) * h / rows)
    return sheet.crop((left, top, right, bottom))


def verify(path, name):
    """Read back what was just written, and refuse to carry on if it is not there.

    🔴 The first run of this script reported "Wrote 54 stems" and left 25 of
    them zero bytes. Nothing failed loudly: `Image.asset` falls back to an
    emoji, so the app would simply have shipped 25 flowers that quietly are
    not flowers. A write is not done until it reads back.
    """
    try:
        if path.stat().st_size == 0:
            raise OSError("zero bytes")
        with Image.open(path) as check:
            check.load()
            if not check.getbbox():
                raise OSError("decoded blank")
    except Exception as error:
        sys.exit(f"{path.name} ({name}) did not survive the write: {error}")


def main():
    # ! Windows consoles default to cp1252 and die on the emoji below --
    #   after every image has already been written. Say what we mean.
    sys.stdout.reconfigure(encoding="utf-8")
    images = "--no-images" not in sys.argv
    if not MODEL.exists():
        sys.exit(f"Missing {MODEL}")
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {}
    lines, written, empty = [], 0, []

    for index, (name, detail, color) in enumerate(catalogue()):
        filename, cell_index, rows = cell(index)
        path = SHEETS / filename
        if not path.exists():
            sys.exit(f"Missing sheet {path}")
        if filename not in sheets:
            sheets[filename] = Image.open(path).convert("RGBA")
        art = crop(sheets[filename], cell_index, rows)

        # An empty cell means the arithmetic above disagrees with the sheet --
        # silently shipping a transparent square would show up as a flower
        # that is simply not there, which is the hardest kind to notice.
        if not art.getbbox():
            empty.append(f"{name} (index {index}, {filename} cell {cell_index})")
            continue

        if images:
            out = OUT / f"stem_{slug(name)}.webp"
            art.save(out, "WEBP", quality=88, method=6, exact=True)
            verify(out, name)
            written += 1
        lines.append(
            "    Flower(\n"
            f"      id: 'stem_{slug(name)}',\n"
            "      emoji: '\U0001f338',\n"
            f"      name: '{name.replace(chr(0x2019), chr(39)).replace(chr(39), chr(92) + chr(39))}',\n"
            f"      color: Color(0xFF{color[1:].upper()}),\n"
            f"      meaning: '{detail.replace(chr(0x2019), chr(39)).replace(chr(39), chr(92) + chr(39))}',\n"
            "      category: FlowerCategory.stem,\n"
            "      cutout: true,\n"
            "    ),"
        )

    if empty:
        print("Empty cells, not written:", *empty, sep="\n  ", file=sys.stderr)
    print(f"Wrote {written} stems to {OUT.relative_to(ROOT)}" if images
          else f"Catalogue only; {len(lines)} entries", file=sys.stderr)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
