import { PALETTE } from "./palette";

/**
 * The two objects the visitor is meant to notice: a sign at the top of the
 * path in the morning, a mailbox at the bottom of the garden at night.
 *
 * Both carry a line of writing, and both are `aria-hidden` scenery. The words
 * are part of the world rather than part of the page, so they are drawn as
 * SVG text in the site serif and never used to say anything the page needs
 * to say elsewhere.
 */

const p = PALETTE.dawn;

/** Posts, a crossbeam, a hanging board, and a lantern that is lit. */
export function SignPost() {
  return (
    <svg className="scene-sign" viewBox="0 0 320 440" aria-hidden>
      <defs>
        <linearGradient id="sign-wood" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#7d5c3c" />
          <stop offset="0.35" stopColor={p.wood[0]} />
          <stop offset="0.7" stopColor={p.wood[1]} />
          <stop offset="1" stopColor="#6a4e33" />
        </linearGradient>
        <linearGradient id="sign-board" x1="0.1" y1="0" x2="0.5" y2="1">
          <stop offset="0" stopColor="#c8a077" />
          <stop offset="0.55" stopColor="#b18d66" />
          <stop offset="1" stopColor="#9a7853" />
        </linearGradient>
        <radialGradient id="sign-lamp">
          <stop offset="0" stopColor="#ffe9b6" stopOpacity="0.9" />
          <stop offset="0.35" stopColor="#ffd28d" stopOpacity="0.34" />
          <stop offset="1" stopColor="#ffd28d" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Two posts standing in the grass, and the beam they carry. */}
      <rect x="34" y="52" width="32" height="388" rx="3" fill="url(#sign-wood)" />
      <rect x="252" y="66" width="26" height="374" rx="3" fill="url(#sign-wood)" opacity="0.92" />
      <path d="M14,44 h292 a6,6 0 0 1 6,6 v18 a6,6 0 0 1 -6,6 H14 a6,6 0 0 1 -6,-6 V50 a6,6 0 0 1 6,-6Z" fill="url(#sign-wood)" />
      <path d="M6,44 L160,20 L314,44 Z" fill="#7a5a3a" opacity="0.9" />
      <rect x="40" y="250" width="234" height="12" rx="3" fill="url(#sign-wood)" opacity="0.6" />

      {/* The lantern, hung off the right-hand end. */}
      <circle cx="286" cy="128" r="74" fill="url(#sign-lamp)" />
      <path d="M286,74 v14" stroke={p.woodDark} strokeWidth="3" />
      <path d="M272,88 h28 l7,11 h-42Z" fill={p.woodDark} />
      <rect x="272" y="99" width="28" height="38" rx="3" fill="#fff1d0" opacity="0.95" />
      <rect x="272" y="99" width="28" height="38" rx="3" fill="none" stroke={p.woodDark} strokeWidth="3.2" />
      <path d="M268,137 h36 l-6,9 h-24Z" fill={p.woodDark} />
      <circle cx="286" cy="119" r="7" fill="#ffdf9d" className="lantern" />

      {/* Board, hung on two chains. */}
      <path d="M86,74 L92,116 M234,74 L228,116" stroke="#5f4a33" strokeWidth="4" />
      <g className="sign-board">
        <rect x="62" y="112" width="196" height="216" rx="9" fill="url(#sign-board)" />
        <rect x="70" y="120" width="180" height="200" rx="6" fill="none" stroke="#8a6a49" strokeWidth="2.4" opacity="0.6" />
        {[164, 204, 244, 284].map((y, i) => (
          <text key={y} x="160" y={y} className="sign-text" textAnchor="middle" fill="#fdf3e2">
            {["Small", "Moments", "Brighter", "Days"][i]}
          </text>
        ))}
        <text x="160" y="313" className="sign-heart" textAnchor="middle" fill="#f6c9d6">
          &#9825;
        </text>
      </g>
    </svg>
  );
}

/** A mailbox with a letter still in it, and the morning's pigeon come home. */
export function Mailbox() {
  const n = PALETTE.night;
  return (
    <svg className="scene-mailbox" viewBox="0 0 260 340" aria-hidden>
      <defs>
        <linearGradient id="box-metal" x1="0" y1="0" x2="1" y2="0.2">
          <stop offset="0" stopColor="#6f5c4a" />
          <stop offset="0.5" stopColor="#8b7461" />
          <stop offset="1" stopColor="#5b4b3c" />
        </linearGradient>
        <radialGradient id="box-lamp">
          <stop offset="0" stopColor="#ffd28c" stopOpacity="0.5" />
          <stop offset="1" stopColor="#ffd28c" stopOpacity="0" />
        </radialGradient>
      </defs>

      <circle cx="120" cy="150" r="118" fill="url(#box-lamp)" />

      {/* Post. */}
      <rect x="104" y="186" width="26" height="154" fill={n.wood[1]} />
      <rect x="92" y="186" width="50" height="12" rx="3" fill={n.wood[0]} opacity="0.7" />

      {/* Body: a rounded tunnel, open toward us. */}
      <path d="M40,96 a56,56 0 0 1 112,0 v82 h-112Z" fill="url(#box-metal)" />
      <path d="M40,96 a56,56 0 0 1 112,0" fill="none" stroke="#3f342a" strokeWidth="3" opacity="0.6" />
      <rect x="40" y="170" width="112" height="10" rx="3" fill="#4b3f33" />
      {/* The open door, and the letter that has not been taken in yet. */}
      <path d="M152,96 a48,48 0 0 1 4,22 v58 l30,10 v-74Z" fill="#5d4d3e" />
      <path d="M44,110 v-44 h4 v44Z" fill="#4a3d31" />
      <path d="M48,66 h26 v18 h-26Z" fill="#d1567f" />
      <g transform="rotate(-9 150 128)">
        <rect x="128" y="104" width="62" height="44" rx="3" fill="#fdf6e6" />
        <path d="M128,104 L159,128 L190,104" fill="none" stroke="#e2d6c0" strokeWidth="2.4" />
        <path d="M156,124 a5,5 0 0 1 9,-3 a5,5 0 0 1 9,3 c0,6 -9,11 -9,11 s-9,-5 -9,-11Z" fill={n.heart} />
      </g>
      {/* A little enamel heart on the side, the only decoration it gets. */}
      <rect x="58" y="112" width="58" height="52" rx="5" fill="#ece5d5" opacity="0.94" />
      <path d="M78,138 a8,8 0 0 1 14,-5 a8,8 0 0 1 14,5 c0,10 -14,18 -14,18 s-14,-8 -14,-18Z" fill={n.heart} opacity="0.85" transform="translate(-4 -4) scale(0.92) translate(8 12)" />

      <Dove />
    </svg>
  );
}

/** The pigeon, perched. Same bird as the morning, with the letter delivered. */
function Dove() {
  return (
    <g className="dove" transform="translate(30 2)">
      {/* Tail first, so the body sits over it. */}
      <path d="M22,62 l-22,10 l24,4Z" fill="#dedacd" />
      <ellipse cx="62" cy="56" rx="34" ry="18" fill="#f1eee4" transform="rotate(-7 62 56)" />
      {/* Folded wing. */}
      <path d="M40,48 c16,-9 40,-10 54,-2 c-13,9 -40,11 -54,2Z" fill="#dfdbcd" />
      <path d="M84,42 c8,-11 12,-20 10,-26 c-5,3 -12,12 -18,22Z" fill="#f1eee4" />
      {/* Neck into a small head: the whole difference between a pigeon and
          a duck is the head being this much smaller than you expect. */}
      <path d="M84,44 c2,-10 6,-16 12,-19 l6,12Z" fill="#f4f1e8" />
      <circle cx="100" cy="27" r="10.5" fill="#f6f3ea" />
      <path d="M109,25 l11,3 l-11,4Z" fill="#dda268" />
      <circle cx="104" cy="24" r="1.9" fill="#332f28" />
      <path d="M58,72 l-1,10 M72,72 l1,10" stroke="#d09a63" strokeWidth="2.6" strokeLinecap="round" />
    </g>
  );
}
