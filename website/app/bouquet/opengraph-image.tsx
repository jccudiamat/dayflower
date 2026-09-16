import { ImageResponse } from "next/og";

export const alt = "A little something, just for you";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/**
 * 🔴 **This override exists to keep a secret, not to market anything.**
 *
 * A private bouquet link is this very page plus a URL fragment
 * (`/bouquet#…`), so whatever card `/bouquet` produces is the card that
 * lands in the recipient's chat — above the sender's own message, before
 * they have opened anything. Without this file the segment would inherit the
 * homepage card, which names the flowers and the brand and spoils the gift.
 *
 * Kept wordless and matched to `/g/[id]`: a sealed envelope, nothing else.
 */
export default function BouquetOpenGraphImage() {
  const ink = "#733952";
  const cream = "#fffdf8";
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "center", background: "#fcedf4", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", transform: "rotate(-6deg)" }}>
        <svg width="620" height="460" viewBox="0 0 380 280">
          <rect x="18" y="26" width="344" height="232" fill={cream} stroke={ink} strokeWidth="4" strokeLinejoin="round" />
          <path d="M18 258 L190 134 L362 258 Z" fill={ink} opacity="0.07" />
          <path d="M18 26 L362 26 L190 172 Z" fill={cream} stroke={ink} strokeWidth="4" strokeLinejoin="round" />
          <circle cx="190" cy="166" r="30" fill="#e8709f" />
        </svg>
      </div>
    </div>,
    size,
  );
}
