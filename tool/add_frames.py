"""Turns frame artwork into the app's frame assets.

    python tool/add_frames.py <art.png>=<id> [<art.png>=<id> ...]

Writes assets/images/frames/<id>.webp for each. Then give each one an entry in
lib/core/frames/photo_frames.dart (its id, a name, its aspect, which this
prints) and run tool/trace_frame_windows.py, which finds its windows.

Each picture is:

- **Cleared of haze.** Cut-out artwork arrives with a faint veil of nearly
  clear pixels round the paper and scattered through the window. Drawn over
  a photo, that veil is a grey smudge; below alpha HAZE it is cleared.
- **Trimmed to what it draws**, so the canvas has no dead margin.
- **Fitted to SIDE pixels on its longest side**, resampled with its colour
  premultiplied by its alpha. Resampled straight, the clear pixels' colour
  (usually black) bleeds into the paper's edge as a dark rim.
- **Saved as lossy WebP with alpha**, at QUALITY.

⚠️ **Every frame is in the APK**, which has a hard 50 MiB ceiling (Supabase's
upload limit; see tool/publish_update.dart). This prints the total the frames
add up to. A frame is about 60 KB.

Requires Pillow (`pip install pillow`).
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'assets', 'images', 'frames')

# Below this alpha a pixel is cut-out residue, not artwork. The same line
# trace_frame_windows.py draws round what a frame draws.
HAZE = 32

# Longest side, in pixels. The frames are drawn at about 350pt on a phone,
# and composed at 1280px; 760 is what every frame so far has used.
SIDE = 760

# WebP quality. Where the paper's grain stops changing to the eye.
QUALITY = 86


def convert(src, frame_id):
    im = Image.open(src).convert('RGBA')
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < HAZE else v)
    im = Image.merge('RGBA', (r, g, b, a))
    box = a.getbbox()
    if box is None:
        raise SystemExit('%s: nothing is drawn in it' % src)
    im = im.crop(box)
    scale = SIDE / max(im.size)
    size = (round(im.width * scale), round(im.height * scale))
    # Premultiplied, so the clear pixels' colour does not bleed into edges.
    im = im.convert('RGBa').resize(size, Image.LANCZOS).convert('RGBA')
    out = os.path.join(DEST, frame_id + '.webp')
    im.save(out, 'WEBP', quality=QUALITY, method=6)
    return out, size


def main(args):
    if not args:
        raise SystemExit(__doc__)
    total = 0
    for arg in args:
        src, _, frame_id = arg.rpartition('=')
        if not src or not frame_id:
            raise SystemExit('expected <art.png>=<id>, got %s' % arg)
        out, (w, h) = convert(src, frame_id)
        n = os.path.getsize(out)
        total += n
        print('%-22s %4dx%-4d  aspect: %d / %d  %5.1f KB'
              % (frame_id, w, h, w, h, n / 1024))
    print('%d frame(s), %.0f KB' % (len(args), total / 1024))


if __name__ == '__main__':
    main(sys.argv[1:])
