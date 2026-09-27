import { ImageResponse } from "next/og";

export const alt = "Dayflower: free digital bouquets and photo keepsakes. A little something, just for them.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/**
 * The card for the homepage, inherited by every route that does not set its
 * own, which is why `/bouquet` and `/g/[id]` each override it. A gift is
 * meant to be a surprise, and a branded card above the message gives it away.
 */
export default function OpenGraphImage() {
  const tools = [
    ["Digital bouquets", "#883b59"],
    ["Photo keepsakes", "#655374"],
  ];
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", background: "#fdfbf8", padding: 78, color: "#302331", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", fontSize: 24, letterSpacing: 3, color: "#883b59" }}>DAYFLOWER</div>
      <div style={{ display: "flex", fontSize: 66, fontWeight: 700, lineHeight: 1.1, marginTop: 26 }}>A little something. Just for them.</div>
      <div style={{ display: "flex", fontSize: 30, color: "#655863", marginTop: 24, width: 940, lineHeight: 1.4 }}>
        Send a digital bouquet or turn your photos into a keepsake. Free to create and share. No account needed.
      </div>
      <div style={{ display: "flex", gap: 16, marginTop: 44 }}>
        {tools.map(([label, color]) => (
          <div key={label} style={{ display: "flex", alignItems: "center", padding: "14px 30px", borderRadius: 9, background: color, color: "#fffdf8", fontSize: 26, fontWeight: 700 }}>{label}</div>
        ))}
      </div>
    </div>,
    size,
  );
}
