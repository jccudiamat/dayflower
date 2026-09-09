"""Regenerates the status-bar notification icon from the app's own mark.

    python tool/trace_notification_icon.py

Android masks a notification icon to a silhouette — it discards every colour
and paints whatever is opaque white — so the status bar icon can only ever be
a flat shape. The app already has that shape: the monochrome layer of the
adaptive launcher icon, `drawable-xxxhdpi/ic_launcher_monochrome.png`, is the
tulip as white-on-transparent at 432px.

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

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                   'drawable-xxxhdpi', 'ic_launcher_monochrome.png')
DEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                    'drawable', 'ic_notification.xml')

# The notification icon's box, and how much of it the artwork fills. 24dp is
# the size Android draws a status-bar icon at; the 2dp of air stops it
# touching the icons either side of it.
VIEW, LIVE = 24.0, 22.0

# RDP tolerance, in source pixels. ⚠️ Deliberately tight. 0.45px of a 432px
# source is 0.025dp — under a tenth of a screen pixel even at 4x — and the
# alternative to a faithful trace is a smoothing pass that would round off
# the petal notches, which are the only thing telling this shape apart from
# a circle at status-bar size.
EPS = 0.45


def trace(alpha, w, h):
    """The outer contour, as a ring of pixel coordinates."""

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and alpha[x, y] >= 128

    start = None
    for y in range(h):
        for x in range(w):
            if solid(x, y):
                start = (x, y)
                break
        if start:
            break
    if start is None:
        raise SystemExit('%s is fully transparent' % SRC)

    # Moore-neighbour tracing, clockwise from the first opaque pixel.
    n8 = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]
    ring = [start]
    cur, back = start, (-1, 0)
    for _ in range(400000):
        i = n8.index(back)
        nxt = None
        for k in range(1, 9):
            d = n8[(i + k) % 8]
            p = (cur[0] + d[0], cur[1] + d[1])
            if solid(*p):
                nxt, back = p, (-d[0], -d[1])
                break
        if nxt is None or (nxt == start and len(ring) > 2):
            break
        ring.append(nxt)
        cur = nxt
    else:
        raise SystemExit('contour did not close — is the mark one shape?')
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
        if span:
            d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / span
        else:
            d = ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
        if d > worst:
            worst, idx = d, i
    if worst <= eps:
        return [pts[0], pts[-1]]
    return rdp(pts[:idx + 1], eps)[:-1] + rdp(pts[idx:], eps)


HEADER = '''<!-- Status-bar icon: the Dayflower tulip.

     Android masks a notification icon to a silhouette - it throws away every
     colour and paints whatever is opaque white - so this is a flat white
     shape on transparent. Using @mipmap/ic_launcher here would render as a
     white blob, which is what that masking does to a full-colour icon.

     WARNING: GENERATED. This path is traced from the app's own mark rather
     than drawn by hand - res/drawable-xxxhdpi/ic_launcher_monochrome.png,
     the monochrome adaptive-icon layer, which is already this silhouette at
     432px. Tracing it is what stops the status bar icon and the app icon
     drifting apart. Re-run tool/trace_notification_icon.py after any change
     to the mark; do not edit the path below.

     %(live)gdp of artwork inside the %(view)gdp box, and the notched top is the
     only thing telling this apart from a circle at status-bar size - which
     is why the trace keeps its corners sharp rather than smoothing them. -->
'''


def main():
    im = Image.open(SRC).convert('RGBA')
    w, h = im.size
    ring = trace(im.split()[3].load(), w, h)
    simple = rdp(ring + [ring[0]], EPS)

    xs = [p[0] for p in simple]
    ys = [p[1] for p in simple]
    bx, by = min(xs), min(ys)
    bw, bh = max(xs) - bx, max(ys) - by
    scale = LIVE / max(bw, bh)
    ox, oy = (VIEW - bw * scale) / 2, (VIEW - bh * scale) / 2

    pts = [(round((x - bx) * scale + ox, 2), round((y - by) * scale + oy, 2))
           for x, y in simple]
    ded = [pts[0]]
    for p in pts[1:]:
        if p != ded[-1]:
            ded.append(p)
    if ded[-1] == ded[0]:
        ded.pop()

    data = 'M%g,%g' % ded[0] + ''.join('L%g,%g' % p for p in ded[1:]) + 'Z'

    # Wrapped so a diff on this file stays readable.
    lines, line = [], '        '
    for tok in re.findall(r'[MLZ][^MLZ]*', data):
        if len(line) + len(tok) > 96:
            lines.append(line.rstrip())
            line = '        '
        line += tok
    lines.append(line.rstrip())

    xml = (HEADER % {'live': LIVE, 'view': VIEW} +
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

    print('%d contour px -> %d points' % (len(ring), len(ded)))
    print('artwork %.2f x %.2f dp in a %gdp box' % (bw * scale, bh * scale, VIEW))
    print('wrote %s' % os.path.relpath(DEST, ROOT))


if __name__ == '__main__':
    main()
