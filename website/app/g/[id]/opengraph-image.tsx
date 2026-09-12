import { ImageResponse } from "next/og";
import { loadGift } from "../../lib/gift";
import { papers } from "../../bouquet/model";
import { bouquetColors } from "../../bouquet/model";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

const revealSources: Record<number, () => Promise<Buffer>> = {
  0: () => readFile(join(process.cwd(), "public/bouquet/reveal-envelope.png")),
  2: () => readFile(join(process.cwd(), "public/bouquet/reveal-letter.png")),
  3: () => readFile(join(process.cwd(), "public/bouquet/reveal-pigeon.png")),
  5: () => readFile(join(process.cwd(), "public/bouquet/reveal-box.png")),
};

export const alt = "A little something, just for you";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/**
 * The card a chat or mail client shows before anything is opened.
 *
 * ⚠️ **It shows the sealed vessel, never the flowers.** Spoiling the gift in
 * the notification defeats the point, and it is why the vessel is a separate
 * choice from the wrapping paper in the first place.
 *
 * Uses the same illustrated keepsakes as the editor. SVG fallbacks cover
 * the postcard and single stem, since ImageResponse has no canvas.
 */

const CREAM = "#fffdf8";

function Vessel({ vessel, ink }: { vessel: number; ink: string }) {
  const common = { stroke: ink, strokeWidth: 4, strokeLinejoin: "round" as const };
  switch (vessel) {
    case 1: // Postcard
      return <svg width="360" height="300" viewBox="0 0 360 300">
        <rect x="14" y="34" width="332" height="232" fill={CREAM} {...common} />
        <line x1="186" y1="58" x2="186" y2="242" stroke={ink} strokeWidth="3" opacity="0.4" />
        <rect x="256" y="58" width="62" height="74" fill="none" stroke={ink} strokeWidth="3" opacity="0.6" />
        <circle cx="214" cy="94" r="26" fill="none" stroke={ink} strokeWidth="3" opacity="0.35" />
        {[0, 1, 2].map(i => <line key={i} x1="210" y1={172 + i * 26} x2="322" y2={172 + i * 26} stroke={ink} strokeWidth="3" opacity="0.35" />)}
      </svg>;
    case 2: // Love letter
      return <svg width="300" height="330" viewBox="0 0 300 330">
        <rect x="46" y="16" width="208" height="298" fill={CREAM} {...common} />
        {[0, 1].map(i => <line key={i} x1="46" y1={115 + i * 99} x2="254" y2={115 + i * 99} stroke={ink} strokeWidth="3" opacity="0.4" />)}
        {[0, 1, 2, 3].map(i => <line key={i} x1="74" y1={52 + i * 22} x2={226 - (i % 3) * 34} y2={52 + i * 22} stroke={ink} strokeWidth="3" opacity="0.3" />)}
        <circle cx="150" cy="266" r="27" fill="#e8709f" />
      </svg>;
    case 3: // Carrier pigeon
      return <svg width="380" height="300" viewBox="0 0 380 300">
        <path d="M196 96 L338 52 L330 96 L340 126 L204 148 Z" fill={CREAM} {...common} />
        <ellipse cx="186" cy="130" rx="112" ry="70" fill={CREAM} {...common} />
        <ellipse cx="86" cy="82" rx="44" ry="38" fill={CREAM} {...common} />
        <path d="M150 106 C212 74, 268 100, 256 142 C212 168, 164 150, 150 106 Z" fill={ink} opacity="0.14" stroke={ink} strokeWidth="3" />
        <path d="M46 78 L4 92 L48 108 Z" fill="#e8922a" />
        <circle cx="74" cy="70" r="6" fill={ink} />
        <rect x="128" y="208" width="124" height="40" fill={CREAM} {...common} />
        <circle cx="190" cy="228" r="13" fill="#e8709f" />
      </svg>;
    case 5: // Gift box
      return <svg width="340" height="300" viewBox="0 0 340 300">
        <rect x="56" y="118" width="228" height="156" fill={CREAM} {...common} />
        <rect x="40" y="76" width="260" height="44" fill={CREAM} {...common} />
        <rect x="148" y="76" width="44" height="198" fill="#e8709f" />
        <circle cx="150" cy="62" r="26" fill="#e8709f" />
        <circle cx="192" cy="62" r="26" fill="#e8709f" />
      </svg>;
    case 4: // Single stem
      return <svg width="300" height="330" viewBox="0 0 300 330">
        <line x1="150" y1="150" x2="150" y2="300" stroke="#5f8a4e" strokeWidth="9" strokeLinecap="round" />
        <ellipse cx="108" cy="212" rx="38" ry="15" fill="#5f8a4e" transform="rotate(-22 108 212)" />
        <ellipse cx="192" cy="246" rx="38" ry="15" fill="#5f8a4e" transform="rotate(22 192 246)" />
        {[0, 1, 2, 3, 4].map(i => {
          const a = (i / 5) * Math.PI * 2 - Math.PI / 2;
          return <ellipse key={i} cx={150 + Math.cos(a) * 42} cy={112 + Math.sin(a) * 42} rx="32" ry="32" fill="#e8709f" />;
        })}
        <circle cx="150" cy="112" r="26" fill="#f3c34e" />
      </svg>;
    default: // Paper envelope
      return <svg width="380" height="280" viewBox="0 0 380 280">
        <rect x="18" y="26" width="344" height="232" fill={CREAM} {...common} />
        <path d="M18 258 L190 134 L362 258 Z" fill={ink} opacity="0.07" />
        <path d="M18 26 L362 26 L190 172 Z" fill={CREAM} {...common} />
        <circle cx="190" cy="166" r="30" fill="#e8709f" />
      </svg>;
  }
}

export default async function GiftOpenGraphImage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const bouquet = await loadGift(id);
  const paper = papers[bouquet?.paper ?? 0];
  const colors = bouquet ? bouquetColors(bouquet) : { color: paper.background, ink: paper.ink };
  const image = await revealSources[bouquet?.vessel ?? 0]?.().catch(() => null);
  const to = bouquet?.to.trim();

  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", background: colors.color, padding: "0 84px", fontFamily: "sans-serif", color: colors.ink }}>
      <div style={{ display: "flex", flexDirection: "column", width: 620 }}>
        <div style={{ fontSize: 24, letterSpacing: 3, opacity: 0.65, marginBottom: 26 }}>A LITTLE SOMETHING</div>
        <div style={{ fontSize: 70, fontWeight: 700, lineHeight: 1.1 }}>
          {to ? `${to}, I made this for you.` : "I made this for you."}
        </div>
        <div style={{ fontSize: 30, opacity: 0.7, marginTop: 28 }}>Open when you have a minute.</div>
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", transform: "rotate(-6deg)" }}>
        {image ?
          // ImageResponse consumes this inline image directly; next/image is for browser pages.
          // eslint-disable-next-line @next/next/no-img-element
          <img src={`data:image/png;base64,${image.toString("base64")}`} alt="" width={360} height={360} />
          : <Vessel vessel={bouquet?.vessel ?? 0} ink={colors.ink} />}
      </div>
    </div>,
    size,
  );
}
