# Bouquet artwork

The September 13 stationery update adds `wrapper-special.webp` (four back/front pairs: kraft, blue toile, blush mesh, and vintage print) and `reveal-envelope.webp`, `reveal-letter.webp`, `reveal-pigeon.webp`, `reveal-box.webp`. These are original OpenAI-generated watercolor assets. The reveal images were cropped from one generated sheet and normalized to transparent 512px squares. Existing flower and paper indexes remain stable for previously sent gifts.

Original artwork generated for Dayflower, not extracted from any reference site.
`botanical-sprites.webp` was made on 2026-09-12; the rest were supplied on
2026-09-12 and converted from PNG to WebP (quality 82, alpha preserved).

| File | Size | Grid | Cell | Contents |
|---|---|---|---|---|
| `botanical-sprites.webp` | 1536 × 1024 | 4 × 2 | 384 × 512 | tulip, rose, daisy, sunflower / lavender, peony, ivory wrapping, lavender wrapping |
| `wrapper-layers.webp` | 1536 × 1024 | 4 × 2 | 384 × 512 | ivory back, ivory front / lilac back, lilac front / black back, black front / pink back, pink front |
| `flowers-a.webp` | 1254 × 1254 | 4 × 3 | 313.5 × 418 | catalogue indexes 6–17 |
| `flowers-b.webp` | 1254 × 1254 | 4 × 3 | 313.5 × 418 | indexes 18–29 |
| `flowers-c.webp` | 1254 × 1254 | 4 × 3 | 313.5 × 418 | indexes 30–41 |
| `flowers-d.webp` | 1254 × 1254 | 4 × 3 | 313.5 × 418 | indexes 42–53 |

**The wrapper is two layers per colour, in back/front pairs.** `renderBouquet`
draws the back half, then the photos and stems, then the front half over them,
which is what puts the flowers *inside* the paper rather than behind it. The
pairs are indexed `wrapIndex + 0` and `+ 1`, so a colour must stay on an even
cell — do not insert a single cell anywhere in this sheet.

⚠️ **Keep the ordering and dimensions stable.** Gift links store the flower
index, so reordering a cell silently rewrites every bouquet already sent.
Sheets are all-or-nothing: `flowerSprite` maps index → sheet by arithmetic.
