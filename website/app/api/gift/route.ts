import { validateBouquet, hasContents } from "../../bouquet/model";
import { MAX_GIFT_BYTES, saveGift } from "../../lib/gift";
import { normalizeGiftPhotos } from "../../lib/gift-photos";
import { onlyKeys } from "../../lib/input";
import { checkRequest, failure, InputError, readJson } from "../../lib/request";
import { rateLimit } from "../../lib/rate-limit";

export const maxDuration = 30;

export async function POST(request: Request) {
  try {
    checkRequest(request);
    await rateLimit(request, "gift-create");
    const body = await readJson(request, MAX_GIFT_BYTES);
    if (!onlyKeys(body, ["bouquet"])) throw new InputError("Unexpected request fields.");
    const bouquet = validateBouquet(body.bouquet, true);
    if (!bouquet || !hasContents(bouquet)) throw new InputError("Check your bouquet, photos, and note before sharing.");
    const clean = await normalizeGiftPhotos(bouquet);
    const id = await saveGift(clean);
    if (!id) throw new Error("Storage unavailable.");
    return Response.json({ id }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) { return failure(error); }
}
