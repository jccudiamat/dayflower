"""Regenerates the status-bar notification icon from the app's own mark.

    python tool/trace_notification_icon.py
    python tool/trace_notification_icon.py --self-test

Android masks a notification icon to a silhouette — it discards every colour
and paints whatever is opaque white — so the status bar icon can only ever be
a flat shape.

🔴 **A silhouette of the full-colour mark is a blob.** The launcher icon reads
as a flower *and* a heart because of its colour: a dark heart behind two
overlapping petals, one shaded in front of the other. Mask that and the
boundaries live in the colour, not the outline, so all three shapes melt into
one round lump. Tracing `ic_launcher_monochrome.png` is exactly what the first
version of this file did, and that lump is what it produced.

The fix is not in the tracing, it is in the source. `notification_mark.png` is
the same mark redrawn **flat**, with the boundaries between the heart and the
two petals cut as real gaps in the artwork rather than implied by shading. It
is three separate white shapes on a background, so the silhouette keeps every
edge that makes the mark legible. That is the whole trick: a silhouette can
only show what is already a gap.

⚠️ **The gaps are the thing to protect if the mark is ever redrawn.** They are
~40px of a 710px-wide mark here, which lands at ~1.2dp inside the 24dp box —
about three screen pixels on a 3x phone. Much narrower and they close up into
the blob again at status-bar size.

⚠️ **Tracing it is the point.** A hand-drawn path would be a second copy of
the mark, free to drift from the real one the next time the icon is redrawn.
This reads the actual pixels, so re-running it after a rebrand is the whole
migration.

Requires Pillow (`pip install pillow`). Not part of the build — the generated
XML is committed, and this exists so the next person does not have to guess
where the path came from.
"""
import os
import re
import sys
import textwrap

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ⚠️ NOT the launcher icon and not its monochrome layer. See the module
# docstring: this is the flat redraw, the only version whose silhouette still
# reads as a flower and a heart. assets/icon/ is deliberately not a bundled
# Flutter asset directory, so keeping the master here ships nothing.
SRC = os.path.join(ROOT, 'assets', 'icon', 'src', 'notification_mark.png')
DEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                    'drawable', 'ic_notification.xml')

# The notification icon's box, and how much of it the artwork fills. 24dp is
# the size Android draws a status-bar icon at; the 1dp of air each side stops
# it touching the icons beside it.
VIEW, LIVE = 24.0, 22.0

# RDP tolerance, **in dp** rather than source pixels, so re-running this
# against a larger or smaller master gives the same curve rather than a
# different one. 0.05dp is a fifth of a screen pixel even at 4x.
#
# ⚠️ Deliberately tight. The alternative to a faithful trace is a smoothing
# pass, and it would round off the petal notches and the heart's cleft —
# the only things telling this shape apart from a circle at status-bar size.
EPS_DP = 0.05

# A pixel belongs to the mark when it is opaque and bright. The master is
# white-on-red; the threshold sits well clear of both.
BRIGHT = 200

# Contours shorter than this are rendering noise — a stray antialiased pixel
# at a corner — not a shape anyone drew.
MIN_CONTOUR_PX = 40


def load_mask(path):
    """`mask[x][y]` — True where the artwork is."""
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    mask = [[False] * h for _ in range(w)]
    for x in range(w):
        col = mask[x]
        for y in range(h):
            r, g, b, a = px[x, y]
            col[y] = a >= 128 and r >= BRIGHT and g >= BRIGHT and b >= BRIGHT
    return mask, w, h


def components(mask, w, h, want):
    """Flood-fill every 4-connected region where `mask` is `want`.

    Returns a list of (seed, pixel_count) — the seed is the region's
    top-left-most pixel, which is where contour tracing has to start.
    """
    seen = [[False] * h for _ in range(w)]
    out = []
    # Column-major so the first pixel found in a region is its leftmost, and
    # among those its topmost — the corner Moore tracing needs.
    for x in range(w):
        for y in range(h):
            if mask[x][y] != want or seen[x][y]:
                continue
            stack = [(x, y)]
            seen[x][y] = True
            n = 0
            while stack:
                cx, cy = stack.pop()
                n += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (0 <= nx < w and 0 <= ny < h
                            and mask[nx][ny] == want and not seen[nx][ny]):
                        seen[nx][ny] = True
                        stack.append((nx, ny))
            out.append(((x, y), n))
    return out


def trace(inside, start):
    """Moore-neighbour trace of one region's boundary, from its corner pixel.

    `inside(x, y)` says whether a pixel belongs to the region being traced —
    so the same routine walks the outside of a shape and the inside of a
    hole, depending on what is passed in.
    """
    n8 = [(-1, 0), (-1, -1), (0, -1), (1, -1),
          (1, 0), (1, 1), (0, 1), (-1, 1)]
    ring = [start]
    cur, back = start, (-1, 0)
    for _ in range(4000000):
        i = n8.index(back)
        nxt = None
        for k in range(1, 9):
            d = n8[(i + k) % 8]
            p = (cur[0] + d[0], cur[1] + d[1])
            if inside(*p):
                nxt, back = p, (-d[0], -d[1])
                break
        if nxt is None or (nxt == start and len(ring) > 2):
            break
        ring.append(nxt)
        cur = nxt
    else:
        raise SystemExit('contour did not close after 4M steps')
    return ring


def rdp(pts, eps):
    """Ramer-Douglas-Peucker: drop points that sit on a line already."""
    if len(pts) < 3:
        return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]
    dx, dy = x2 - x1, y2 - y1
    span = (dx * dx + dy * dy) ** 0.5
    worst, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        # ⚠️ A closed ring arrives with first == last, so `span` is 0 and the
        # line formula is undefined. Distance to the point, not 0 — returning
        # 0 collapses the entire ring to two points.
        if span:
            d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / span
        else:
            d = ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
        if d > worst:
            worst, idx = d, i
    if worst <= eps:
        return [pts[0], pts[-1]]
    return rdp(pts[:idx + 1], eps)[:-1] + rdp(pts[idx:], eps)


def signed_area(pts):
    a = 0.0
    for i, (x1, y1) in enumerate(pts):
        x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    return a / 2.0


def contours(mask, w, h):
    """Every boundary in the mask: shape outlines, then the holes in them.

    Holes come back tagged so the caller can wind them the other way. There
    are none in the mark as drawn — but a flower is exactly the kind of shape
    that grows one, and a hole traced the same direction as its shape fills
    solid instead of cutting.
    """
    rings = []
    for seed, n in components(mask, w, h, True):
        if n < MIN_CONTOUR_PX:
            continue
        rings.append((trace(lambda x, y: (0 <= x < w and 0 <= y < h
                                          and mask[x][y]), seed), False))

    # A background region that never touches the border is enclosed: a hole.
    for seed, n in components(mask, w, h, False):
        if n < MIN_CONTOUR_PX:
            continue
        touches_border = False
        stack, seen = [seed], {seed}
        while stack and not touches_border:
            cx, cy = stack.pop()
            if cx in (0, w - 1) or cy in (0, h - 1):
                touches_border = True
                break
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (cx + dx, cy + dy)
                if (0 <= p[0] < w and 0 <= p[1] < h
                        and not mask[p[0]][p[1]] and p not in seen):
                    seen.add(p)
                    stack.append(p)
        if not touches_border:
            rings.append((trace(lambda x, y: (0 <= x < w and 0 <= y < h
                                              and not mask[x][y]), seed), True))
    return rings


HEADER = '''<!-- Status-bar icon: the Dayflower tulip.

     Android masks a notification icon to a silhouette - it throws away every
     colour and paints whatever is opaque white - so this is a flat white
     shape on transparent. Using @mipmap/ic_launcher here would render as a
     white blob, which is what that masking does to a full-colour icon.

     WARNING: GENERATED. Traced from assets/icon/src/notification_mark.png -
     the flat redraw of the mark, NOT the launcher icon. The launcher icon
     carries the boundaries between the heart and the two petals in its
     shading, and a silhouette throws shading away, so tracing it gives one
     round lump. The flat master cuts those boundaries as real gaps, which is
     the only form a silhouette can keep them in. Re-run
     tool/trace_notification_icon.py after any change to the mark; do not
     edit the path below.

     %(shapes)d shapes, %(pts)d points: the heart and the two petals, each a subpath of its own, with the gaps between them left empty. Those gaps run about %(gap).1fdp wide inside the %(view)gdp box - roughly three screen pixels on a 3x phone. If the mark is ever redrawn, that is the measurement to protect; much narrower and the three shapes close back into a blob at status-bar size.

     %(live)gdp of artwork inside the %(view)gdp box. -->
'''


def build(mask, w, h):
    """mask -> (path data, stats). Shared with --self-test."""
    rings = contours(mask, w, h)
    if not rings:
        raise SystemExit('%s has no artwork in it' % SRC)

    # Scale is set by the union of every shape, so the pieces keep their
    # positions relative to each other.
    allpts = [p for ring, _ in rings for p in ring]
    bx = min(p[0] for p in allpts)
    by = min(p[1] for p in allpts)
    bw = max(p[0] for p in allpts) - bx
    bh = max(p[1] for p in allpts) - by
    scale = LIVE / max(bw, bh)
    ox, oy = (VIEW - bw * scale) / 2, (VIEW - bh * scale) / 2

    subpaths, raw = [], 0
    for ring, is_hole in rings:
        raw += len(ring)
        simple = rdp(ring + [ring[0]], EPS_DP / scale)
        pts = [(round((x - bx) * scale + ox, 2),
                round((y - by) * scale + oy, 2)) for x, y in simple]
        ded = [pts[0]]
        for p in pts[1:]:
            if p != ded[-1]:
                ded.append(p)
        if len(ded) > 1 and ded[-1] == ded[0]:
            ded.pop()
        if len(ded) < 3:
            continue
        # ⚠️ Holes are wound the OTHER way round. VectorDrawable fills
        # non-zero by default, so a hole running the same direction as the
        # shape around it fills solid rather than cutting. (fillType="evenOdd"
        # would also do it but is API 24+; winding needs no version at all.)
        if is_hole == (signed_area(ded) > 0):
            ded.reverse()
        subpaths.append(ded)

    # Largest first: the leading M is what a reader's eye lands on, and the
    # order is otherwise an accident of which pixel came first.
    subpaths.sort(key=lambda s: -abs(signed_area(s)))

    def sub(pts):
        return 'M%g,%g' % pts[0] + ''.join('L%g,%g' % p for p in pts[1:]) + 'Z'

    data = ''.join(sub(s) for s in subpaths)
    return data, dict(shapes=len(subpaths), raw=raw,
                      pts=sum(len(s) for s in subpaths),
                      w=bw * scale, h=bh * scale, scale=scale)


def gap_dp(mask, w, h, scale):
    """The typical gap between two shapes, in dp — the legibility budget.

    ⚠️ The **median** of the gaps crossed by a horizontal scanline, not the
    minimum. Every one of these gaps tapers to nothing at the tangent where
    two shapes meet, so the minimum is always ~0 and says nothing about
    whether the separation reads. What matters is the width along the run.
    """
    runs = []
    for y in range(h):
        row = [mask[i][y] for i in range(w)]
        if not any(row):
            continue
        first, last = row.index(True), len(row) - 1 - row[::-1].index(True)
        x = first
        while x <= last:
            if not row[x]:
                s = x
                while x <= last and not row[x]:
                    x += 1
                runs.append(x - s)
            else:
                x += 1
    if not runs:
        return 0.0
    runs.sort()
    return runs[len(runs) // 2] * scale


def self_test():
    """A donut: proves holes come out cut rather than filled."""
    n = 120
    mask = [[False] * n for _ in range(n)]
    for x in range(n):
        for y in range(n):
            d = ((x - n / 2) ** 2 + (y - n / 2) ** 2) ** 0.5
            mask[x][y] = 18 < d < 50
    rings = contours(mask, n, n)
    holes = [h for _, h in rings]
    assert len(rings) == 2 and holes.count(True) == 1, rings and holes
    data, st = build(mask, n, n)
    assert st['shapes'] == 2, st
    # Two subpaths, opposite winding: that is what makes the hole a hole.
    areas = [signed_area([tuple(float(v) for v in p.split(','))
                          for p in s.split('L')])
             for s in data.rstrip('Z').split('Z')
             for s in [s.lstrip('M')]]
    assert (areas[0] > 0) != (areas[1] > 0), areas
    print('self-test ok: donut -> 2 subpaths, opposite winding %s'
          % ['+' if a > 0 else '-' for a in areas])


def main():
    if '--self-test' in sys.argv:
        return self_test()

    mask, w, h = load_mask(SRC)
    data, st = build(mask, w, h)
    gap = gap_dp(mask, w, h, st['scale'])

    # Wrapped so a diff on this file stays readable.
    lines, line = [], '        '
    for tok in re.findall(r'[MLZ][^MLZ]*', data):
        if len(line) + len(tok) > 96:
            lines.append(line.rstrip())
            line = '        '
        line += tok
    lines.append(line.rstrip())

    # Rewrapped after substitution — the numbers change length, and a comment
    # with one stubby line in the middle of it looks like a merge artefact.
    head = '\n\n'.join(
        textwrap.fill(re.sub(r'\s+', ' ', para).strip(), width=76,
                      initial_indent='     ', subsequent_indent='     ')
        for para in (HEADER % dict(st, view=VIEW, live=LIVE, gap=gap)).split('\n\n')
    ).lstrip() + '\n'
    xml = (head +
           '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
           '    android:width="%gdp"\n'
           '    android:height="%gdp"\n'
           '    android:viewportWidth="%g"\n'
           '    android:viewportHeight="%g"\n'
           '    android:tint="#FFFFFFFF">\n'
           '    <path\n'
           '        android:fillColor="#FFFFFFFF"\n'
           '        android:pathData="\n%s" />\n'
           '</vector>\n' % (VIEW, VIEW, VIEW, VIEW, '\n'.join(lines)))

    with open(DEST, 'w', encoding='utf-8', newline='\n') as f:
        f.write(xml)

    print('%s: %d contour px -> %d shapes, %d points'
          % (os.path.relpath(SRC, ROOT), st['raw'], st['shapes'], st['pts']))
    print('artwork %.2f x %.2f dp in a %gdp box, typical gap %.2fdp'
          % (st['w'], st['h'], VIEW, gap))
    print('wrote %s' % os.path.relpath(DEST, ROOT))


if __name__ == '__main__':
    main()
