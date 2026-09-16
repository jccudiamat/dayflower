import { ImageResponse } from "next/og";

export const alt = "Dayflower — free digital bouquets, a photo booth, and gift ideas for the people you love";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/**
 * The card for the homepage, inherited by every route that does not set its
 * own — which is why `/bouquet` and `/g/[id]` each override it. A gift is
 * meant to be a surprise, and a branded card above the message gives it away.
 */
export default function OpenGraphImage() {
  const tools = [
    ["Bouquet", "#f0709f"],
    ["Photo booth", "#906fe8"],
    ["Gifts", "#d5568f"],
  ];
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", background: "linear-gradient(160deg, #171027, #221838 55%, #120c1f)", padding: 78, color: "#f5f2f8", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", fontSize: 24, letterSpacing: 3, color: "#f0709f" }}>DAYFLOWER</div>
      <div style={{ display: "flex", fontSize: 72, fontWeight: 700, lineHeight: 1.1, marginTop: 26 }}>Make their day.</div>
      <div style={{ display: "flex", fontSize: 30, color: "#c9bed6", marginTop: 24, width: 860, lineHeight: 1.4 }}>
        Send a digital bouquet, make a photo keepsake, or find a thoughtful gift. Free, and no account needed.
      </div>
      <div style={{ display: "flex", gap: 16, marginTop: 44 }}>
        {tools.map(([label, color]) => (
          <div key={label} style={{ display: "flex", alignItems: "center", padding: "14px 30px", borderRadius: 999, background: color, color: "#fffdf8", fontSize: 26, fontWeight: 700 }}>{label}</div>
        ))}
      </div>
    </div>,
    size,
  );
}
