import { ImageResponse } from "next/og";

export function articleImage(title: string, subtitle: string) {
  return new ImageResponse(<div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", padding: 80, background: "#fdfbf8", color: "#302331", fontFamily: "sans-serif" }}><div style={{ display: "flex", fontSize: 24, letterSpacing: 3, color: "#883b59" }}>DAYFLOWER JOURNAL</div><div style={{ display: "flex", fontSize: 64, fontWeight: 700, lineHeight: 1.15, marginTop: 34 }}>{title}</div><div style={{ display: "flex", fontSize: 28, color: "#655863", marginTop: 30 }}>{subtitle}</div></div>, { width: 1200, height: 630 });
}
