/**
 * Curve helpers for the scenery.
 *
 * Every horizon, slope and bank in the world is a short list of anchor
 * points, smoothed here into one path. Two reasons it is not hand-written
 * bezier data: the same anchors can be *sampled* to plant grass along the
 * edge they describe, and a slope you can nudge by moving one number is a
 * slope somebody will actually adjust.
 */
export type Pt = [number, number];

/**
 * Catmull-Rom through the anchors, emitted as cubic segments, then closed
 * down to `bottom` to make a fillable silhouette.
 */
export function slope(points: Pt[], bottom: number): string {
  let d = `M${points[0][0]},${points[0][1]}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i - 1] ?? points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] ?? points[i + 1];
    const c1: Pt = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2: Pt = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C${c1[0].toFixed(1)},${c1[1].toFixed(1)} ${c2[0].toFixed(1)},${c2[1].toFixed(1)} ${p2[0]},${p2[1]}`;
  }
  return `${d} L${points[points.length - 1][0]},${bottom} L${points[0][0]},${bottom} Z`;
}

/** Height of a slope at x, by walking the anchors. Good enough for planting. */
export function heightAt(points: Pt[], x: number): number {
  for (let i = 0; i < points.length - 1; i++) {
    const [x1, y1] = points[i];
    const [x2, y2] = points[i + 1];
    if (x >= x1 && x <= x2) {
      // Smoothstep rather than linear, so blades follow the drawn curve
      // instead of the straight line between anchors.
      const t = (x - x1) / (x2 - x1 || 1);
      return y1 + (y2 - y1) * (t * t * (3 - 2 * t));
    }
  }
  return points[x < points[0][0] ? 0 : points.length - 1][1];
}

/**
 * Grass along an edge, as one path.
 *
 * 🔴 One element, not four hundred. A blade is four points; a fringe is a
 * few hundred blades; four hundred `<path>` nodes on a page that also has a
 * meadow in front of it is how a static picture starts costing frames.
 */
export function fringe(
  points: Pt[],
  from: number,
  to: number,
  step: number,
  height: number,
  rand: () => number,
): string {
  let d = "";
  for (let x = from; x < to; x += step) {
    const y = Math.round(heightAt(points, x) + 2);
    const h = Math.round(height * (0.45 + rand() * 0.95));
    const lean = Math.round((rand() - 0.5) * h * 0.7);
    const w = Math.round(step * (0.5 + rand() * 0.6)) || 1;
    // ⚠️ A straight-sided blade, not a curved one. At four pixels tall the
    // curve is invisible and each blade costs twice the path data; a fringe
    // is several hundred blades and the homepage carries eight of them.
    d += `M${Math.round(x)},${y}l${lean},${-h}l${w},${h}Z`;
  }
  return d;
}
