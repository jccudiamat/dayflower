import { NextResponse } from "next/server";
import { validateBouquet } from "../../bouquet/model";
import { MAX_GIFT_BYTES, saveGift } from "../../lib/gift";

function fail(error: string, status: number) {
  return NextResponse.json({ error }, { status });
}

export async function POST(request: Request) {
  // Size is checked before parsing, so an oversized body is refused rather
  // than deserialised into memory first.
  const declared = Number(request.headers.get("content-length") ?? 0);
  if (declared > MAX_GIFT_BYTES) return fail("This bouquet is too large to share as a link.", 413);

  let body: unknown;
  try {
    const text = await request.text();
    if (text.length > MAX_GIFT_BYTES) return fail("This bouquet is too large to share as a link.", 413);
    body = JSON.parse(text);
  } catch {
    return fail("Invalid request.", 400);
  }

  // The same gate a pasted link goes through. Anything the editor could not
  // have produced is refused here rather than stored and rendered later.
  const bouquet = validateBouquet((body as { bouquet?: unknown } | null)?.bouquet);
  if (!bouquet) return fail("This bouquet could not be read.", 400);
  if (!bouquet.stems.length && !(bouquet.photos?.length)) return fail("Add at least one flower or photo before sharing.", 400);

  const id = await saveGift(bouquet);
  if (!id) return fail("Gift links aren’t available right now. Please try again later.", 503);
  return NextResponse.json({ id });
}
