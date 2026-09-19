import { PALETTE, seeded, type Palette, type Time } from "./palette";
import { fringe, heightAt, slope, type Pt } from "./shapes";

/**
 * The scenery behind the first and last sections of the homepage.
 *
 * 🔴 **Nothing here is content.** The whole tree is `aria-hidden` and
 * `pointer-events: none`; every word, link and field on the page is HTML
 * layered above it. Delete this component and the homepage still says the
 * same things over a painted sky.
 *
 * Built as layered 2.5D rather than WebGL. The reference is a still painting
 * with a very small amount of life in it, and a few hundred SVG shapes that
 * never repaint reproduce it closer — and on a mid-range phone far cheaper —
 * than a scene graph would.
 *
 * ⚠️ Three layers, three different ways of meeting the viewport:
 *  - `far` and `hills` stretch (`preserveAspectRatio="none"`). They are
 *    gradients and soft silhouettes; nobody can see a hill 12% wider than it
 *    was drawn, and stretching is what keeps the town on the right-hand edge
 *    on a phone instead of cropping it away.
 *  - `near` keeps its aspect and crops, because a flower stretched to twice
 *    its width reads immediately as broken.
 *
 * ⚠️ **Depth is made of haze, not of outlines.** Every range and every slope
 * is followed by a wash of the horizon colour. Take those out and the picture
 * collapses into flat bands of green, which is exactly what it looked like
 * the first time.
 */
export default function Scenery({ time }: { time: Time }) {
  const p = PALETTE[time];
  const night = time === "night";
  return (
    <div className={`scene scene-${time}`} aria-hidden>
      <Far time={time} p={p} />
      <Hills time={time} p={p} />
      <Near time={time} p={p} />
      {night && <Moon />}
      {night ? <NightTrees p={p} /> : <Canopy p={p} />}
      <div className="scene-light" />
      <div className="scene-vignette" />
    </div>
  );
}

/* ── Sky, mountains, lake, town ───────────────────────────────────────────
 *
 * The waterline sits at y=496 of 640 in every light, which is the whole
 * trick behind the two scenes being one place.
 */

const FAR_RANGE: Pt[] = [
  [-40, 470], [90, 402], [210, 452], [330, 372], [452, 436],
  [560, 392], [680, 448], [790, 404], [900, 444], [1010, 388],
  [1130, 442], [1250, 396], [1370, 446], [1480, 412],
];
const MID_RANGE: Pt[] = [
  [-40, 492], [70, 430], [180, 484], [300, 448], [420, 490],
  [540, 470], [700, 494], [880, 494], [1000, 452], [1100, 486],
  [1210, 438], [1320, 480], [1420, 444], [1480, 468],
];

function Far({ time, p }: { time: Time; p: Palette }) {
  const id = (name: string) => `${name}-${time}`;
  const night = time === "night";
  const rand = seeded(2026);
  const sunX = night ? 470 : 768;
  return (
    <svg className="scene-far" viewBox="0 0 1440 640" preserveAspectRatio="none">
      <defs>
        <linearGradient id={id("sky")} x1="0" y1="0" x2="0.1" y2="1">
          {p.sky.map((c, i) => (
            <stop key={c + i} offset={[0, 0.3, 0.55, 0.78, 1][i]} stopColor={c} />
          ))}
        </linearGradient>
        <radialGradient id={id("glow")}>
          <stop offset="0" stopColor="#fffdf2" stopOpacity={night ? 0.5 : 0.98} />
          <stop offset="0.16" stopColor={p.glow} stopOpacity={night ? 0.3 : 0.82} />
          <stop offset="0.42" stopColor={p.glow} stopOpacity={night ? 0.1 : 0.34} />
          <stop offset="1" stopColor={p.glow} stopOpacity="0" />
        </radialGradient>
        {/* The bloom that lies along the horizon rather than around the sun:
            what makes a low sun read as *low*. */}
        <linearGradient id={id("bloom")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={p.glow} stopOpacity="0" />
          <stop offset="0.6" stopColor={p.glow} stopOpacity={night ? 0.12 : 0.5} />
          <stop offset="1" stopColor={p.glow} stopOpacity="0" />
        </linearGradient>
        {["far", "mid", "ridge", "water"].map((k) => {
          const pair = p[k as "far" | "mid" | "ridge" | "water"];
          return (
            <linearGradient key={k} id={id(k)} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor={pair[0]} />
              <stop offset="1" stopColor={pair[1]} />
            </linearGradient>
          );
        })}
        <linearGradient id={id("haze")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor={p.sky[3]} stopOpacity={night ? 0.66 : 0.95} />
          <stop offset="0.45" stopColor={p.sky[3]} stopOpacity={night ? 0.3 : 0.5} />
          <stop offset="1" stopColor={p.sky[2]} stopOpacity="0" />
        </linearGradient>
        {/* ⚠️ No `feGaussianBlur` anywhere in this layer. Every soft thing
            here — cloud, sun, mist, window light — is a radial gradient that
            fades to nothing instead. A blur inside a
            `preserveAspectRatio="none"` SVG has its filter region stretched
            along with everything else, which makes the cost of it depend on
            the viewport rather than on the drawing, and a dozen of them sit
            over most of the screen. A gradient gives the same softness for
            the price of a fill. */}
        <radialGradient id={id("puff")}>
          <stop offset="0" stopColor="#ffffff" stopOpacity="1" />
          <stop offset="0.45" stopColor="#ffffff" stopOpacity="0.78" />
          <stop offset="1" stopColor="#ffffff" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={id("puffWarm")}>
          <stop offset="0" stopColor={p.cloudWarm} stopOpacity="1" />
          <stop offset="0.45" stopColor={p.cloudWarm} stopOpacity="0.72" />
          <stop offset="1" stopColor={p.cloudWarm} stopOpacity="0" />
        </radialGradient>
        <radialGradient id={id("orb")}>
          <stop offset="0" stopColor="#fffef9" />
          <stop offset="0.42" stopColor="#fffbec" stopOpacity="0.95" />
          <stop offset="0.62" stopColor={p.glow} stopOpacity="0.5" />
          <stop offset="1" stopColor={p.glow} stopOpacity="0" />
        </radialGradient>
        <radialGradient id={id("lamp")}>
          <stop offset="0" stopColor={p.window} stopOpacity="0.85" />
          <stop offset="1" stopColor={p.window} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={id("reflect")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={p.waterLight} stopOpacity={night ? 0.5 : 0.85} />
          <stop offset="1" stopColor={p.waterLight} stopOpacity="0" />
        </linearGradient>
      </defs>

      <rect width="1440" height="640" fill={`url(#${id("sky")})`} />

      {/* Sun, or moon, in the same part of the sky. */}
      <circle cx={sunX} cy={night ? 176 : 448} r={night ? 210 : 420} fill={`url(#${id("glow")})`} />
      {night ? <Stars /> : <Clouds puff={id("puff")} puffWarm={id("puffWarm")} />}
      <rect x="0" y="376" width="1440" height="160" fill={`url(#${id("bloom")})`} />

      {/* Far range, hazed almost to nothing. */}
      <path fill={`url(#${id("far")})`} opacity={night ? 0.82 : 0.7} d={slope(FAR_RANGE, 520)} />
      <rect x="0" y="330" width="1440" height="200" fill={`url(#${id("haze")})`} opacity={night ? 0.5 : 0.68} />

      {/* Nearer range, with the gap the lake is seen through. */}
      <path fill={`url(#${id("mid")})`} opacity={night ? 0.95 : 0.88} d={slope(MID_RANGE, 522)} />
      <rect x="0" y="392" width="1440" height="130" fill={`url(#${id("haze")})`} opacity={night ? 0.34 : 0.4} />

      {/* 🔴 The sun goes *between* the ranges, not behind them. Painted with
          the sky it is a pale smudge under two layers of haze; painted here
          it sits on the water with the far range showing through it, which
          is where the reference puts it and why that scene reads as dawn. */}
      {!night && <circle cx={sunX} cy="450" r="92" fill={`url(#${id("orb")})`} />}

      {/* The two headlands the water runs between. */}
      <path fill={`url(#${id("ridge")})`} opacity="0.92" d="M-20,452 C110,448 214,472 300,494 C356,508 396,500 436,498 L436,524 L-20,524 Z" />
      <path fill={`url(#${id("ridge")})`} opacity="0.92" d="M1460,430 C1336,436 1244,460 1162,486 C1090,508 1028,498 958,498 L958,524 L1460,524 Z" />

      {/* The lake. */}
      <rect x="0" y="494" width="1440" height="146" fill={`url(#${id("water")})`} />
      <path d={`M${sunX - 22},494 L${sunX + 22},494 L${sunX + 82},640 L${sunX - 76},640 Z`} fill={`url(#${id("reflect")})`} />
      <Shimmer p={p} night={night} />

      <Town p={p} night={night} lamp={id("lamp")} />
      <Shoreline p={p} />
      {/* Mist sitting on the water at the foot of the hills. */}
      <g opacity={night ? 0.3 : 0.62}>
        {Array.from({ length: 7 }, (_, i) => (
          <ellipse key={i} cx={n(rand() * 1440)} cy={n(480 + rand() * 26)} rx={n(130 + rand() * 210)} ry={n(14 + rand() * 12)} fill={`url(#${id("puff")})`} opacity={n(0.3 + rand() * 0.35)} />
        ))}
      </g>
    </svg>
  );
}

/**
 * ⚠️ Its own element, not a circle in the `far` layer. That layer stretches
 * to the viewport, and a stretched circle is an egg — which is exactly what
 * the moon looked like on a wide screen.
 */
function Moon() {
  return (
    <svg className="scene-moon" viewBox="0 0 120 120" aria-hidden>
      <circle cx="60" cy="60" r="34" fill="#f7f4e8" />
      <circle cx="49" cy="51" r="8" fill="#e8e4d4" opacity="0.35" />
      <circle cx="71" cy="72" r="5" fill="#e8e4d4" opacity="0.26" />
      <circle cx="53" cy="75" r="3.6" fill="#e8e4d4" opacity="0.2" />
    </svg>
  );
}

function Stars() {
  const rand = seeded(90210);
  return (
    <g fill="#ffffff">
      {Array.from({ length: 70 }, (_, i) => {
        return (
          <circle
            key={i}
            className={i % 6 === 0 ? "twinkle" : undefined}
            cx={n(rand() * 1440)}
            cy={n(rand() * 430)}
            r={n(0.7 + rand() * 1.6)}
            opacity={0.2 + rand() * 0.65}
            style={i % 6 === 0 ? { animationDelay: `-${(rand() * 7).toFixed(1)}s` } : undefined}
          />
        );
      })}
    </g>
  );
}

function Clouds({ puff, puffWarm }: { puff: string; puffWarm: string }) {
  const rand = seeded(4242);
  // Banks of overlapping ellipses blurred into one soft mass. The drift is a
  // four-minute translate: slow enough that you only notice if you stay.
  return (
    <g>
      {[
        { x: 150, y: 132, w: 1.3, o: 0.72, warm: false, d: 0 },
        { x: 620, y: 84, w: 1, o: 0.46, warm: false, d: -70 },
        { x: 1010, y: 156, w: 1.45, o: 0.6, warm: true, d: -140 },
        { x: 1310, y: 104, w: 0.9, o: 0.4, warm: true, d: -30 },
        { x: 380, y: 250, w: 1.15, o: 0.34, warm: true, d: -190 },
        { x: 1120, y: 296, w: 1.25, o: 0.3, warm: true, d: -110 },
        { x: 760, y: 200, w: 1.1, o: 0.26, warm: true, d: -225 },
      ].map((c, i) => (
        <g key={i} className="cloud" style={{ animationDelay: `${c.d}s` }}>
          {Array.from({ length: 5 }, (_, j) => (
            <ellipse
              key={j}
              cx={n(c.x + (rand() - 0.5) * 230 * c.w)}
              cy={n(c.y + (rand() - 0.5) * 36)}
              rx={n((78 + rand() * 120) * c.w)}
              ry={n(26 + rand() * 30)}
              fill={`url(#${c.warm ? puffWarm : puff})`}
              opacity={c.o * 0.8}
            />
          ))}
        </g>
      ))}
    </g>
  );
}

function Shimmer({ p, night }: { p: Palette; night: boolean }) {
  const rand = seeded(777);
  return (
    <g fill={night ? p.waterLight : "#ffffff"}>
      {Array.from({ length: 18 }, (_, i) => (
        <rect
          key={i}
          x={n(rand() * 1380)}
          y={n(498 + rand() * 136)}
          width={n(26 + rand() * 210)}
          height={n(1.4 + rand() * 2.4)}
          rx="1.4"
          opacity={(night ? 0.08 : 0.2) + rand() * 0.22}
        />
      ))}
    </g>
  );
}

/** The town on the far shore: what makes the lake a place people live. */
function Town({ p, night, lamp }: { p: Palette; night: boolean; lamp: string }) {
  const rand = seeded(13579);
  const houses = Array.from({ length: 30 }, (_, i) => {
    const x = n(968 + i * 15.5 + rand() * 8);
    const w = n(12 + rand() * 15);
    const h = n(10 + rand() * 15);
    // The shore falls away to the right, so the town falls with it.
    const y = n(468 + (x - 968) * 0.05 + rand() * 10);
    return { x, y, w, h, lit: rand() > 0.32 };
  });
  return (
    <g>
      {houses.map((h, i) => (
        <g key={i}>
          <rect x={h.x} y={h.y} width={h.w} height={h.h} fill={p.wall} opacity={night ? 0.8 : 0.95} />
          <path d={`M${h.x - 2},${h.y} L${h.x + h.w / 2},${h.y - 5.5} L${h.x + h.w + 2},${h.y} Z`} fill={p.roof} />
          {h.lit && <rect x={h.x + h.w * 0.3} y={h.y + h.h * 0.35} width="2.8" height="3.2" fill={p.window} />}
        </g>
      ))}
      {/* Window light, as light rather than as a coloured rectangle. */}
      <g opacity={night ? 0.95 : 0.5}>
        {houses.filter((h) => h.lit).map((h, i) => (
          <circle key={i} cx={h.x + h.w * 0.4} cy={h.y + h.h * 0.4} r={night ? 18 : 12} fill={`url(#${lamp})`} />
        ))}
      </g>
      {/* …and again on the water, smeared downward. */}
      <g opacity={night ? 0.45 : 0.22}>
        {houses.filter((h) => h.lit).map((h, i) => (
          <rect key={i} x={h.x + h.w * 0.3} y="498" width="2.4" height={16 + rand() * 42} fill={p.window} opacity="0.5" />
        ))}
      </g>
    </g>
  );
}

/** Conifers along both shores, small and hazy: the edge of the water. */
function Shoreline({ p }: { p: Palette }) {
  const rand = seeded(2468);
  return (
    <g fill={p.conifer}>
      {Array.from({ length: 40 }, (_, i) => {
        const left = i < 20;
        const x = n(left ? -4 + i * 21.5 + rand() * 8 : 952 + (i - 20) * 24 + rand() * 9);
        const base = n(left ? 500 - (430 - x) * 0.014 : 476 + (x - 952) * 0.052);
        const h = n(12 + rand() * 22);
        const w = n(3.4 + rand() * 4);
        return (
          <path
            key={i}
            opacity={n(0.4 + rand() * 0.42)}
            d={`M${x},${base} L${x - w},${base} L${x},${base - h} L${x + w},${base} Z`}
          />
        );
      })}
    </g>
  );
}

/* ── The hillside ─────────────────────────────────────────────────────────
 *
 * Three slopes, high on the left and falling away right, so the lake stays
 * visible in the gap the reference leaves for it. Each one is planted along
 * its own top edge, which is what keeps the boundary between them from
 * reading as a stripe of colour.
 */

const SLOPES: Pt[][] = [
  [[-40, 104], [180, 62], [400, 118], [620, 176], [860, 236], [1120, 280], [1480, 282]],
  [[-40, 218], [200, 172], [460, 230], [720, 280], [980, 320], [1240, 338], [1480, 332]],
  [[-40, 322], [260, 288], [560, 326], [880, 350], [1160, 366], [1480, 368]],
];

function Hills({ time, p }: { time: Time; p: Palette }) {
  const id = (name: string) => `${name}-h-${time}`;
  const night = time === "night";
  return (
    <svg className="scene-hills" viewBox="0 0 1440 420" preserveAspectRatio="none">
      <defs>
        {p.hills.map((pair, i) => (
          <linearGradient key={i} id={id(`s${i}`)} x1="0" y1="0" x2="0.1" y2="1">
            <stop offset="0" stopColor={pair[0]} />
            <stop offset="1" stopColor={pair[1]} />
          </linearGradient>
        ))}
        <linearGradient id={id("wash")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor={p.sky[4]} stopOpacity="0" />
          <stop offset="1" stopColor={p.sky[4]} stopOpacity={night ? 0.3 : 0.62} />
        </linearGradient>
      </defs>

      {SLOPES.map((pts, i) => (
        <g key={i}>
          <path fill={`url(#${id(`s${i}`)})`} d={slope(pts, 420)} />
          {/* Grass on the skyline, so no two slopes meet on a clean curve. */}
          <path
            fill={p.hills[i][0]}
            opacity={0.9}
            d={fringe(pts, -20, 1460, i === 2 ? 10 : 8, i === 2 ? 15 : 9, seeded(700 + i))}
          />
          {/* Distance, poured back over the slope from the horizon. */}
          {i < 2 && (
            <path
              fill={`url(#${id("wash")})`}
              opacity={i === 0 ? 0.95 : 0.55}
              d={slope(pts, i === 0 ? 260 : 360)}
            />
          )}
          {i === 0 && <Conifers pts={pts} p={p} />}
          <Speckles pts={pts} p={p} band={i} />
        </g>
      ))}

    </svg>
  );
}

function Conifers({ pts, p }: { pts: Pt[]; p: Palette }) {
  const rand = seeded(5150);
  return (
    <g fill={p.hills[2][1]} opacity="0.55">
      {Array.from({ length: 26 }, (_, i) => {
        const x = n(40 + i * 54 + rand() * 30);
        const base = n(heightAt(pts, x) + 4);
        const h = n(16 + rand() * 26);
        const w = n(4 + rand() * 5);
        return <path key={i} d={`M${x},${base} L${x - w},${base} L${x},${base - h} L${x + w},${base} Z`} opacity={n(0.4 + rand() * 0.5)} />;
      })}
    </g>
  );
}

/** Flowers at a distance are dots of colour, and nothing else. */
function Speckles({ pts, p, band }: { pts: Pt[]; p: Palette; band: number }) {
  const rand = seeded(9001 + band * 31);
  const count = [24, 36, 54][band];
  const colours = [p.petalWarm, p.petalPink, p.petalPale, p.window, p.petalDeep];
  return (
    <g>
      {Array.from({ length: count }, (_, i) => {
        const x = rand() * 1480 - 20;
        const top = heightAt(pts, x);
        return (
          <circle
            key={i}
            cx={n(x)}
            cy={n(top + 6 + rand() * (band === 2 ? 74 : 56))}
            r={n((0.9 + rand() * 1.5) * (1 + band * 0.45))}
            fill={colours[Math.floor(rand() * colours.length)]}
            opacity={0.45 + rand() * 0.45}
          />
        );
      })}
    </g>
  );
}

function Stones({ p }: { p: Palette }) {
  const rand = seeded(8642);
  return (
    <g fill={p.stone[0]}>
      {Array.from({ length: 13 }, (_, i) => {
        const t = i / 12;
        const y = n(292 - t * 104);
        const x = n(606 + t * 88 + (rand() - 0.5) * 12);
        const w = n(40 - t * 26);
        return <ellipse key={i} cx={x} cy={y} rx={w} ry={n(w * 0.34)} opacity={n(0.3 + rand() * 0.38)} />;
      })}
    </g>
  );
}

/* ── The foreground band ──────────────────────────────────────────────────
 *
 * Everything close enough to move in the wind. Plants are grouped into a
 * dozen swaying clusters rather than animated one by one: a hundred
 * independently transformed nodes is a hundred repaints a frame, and at this
 * size nobody can tell the difference.
 */

const BANK: Pt[] = [[-40, 176], [200, 150], [440, 186], [700, 158], [960, 192], [1200, 164], [1480, 180]];

function Near({ time, p }: { time: Time; p: Palette }) {
  const id = (name: string) => `${name}-n-${time}`;
  const rand = seeded(19260817);

  // Behind: small, still, hazier. In front: fewer, bigger, and in the wind.
  const back = Array.from({ length: 26 }, () => {
    const x = rand() * 1500 - 30;
    return { x: n(x), y: n(heightAt(BANK, x) + 2 + rand() * 38), s: n(0.3 + rand() * 0.3), kind: rand() };
  });
  const clusters = Array.from({ length: 16 }, (_, i) => {
    const x = -24 + i * 96 + (rand() - 0.5) * 62;
    return {
      x: n(x),
      y: n(heightAt(BANK, x) + 12 + rand() * 62),
      s: n(0.74 + rand() * 0.62),
      dur: 6.4 + rand() * 4.2,
      delay: -rand() * 9,
      tilt: (1 + rand() * 1.6).toFixed(2),
      kind: rand(),
    };
  });

  return (
    <svg className="scene-near" viewBox="0 0 1440 300" preserveAspectRatio="xMidYMax slice">
      <defs>
        <linearGradient id={id("grass")} x1="0" y1="0" x2="0.06" y2="1">
          <stop offset="0" stopColor={p.grass[0]} />
          <stop offset="1" stopColor={p.grass[1]} />
        </linearGradient>
        <linearGradient id={id("stone")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={p.stone[1]} />
          <stop offset="1" stopColor={p.stone[0]} />
        </linearGradient>
        <filter id={id("dof")} x="-12%" y="-12%" width="124%" height="124%">
          <feGaussianBlur stdDeviation="1.9" />
        </filter>
        {/* 🔴 Every flower is drawn once here and stamped with `<use>`.
            Written out per instance instead, a nine-petal daisy is about a
            kilobyte of markup, and sixty tufts across two scenes turned the
            homepage into megabytes of HTML. Same picture, a fraction of the
            bytes and of the DOM. */}
        <Blooms p={p} time={time} />
      </defs>

      <path fill={`url(#${id("grass")})`} d={slope(BANK, 300)} />

      {/* The path, cutting through the meadow where the reference puts it.
          Drawn before the plants so they close over its edges. */}
      <path fill={`url(#${id("stone")})`} opacity="0.92" d="M566,300 C614,264 656,232 684,186 L766,186 C726,230 682,268 660,300 Z" />
      <Stones p={p} />
      <path fill={p.leafDeep} opacity="0.95" d={fringe(BANK, -30, 1470, 7, 18, seeded(4477))} />

      <g opacity="0.82">
        {back.map((b, i) => (
          <Tuft key={i} x={b.x} y={b.y} s={b.s} p={p} kind={b.kind} time={time} seed={200 + i} />
        ))}
      </g>

      {clusters.map((c, i) => (
        <g
          key={i}
          className="sway"
          style={{
            animationDuration: `${c.dur.toFixed(1)}s`,
            animationDelay: `${c.delay.toFixed(1)}s`,
            ["--tilt" as string]: `${c.tilt}deg`,
            transformOrigin: `${Math.round(c.x)}px ${Math.round(c.y + 62 * c.s)}px`,
          }}
        >
          <Tuft x={c.x} y={c.y} s={c.s} p={p} kind={c.kind} time={time} seed={1000 + i} />
        </g>
      ))}

      {/* Two clumps close enough to be out of focus, which is most of what
          sells depth in a flat picture. */}
      <g filter={`url(#${id("dof")})`}>
        <g className="sway" style={{ animationDuration: "9s", animationDelay: "-2s", ["--tilt" as string]: "1.3deg", transformOrigin: "206px 300px" }}>
          <Tuft x={196} y={236} s={2.1} p={p} kind={0.1} time={time} seed={51} />
        </g>
        <g className="sway" style={{ animationDuration: "10.5s", animationDelay: "-6s", ["--tilt" as string]: "1.1deg", transformOrigin: "1244px 300px" }}>
          <Tuft x={1246} y={242} s={2.2} p={p} kind={0.85} time={time} seed={52} />
        </g>
      </g>
    </svg>
  );
}

/** One decimal is as much precision as a flower needs. */
const n = (v: number) => Math.round(v * 10) / 10;

/* ── The five plants the meadow is made of ────────────────────────────────
 *
 * Each is drawn at unit scale with its head at the origin and its stem
 * running down to y=62, so a `<use>` only ever needs a translate and a
 * uniform scale.
 */
function Blooms({ p, time }: { p: Palette; time: Time }) {
  const tulipHead = (c: string) => (
    <>
      <path d="M0,64 Q3,28 0,6" stroke={p.leaf} strokeWidth="2.6" fill="none" />
      <path d="M0,54 q-18,-13 -14,-32 q12,7 14,32Z" fill={p.leafDeep} />
      <path
        fill={c}
        d="M0,6 c-7,0 -10,-4 -10,-10 c0,-8 2,-14 4,-18 c1,5 2,7 4,8 c1,-5 2,-9 2,-12 c0,3 1,7 2,12 c2,-1 3,-3 4,-8 c2,4 4,10 4,18 c0,6 -3,10 -10,10Z"
      />
      <path fill="#ffffff" opacity="0.22" d="M0,4 c-5,-4 -5,-16 1,-21 c5,6 4,17 -1,21Z" />
    </>
  );
  const budHead = (c: string) => (
    <>
      <path d="M0,62 Q-3,31 0,0" stroke={p.leafDeep} strokeWidth="1.8" fill="none" />
      {[0, 72, 144, 216, 288].map((a) => (
        <ellipse key={a} cx="0" cy="-4.6" rx="2.6" ry="4.8" fill={c} transform={`rotate(${a})`} />
      ))}
      <circle r="1.8" fill="#f7d98a" />
    </>
  );
  return (
    <>
      <g id={`daisy-${time}`}>
        <path d="M0,62 Q-2,24 0,0" stroke={p.leafDeep} strokeWidth="2.2" fill="none" />
        {[0, 40, 80, 120, 160, 200, 240, 280, 320].map((a) => (
          <ellipse key={a} cx="0" cy="-7.4" rx="3" ry="7.4" fill={p.petalWarm} transform={`rotate(${a})`} />
        ))}
        <circle r="3" fill="#f3c25c" />
      </g>
      <g id={`tulip-a-${time}`}>{tulipHead(p.petalDeep)}</g>
      <g id={`tulip-b-${time}`}>{tulipHead(p.petalPink)}</g>
      <g id={`bud-a-${time}`}>{budHead(p.petalDeep)}</g>
      <g id={`bud-b-${time}`}>{budHead(p.petalPink)}</g>
    </>
  );
}

/** A handful of plants that belong together: blades, a daisy or two, a tulip. */
function Tuft({ x, y, s, p, kind, time, seed }: { x: number; y: number; s: number; p: Palette; kind: number; time: Time; seed: number }) {
  const rand = seeded(seed * 7919);
  const base = y + 62 * s;
  const stamp = (name: string, dx: number, dy: number, ds: number) => (
    <use href={`#${name}-${time}`} transform={`translate(${n(x + dx * s)} ${n(y + dy * s)}) scale(${n(s * ds)})`} />
  );
  let blades = "";
  for (let i = 0; i < 6; i++) {
    const dx = (rand() - 0.5) * 84 * s;
    const h = (30 + rand() * 52) * s;
    const bend = (rand() - 0.5) * 28 * s;
    const r = Math.round;
    blades += `M${r(x + dx)},${r(base)}q${r(bend)},${r(-h * 0.6)} ${r(bend * 1.7)},${r(-h)}q${r(-bend * 0.35)},${r(h * 0.45)} ${r(-bend * 0.9 - 3.6 * s)},${r(h)}Z`;
  }
  return (
    <g>
      <path fill={p.leaf} d={blades} />
      {kind > 0.62 ? (
        <>
          {stamp("tulip-a", 0, 0, 1)}
          {stamp("tulip-b", 27, 13, 0.86)}
          {stamp("daisy", -27, 25, 0.8)}
        </>
      ) : kind > 0.3 ? (
        <>
          {stamp("daisy", -9, 7, 1)}
          {stamp("daisy", 31, 27, 0.82)}
          {stamp("tulip-b", 7, -13, 0.78)}
        </>
      ) : (
        <>
          {stamp("daisy", 5, 15, 0.9)}
          {stamp("bud-a", -25, 3, 1)}
          {stamp("bud-b", 30, 19, 0.8)}
        </>
      )}
    </g>
  );
}

/* ── Framing ──────────────────────────────────────────────────────────────
 *
 * Leaves hanging into the top corners in the morning; whole trees at night.
 * Both are blurred: they are inches from the lens, and a sharp leaf up there
 * pulls the eye straight off the headline.
 */
function Canopy({ p }: { p: Palette }) {
  return (
    <>
      <svg className="scene-canopy scene-canopy-left" viewBox="0 0 320 240" aria-hidden>
        <Branch p={p} seed={11} flip={false} />
      </svg>
      <svg className="scene-canopy scene-canopy-right" viewBox="0 0 320 240" aria-hidden>
        <Branch p={p} seed={23} flip />
      </svg>
    </>
  );
}

function Branch({ p, seed, flip }: { p: Palette; seed: number; flip: boolean }) {
  const rand = seeded(seed * 104729);
  return (
    <g transform={flip ? "translate(320 0) scale(-1 1)" : undefined}>
      <path d="M-12,-10 C64,20 124,58 164,118 C186,150 196,186 200,240" stroke={p.woodDark} strokeWidth="7" fill="none" opacity="0.85" />
      <path d="M40,6 C74,34 96,72 104,122" stroke={p.woodDark} strokeWidth="4" fill="none" opacity="0.7" />
      {Array.from({ length: 46 }, (_, i) => {
        const t = rand();
        const cx = n(-14 + t * 218 + (rand() - 0.5) * 86);
        const cy = n(t * t * 236 + (rand() - 0.5) * 74);
        const r = n(6 + rand() * 11);
        return (
          <ellipse
            key={i}
            cx={cx}
            cy={cy}
            rx={r}
            ry={n(r * 0.52)}
            fill={i % 3 === 0 ? p.leafDeep : p.leaf}
            opacity={n(0.72 + rand() * 0.28)}
            transform={`rotate(${Math.round(rand() * 180)} ${cx} ${cy})`}
          />
        );
      })}
    </g>
  );
}

function NightTrees({ p }: { p: Palette }) {
  return (
    <>
      <svg className="scene-tree scene-tree-left" viewBox="0 0 320 620" aria-hidden>
        <Trunk p={p} seed={7} flip={false} />
      </svg>
      <svg className="scene-tree scene-tree-right" viewBox="0 0 320 620" aria-hidden>
        <Trunk p={p} seed={19} flip />
      </svg>
    </>
  );
}

function Trunk({ p, seed, flip }: { p: Palette; seed: number; flip: boolean }) {
  const rand = seeded(seed * 65537);
  return (
    <g transform={flip ? "translate(320 0) scale(-1 1)" : undefined}>
      <path d="M52,620 C46,470 58,340 80,232 C92,168 96,104 92,0 L138,0 C142,110 132,182 122,244 C106,344 94,470 102,620Z" fill={p.woodDark} />
      <path d="M94,206 C130,184 174,168 234,156" stroke={p.woodDark} strokeWidth="9" fill="none" />
      <path d="M92,112 C140,96 196,88 272,86" stroke={p.woodDark} strokeWidth="7" fill="none" />
      {Array.from({ length: 56 }, (_, i) => {
        const cx = n(24 + rand() * 296);
        const cy = n(rand() * 268);
        const r = n(5 + rand() * 11);
        return (
          <ellipse
            key={i}
            cx={cx}
            cy={cy}
            rx={r}
            ry={n(r * 0.5)}
            fill={i % 4 === 0 ? p.leaf : p.leafDeep}
            opacity={n(0.8 + rand() * 0.2)}
            transform={`rotate(${Math.round(rand() * 180)} ${cx} ${cy})`}
          />
        );
      })}
      {/* Lights strung through the branches. Warm, few, and still. */}
      {Array.from({ length: 8 }, (_, i) => {
        const cx = n(48 + rand() * 244);
        const cy = n(36 + rand() * 216);
        return (
          <g key={i}>
            <circle cx={cx} cy={cy} r="16" fill="#ffca7d" opacity="0.15" />
            <circle cx={cx} cy={cy} r="7" fill="#ffca7d" opacity="0.3" />
            <circle cx={cx} cy={cy} r="2.6" fill="#fff3d8" />
          </g>
        );
      })}
    </g>
  );
}
