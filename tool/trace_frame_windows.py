"""Traces the hole in every photo frame, so a photo is cut to the hole's shape.

    python tool/trace_frame_windows.py

Writes lib/core/frames/frame_windows.dart. Run it again whenever a frame is
added to assets/images/frames/ or redrawn; the frame's name and aspect still
go in photo_frames.dart by hand, and its windows come from here.

🔴 **A window is a shape, not a rectangle.** The first frames stored each
window as the box around its hole, and the photo was clipped to that box.
That is only right for a polaroid. The cloud's hole is a cloud: its box
reaches past the outline into the corners, where the paper is transparent,
so the photo showed there, outside the frame, in the camera and in every
photo sent with it. The box was also measured on a coarse grid, three pixels
short of the hole's bottom edge, which left a thin line of whatever was
behind the picture showing between the photo and the paper.

So each window is now the hole's own outline, traced from the artwork's
alpha channel: a transparent region the paper completely encloses. Anything
transparent that reaches the edge of the image is outside the frame.

⚠️ **The outline is grown by DILATE pixels past the hole.** The paper's inner
edge is antialiased, and a photo cut exactly to the hole would leave that
half-transparent ring showing whatever is behind. Grown a little, the photo
runs under the paper's edge, which is drawn on top of it anyway. The script
refuses to write a frame whose paper is too thin for that to stay hidden.

It also finds each frame's **caption strip**: the blank paper under a
window, the bottom of a polaroid, where Home writes whose day it is and
when. It is measured, tilt and all, rather than placed by eye, so the words
sit on the paper the way a pen would put them there. A frame with no such
strip (a strip too thin to write on) gets none, and Home writes its label
elsewhere.

Requires Pillow (`pip install pillow`). Not part of the build: the generated
Dart is committed.
"""
import math
import os
import sys
from collections import deque

from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trace_notification_icon import rdp, signed_area, trace  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'images', 'frames')
DEST = os.path.join(ROOT, 'lib', 'core', 'frames', 'frame_windows.dart')

# Alpha at or above this is paper. Not 255: the WebP artwork keeps its paper
# at 250 to 254 almost everywhere, so "fully opaque" would find no paper at
# all and every hole would leak out to the edge.
OPAQUE = 250

# How far past the hole the photo runs under the paper, in artwork pixels
# (the frames are about 760 across).
DILATE = 3

# Ramer-Douglas-Peucker tolerance, in artwork pixels. The outline may cut
# inward by this much, which DILATE more than covers.
EPS = 0.75

# A hole smaller than this share of the frame is a gap in the drawing (the
# inside of a sparkle, a stray transparent pixel), not a place for a photo.
MIN_WINDOW = 0.01

# A caption strip thinner than this share of the frame's height is too thin
# to write a line in at a size anybody could read.
MIN_STRIP = 0.06

# Of the paper under a window, how much a caption uses: some air above and
# below the words, and in from the ends.
STRIP_FILL = (0.86, 0.62)

# A window's bottom edge that strays further than this from a straight line
# (in artwork pixels, on average) is not an edge to write along: a cloud's
# is wavy. The caption is written level under it instead.
MAX_WAVE = 4.0


def load_alpha(path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    return im.getchannel('A').tobytes(), w, h


def flood(open_, w, h, seeds, label, out, value):
    """Marks every pixel 4-connected to [seeds] where open_[i] is true."""
    q = deque()
    for i in seeds:
        if open_[i] and not out[i]:
            out[i] = value
            q.append(i)
    n = 0
    while q:
        i = q.popleft()
        n += 1
        x, y = i % w, i // w
        if x > 0:
            j = i - 1
            if open_[j] and not out[j]:
                out[j] = value
                q.append(j)
        if x < w - 1:
            j = i + 1
            if open_[j] and not out[j]:
                out[j] = value
                q.append(j)
        if y > 0:
            j = i - w
            if open_[j] and not out[j]:
                out[j] = value
                q.append(j)
        if y < h - 1:
            j = i + w
            if open_[j] and not out[j]:
                out[j] = value
                q.append(j)
    return n


def holes(alpha, w, h):
    """(exterior, [(pixel count, label)], labels) for one frame."""
    see_through = bytes(1 if a < OPAQUE else 0 for a in alpha)
    labels = [0] * (w * h)
    edge = ([x for x in range(w)] + [(h - 1) * w + x for x in range(w)] +
            [y * w for y in range(h)] + [y * w + w - 1 for y in range(h)])
    # Label 1 is outside the frame: see-through and reachable from an edge.
    flood(see_through, w, h, edge, None, labels, 1)
    found = []
    label = 2
    for i in range(w * h):
        if see_through[i] and not labels[i]:
            n = flood(see_through, w, h, [i], None, labels, label)
            found.append((n, label))
            label += 1
    found.sort(reverse=True)
    return found, labels


def mask_of(labels, w, h, want):
    return Image.frombytes(
        'L', (w, h), bytes(255 if v == want else 0 for v in labels))


def grow(mask, r):
    return mask.filter(ImageFilter.MaxFilter(2 * r + 1))


def outline(mask, w, h):
    """The outer edge of [mask], simplified, as pixel-centre points."""
    px = mask.tobytes()
    x0 = mask.getbbox()[0]
    # Moore tracing starts at the region's leftmost column, topmost in it.
    y0 = next(y for y in range(h) if px[y * w + x0])
    ring = trace(lambda x, y: 0 <= x < w and 0 <= y < h and px[y * w + x],
                 (x0, y0))
    pts = rdp(ring + [ring[0]], EPS)
    if pts[-1] == pts[0]:
        pts.pop()
    # Clockwise on screen, whichever way the trace happened to walk, so
    # every outline in the file reads the same way round.
    if signed_area(pts) < 0:
        pts.reverse()
    return [((x + 0.5) / w, (y + 0.5) / h) for x, y in pts]


def caption_strip(alpha, labels, kept, w, h):
    """The blank paper under a window, as (cx, cy, width, height, angle).

    Walks down each column from the window's bottom edge to the edge of the
    frame, then fits one straight line to where the strips start and
    lays a band of the same slope under it, as tall as every column allows.
    The window with the tallest band wins; None when none is tall enough.
    """
    windows = {lab for _, lab in kept}
    best = None
    for _, lab in kept:
        cols = [x for x in range(w)
                if any(labels[y * w + x] == lab for y in range(0, h, 2))]
        if not cols:
            continue
        # The middle of the window's width: its ends curve away on a torn
        # or rounded window, and the words do not need them.
        x0, x1 = cols[0], cols[-1]
        span = x1 - x0
        runs = []
        for x in range(int(x0 + span * .15), int(x1 - span * .15) + 1, 2):
            last = max((y for y in range(h) if labels[y * w + x] == lab),
                       default=None)
            if last is None:
                continue
            top = last + 1 + DILATE
            end = top
            # Down to the edge of the frame or into another window. Not to
            # the first clear pixel: the paper's texture has specks of it.
            while (end < h and labels[end * w + x] != 1
                   and labels[end * w + x] not in windows):
                end += 1
            runs.append((x, top, end))
        if len(runs) < 8:
            continue
        n = len(runs)
        mx = sum(r[0] for r in runs) / n
        my = sum(r[1] for r in runs) / n
        sxx = sum((r[0] - mx) ** 2 for r in runs)
        slope = sum((r[0] - mx) * (r[1] - my) for r in runs) / sxx if sxx else 0
        wave = (sum((r[1] - my - slope * (r[0] - mx)) ** 2 for r in runs)
                / n) ** .5
        if wave > MAX_WAVE:
            slope = 0.0
        # The band's top is above no strip's start, its bottom below no
        # strip's end: every column has paper for all of it.
        a = max(r[1] - slope * r[0] for r in runs)
        c = min(r[2] - slope * r[0] for r in runs)
        if c <= a:
            continue
        angle = math.atan(slope)
        tall = (c - a) * math.cos(angle)
        if tall < MIN_STRIP * h:
            continue
        cx = (runs[0][0] + runs[-1][0]) / 2
        cy = (a + c) / 2 + slope * cx
        wide = (runs[-1][0] - runs[0][0]) / math.cos(angle)
        spot = (cx / w, cy / h, wide * STRIP_FILL[0] / w,
                tall * STRIP_FILL[1] / h, angle)
        if best is None or tall > best[0]:
            best = (tall, spot)
    return None if best is None else best[1]


def frame_windows(name):
    alpha, w, h = load_alpha(os.path.join(SRC, name + '.webp'))
    found, labels = holes(alpha, w, h)
    outside = mask_of(labels, w, h, 1)
    kept = [(n, lab) for n, lab in found if n >= MIN_WINDOW * w * h]
    windows = []
    for n, lab in kept:
        hole = mask_of(labels, w, h, lab)
        grown = grow(hole, DILATE)
        # 🔴 The photo must stay under paper. Grown once more by the
        # simplification's slack, the window may not reach outside the frame
        # or into another window.
        reach = grow(hole, DILATE + int(EPS) + 1)
        if ImageChops.multiply(reach, outside).getbbox():
            raise SystemExit('%s: the paper around a window is thinner than '
                             '%dpx, so the photo would show outside it'
                             % (name, DILATE + 2))
        for _, other in kept:
            if other != lab and ImageChops.multiply(
                    reach, mask_of(labels, w, h, other)).getbbox():
                raise SystemExit('%s: two windows are too close to keep '
                                 'their photos apart' % name)
        # Rounded here, before the box is taken, so the box written out is
        # exactly the box around the points written out.
        pts = [(round(x, 4), round(y, 4)) for x, y in outline(grown, w, h)]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        windows.append(dict(
            share=n / (w * h),
            bounds=(min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)),
            points=pts))
    return windows, (w, h), caption_strip(alpha, labels, kept, w, h)


HEADER = '''// GENERATED by tool/trace_frame_windows.py from the artwork's alpha channel.
// Do not edit by hand: add or redraw a frame, then run the script again.
//
// Every window is the hole's own outline, grown %(dilate)dpx so the photo runs
// under the paper's antialiased edge, as fractions of the frame's box. Largest
// window first, which is the order photos fill them.

import 'dart:ui' show Offset, Rect, Size;

import 'photo_frames.dart';

const frameWindows = <String, List<FrameWindow>>{
'''


STRIPS_HEADER = '''
// The blank paper under a window, where Home writes whose day it is and
// when: its centre and size as fractions of the frame's box, and its tilt
// in radians. Frames with no strip wide enough to write on are absent.
const frameCaptionStrips = <String, FrameCaptionStrip>{
'''


def fmt(v):
    s = '%.4f' % v
    return s.rstrip('0').rstrip('.') if '.' in s else s


def main():
    names = sorted(f[:-5] for f in os.listdir(SRC) if f.endswith('.webp'))
    out = [HEADER % dict(dilate=DILATE)]
    strips = {}
    for name in names:
        windows, (w, h), strips[name] = frame_windows(name)
        print('%-20s %dx%d  %d window(s)  %s' % (
            name, w, h, len(windows),
            ', '.join('%.0f%% of it, %d points' % (x['share'] * 100,
                                                  len(x['points']))
                      for x in windows)))
        out.append("  '%s': [\n" % name)
        for x in windows:
            l, t, bw, bh = x['bounds']
            out.append('    FrameWindow(\n')
            out.append('      Rect.fromLTWH(%s, %s, %s, %s),\n'
                       % (fmt(l), fmt(t), fmt(bw), fmt(bh)))
            out.append('      [\n')
            flat = [fmt(v) for p in x['points'] for v in p]
            for i in range(0, len(flat), 8):
                out.append('        %s,\n' % ', '.join(flat[i:i + 8]))
            out.append('      ],\n')
            out.append('    ),\n')
        out.append('  ],\n')
    out.append('};\n')
    out.append(STRIPS_HEADER)
    for name in names:
        spot = strips[name]
        print('%-20s caption strip: %s' % (
            name, 'none' if spot is None else
            '%.0f%% by %.0f%%, tilted %.1f deg' % (
                spot[2] * 100, spot[3] * 100, math.degrees(spot[4]))))
        if spot is None:
            continue
        cx, cy, sw, sh, angle = spot
        out.append("  '%s': FrameCaptionStrip(\n"
                   "      Offset(%s, %s), Size(%s, %s), %s),\n"
                   % (name, fmt(cx), fmt(cy), fmt(sw), fmt(sh), fmt(angle)))
    out.append('};\n')
    with open(DEST, 'w', encoding='utf-8', newline='\n') as f:
        f.write(''.join(out))
    print('wrote %s' % os.path.relpath(DEST, ROOT))


if __name__ == '__main__':
    main()
