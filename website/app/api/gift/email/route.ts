import { htmlFor, subjectFor, textFor } from "../../../../emails/bouquet-gift";
import { loadGift } from "../../../lib/gift";
import { emailAddress, giftId, onlyKeys } from "../../../lib/input";
import { checkRequest, failure, InputError, readJson } from "../../../lib/request";
import { rateLimit } from "../../../lib/rate-limit";

import { verifyDelivery } from "../../../lib/turnstile";

const SITE = "https://mydayflower.com";

export async function POST(request: Request) {
  try {
    checkRequest(request);
    const body = await readJson(request, 4096);
    const email = emailAddress(body.email);
    if (!onlyKeys(body, ["id", "email", "token"]) || !giftId(body.id) || !email) throw new InputError("Please check the gift link and email address.");
    const id = body.id;
    await rateLimit(request, "gift-email", email, id);
    await verifyDelivery(body.token);
    const bouquet = await loadGift(id);
    if (!bouquet) throw new InputError("This gift link has expired. Make a new link and try again.", 404);
    const resendKey = process.env.RESEND_API_KEY;
    const from = process.env.BOUQUET_EMAIL_FROM ?? process.env.WAITLIST_EMAIL_FROM;
    if (!resendKey || !from) throw new Error("Email unavailable.");
    const content = { url: `${SITE}/g/${id}`, imageUrl: `${SITE}/g/${id}/opengraph-image`, to: bouquet.to, from: bouquet.from };
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json", "Idempotency-Key": `bouquet-gift-v1/${id}/${email}` },
      body: JSON.stringify({ from, to: [email], subject: subjectFor({ from: bouquet.from }), html: htmlFor(content), text: textFor(content),
        ...(process.env.WAITLIST_EMAIL_REPLY_TO ? { reply_to: process.env.WAITLIST_EMAIL_REPLY_TO } : {}) }),
      signal: AbortSignal.timeout(12000),
    });
    if (!res.ok) throw new Error("Email unavailable.");
    return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) { return failure(error); }
}
