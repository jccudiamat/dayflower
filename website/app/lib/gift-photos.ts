import sharp from "sharp";
import { MAX_PHOTO_LENGTH, type Bouquet } from "../bouquet/model";
import { rasterInfo } from "./image-file";
import { InputError } from "./request";

/** Decode/re-encode uploads server-side, sequentially, with strict resource limits. */
export async function normalizeGiftPhotos(bouquet: Bouquet): Promise<Bouquet> {
  if (!bouquet.photos?.length) return bouquet;
  const photos = [];
  for (const photo of bouquet.photos) {
    try {
      const bytes = Buffer.from(photo.src.slice(photo.src.indexOf(",") + 1), "base64");
      const info = rasterInfo(bytes);
      // The editor exports <=640px. Allow older photos some headroom, but
      // never decode an original high-resolution upload on the gift server.
      if (info.width > 2048 || info.height > 2048 || info.width * info.height > 4_000_000 || !photo.src.startsWith(`data:image/${info.format};base64,`)) throw new Error("Invalid image size or type.");
      const output = await sharp(bytes, { limitInputPixels: 4_000_000, failOn: "warning" }).timeout({ seconds: 3 })
        .rotate().resize({ width: 640, height: 640, fit: "inside", withoutEnlargement: true }).webp({ quality: 80, effort: 2 }).toBuffer();
      const src = `data:image/webp;base64,${output.toString("base64")}`;
      if (src.length > MAX_PHOTO_LENGTH) throw new Error("Image too large.");
      photos.push({ ...photo, src });
    } catch { throw new InputError("A photo could not be read safely. Please remove it and upload a smaller JPG, PNG, or WebP."); }
  }
  return { ...bouquet, photos };
}
