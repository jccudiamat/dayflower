import { MAX_PHOTO_LENGTH, type Photo } from "./model";

export async function readPhoto(file: File): Promise<string> {
  if (!/^image\/(jpeg|png|webp)$/.test(file.type)) throw new Error("Choose a JPG, PNG, or WebP image. Export HEIC photos as JPG first.");
  if (file.size > 15 * 1024 * 1024) throw new Error("Choose an image smaller than 15 MB.");
  const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  try {
    if (!bitmap.width || !bitmap.height) throw new Error("This image could not be opened.");
    const canvas = document.createElement("canvas");
    const ratio = Math.min(1, 640 / Math.max(bitmap.width, bitmap.height));
    canvas.width = Math.max(1, Math.round(bitmap.width * ratio)); canvas.height = Math.max(1, Math.round(bitmap.height * ratio));
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Your browser could not open the photo editor.");
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    // Re-encoding removes the original file's metadata, while WebP keeps PNG transparency.
    for (const quality of [.86, .72, .55, .38]) {
      const src = canvas.toDataURL("image/webp", quality);
      if (src.length <= MAX_PHOTO_LENGTH) return src;
    }
    throw new Error("This photo is too detailed to share. Try a smaller image.");
  } finally { bitmap.close(); }
}

export function newPhoto(src: string, id: number, slot: number, frame = 0): Photo {
  const positions = [[240, 300, -13], [470, 310, 12], [355, 260, 2], [300, 435, -6], [470, 440, 14], [165, 410, -18], [540, 350, 18], [375, 395, 5]];
  const [x, y, angle] = positions[slot % positions.length];
  return { id, src, frame, x, y, angle, scale: .83, zoom: 1, cropX: 50, cropY: 50, caption: "", layer: "front" };
}

export function removeEdgeBackground(data: Uint8ClampedArray, width: number, height: number, tolerance = 46) {
  const visited = new Uint8Array(width * height), queue = new Int32Array(width * height);
  const corners = [0, width - 1, (height - 1) * width, width * height - 1].map(i => [data[i * 4], data[i * 4 + 1], data[i * 4 + 2]]);
  let head = 0, tail = 0;
  function enqueue(i: number) {
    if (visited[i]) return;
    visited[i] = 1;
    const p = i * 4;
    if (data[p + 3] < 10 || corners.some(c => Math.hypot(data[p] - c[0], data[p + 1] - c[1], data[p + 2] - c[2]) < tolerance)) queue[tail++] = i;
  }
  for (let x = 0; x < width; x++) { enqueue(x); enqueue((height - 1) * width + x); }
  for (let y = 0; y < height; y++) { enqueue(y * width); enqueue(y * width + width - 1); }
  while (head < tail) {
    const i = queue[head++]; data[i * 4 + 3] = 0;
    if (i % width > 0) enqueue(i - 1);
    if (i % width < width - 1) enqueue(i + 1);
    if (i >= width) enqueue(i - width);
    if (i < width * (height - 1)) enqueue(i + width);
  }
  return data;
}

export async function makeCutout(src: string): Promise<string> {
  const image = new Image(); image.src = src; await image.decode();
  const canvas = document.createElement("canvas"); canvas.width = image.naturalWidth; canvas.height = image.naturalHeight;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("This browser could not make a cutout.");
  ctx.drawImage(image, 0, 0);
  const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
  removeEdgeBackground(pixels.data, canvas.width, canvas.height); ctx.putImageData(pixels, 0, 0);
  const output = canvas.toDataURL("image/webp", .8);
  if (output.length > MAX_PHOTO_LENGTH) throw new Error("The cutout is too large. Try a smaller photo.");
  return output;
}
