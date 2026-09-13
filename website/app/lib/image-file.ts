export const MAX_IMAGE_PIXELS = 24_000_000;

/** Inspect image headers before decoding; MIME labels alone are untrusted. */
export function rasterInfo(bytes: Uint8Array): { format: "png" | "jpeg" | "webp"; width: number; height: number } {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const ascii = (start: number, length: number) => String.fromCharCode(...bytes.subarray(start, start + length));
  let width = 0, height = 0;
  let format: "png" | "jpeg" | "webp";
  if (bytes.length >= 33 && bytes[0] === 137 && ascii(1, 7) === "PNG\r\n\x1a\n" && ascii(12, 4) === "IHDR") {
    format = "png"; width = view.getUint32(16); height = view.getUint32(20);
    for (let offset = 8; offset + 12 <= bytes.length;) {
      const length = view.getUint32(offset);
      if (length > bytes.length - offset - 12) throw new Error("This PNG is incomplete.");
      if (ascii(offset + 4, 4) === "acTL") throw new Error("Choose a still photo, not an animation.");
      offset += length + 12;
    }
  } else if (bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216) {
    format = "jpeg";
    for (let offset = 2; offset + 3 < bytes.length;) {
      if (bytes[offset++] !== 255) throw new Error("This JPG could not be read.");
      while (bytes[offset] === 255) offset++;
      const marker = bytes[offset++];
      if (marker === 217 || marker === 218) break;
      if (marker === 1 || marker >= 208 && marker <= 215) continue;
      if (offset + 2 > bytes.length) break;
      const length = view.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) throw new Error("This JPG is incomplete.");
      if ([192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207].includes(marker)) {
        if (length < 8) break;
        height = view.getUint16(offset + 3); width = view.getUint16(offset + 5); break;
      }
      offset += length;
    }
  } else if (bytes.length >= 30 && ascii(0, 4) === "RIFF" && ascii(8, 4) === "WEBP") {
    format = "webp";
    if (view.getUint32(4, true) + 8 > bytes.length) throw new Error("This WebP is incomplete.");
    const kind = ascii(12, 4);
    if (kind === "VP8X") {
      if (bytes[20] & 2) throw new Error("Choose a still photo, not an animation.");
      width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
      height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
    } else if (kind === "VP8 " && bytes[23] === 157 && bytes[24] === 1 && bytes[25] === 42) {
      width = view.getUint16(26, true) & 16383; height = view.getUint16(28, true) & 16383;
    } else if (kind === "VP8L" && bytes[20] === 47) {
      const dimensions = view.getUint32(21, true);
      width = (dimensions & 16383) + 1; height = ((dimensions >>> 14) & 16383) + 1;
    }
  } else throw new Error("Choose a valid JPG, PNG, or WebP photo.");
  if (!width || !height || width > 12000 || height > 12000 || width * height > MAX_IMAGE_PIXELS) throw new Error("Choose a photo up to 24 megapixels and 12,000 pixels per side.");
  return { format, width, height };
}

export async function checkImageFile(file: File, maxBytes: number) {
  if (!/^image\/(jpeg|png|webp)$/.test(file.type) || file.size === 0 || file.size > maxBytes) throw new Error(`Choose a JPG, PNG, or WebP photo smaller than ${Math.round(maxBytes / 1024 / 1024)} MB.`);
  const info = rasterInfo(new Uint8Array(await file.arrayBuffer()));
  if (file.type !== `image/${info.format}`) throw new Error("The photo contents do not match its file type.");
  return info;
}
