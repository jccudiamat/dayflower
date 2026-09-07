import { ImageResponse } from "next/og";

export const alt = "Dayflower free online photo booth — solo and couple photo strips";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", background: "#100a1e", padding: 70, color: "#f5f2f8", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", flexDirection: "column", width: 690 }}>
        <div style={{ fontSize: 24, color: "#f0709f", marginBottom: 30 }}>DAYFLOWER PHOTO BOOTH</div>
        <div style={{ fontSize: 66, fontWeight: 700, lineHeight: 1.1 }}>Little moments. Yours to keep.</div>
        <div style={{ fontSize: 26, color: "#c9bed6", marginTop: 30 }}>Free solo & couple photo strips. No login.</div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 14, width: 250, padding: 20, background: "#fcedf4", transform: "rotate(7deg)" }}>
        {["#d5568f", "#906fe8", "#733952"].map((color, i) => <div key={color} style={{ display: "flex", alignItems: "center", justifyContent: "center", height: 122, background: color, fontSize: 50, color: "white" }}>{["1", "2", "3"][i]}</div>)}
        <div style={{ display: "flex", justifyContent: "center", color: "#733952", fontSize: 18 }}>made with Dayflower</div>
      </div>
    </div>, size,
  );
}
