import { NextResponse } from "next/server";
import { htmlFor, subjectFor, textFor } from "../../../../emails/bouquet-gift";
import { loadGift } from "../../../lib/gift";

// Deliberately loose, like the waitlist's: real addresses are stranger than
// most regexes allow, so this only rejects the obviously-not-an-email.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;
const SITE = "https://mydayflower.com";

function fail(error: string, status: number) {
  return NextResponse.json({ error }, { status });
}

/**
 * A salted, one-way identifier for the sender. The raw IP is never stored,
 * and without the salt the hash cannot be walked back through the (small)
 * space of IPv4 addresses.
 */
async function senderHash(request: Request) {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0].trim()
    ?? request.headers.get("x-real-ip") ?? "unknown";
  const salt = process.env.RATE_LIMIT_SALT ?? "dayflower-gift";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${salt}:${ip}`));
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

/** Both ceilings live in Postgres so two racing requests cannot both pass. */
async function claim(giftId: string, hash: string) {
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) return false;
  try {
    const res = await fetch(`${url}/rest/v1/rpc/claim_gift_email`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_gift_id: giftId, p_sender_hash: hash }),
      signal: AbortSignal.timeout(8000),
    });
    return res.ok && (await res.json()) === true;
  } catch {
    return false;
  }
}

export async function POST(request: Request) {
  let body: { id?: unknown; email?: unknown };
  try {
    body = await request.json();
  } catch {
    return fail("Invalid request.", 400);
  }

  const id = typeof body.id === "string" ? body.id : "";
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!EMAIL_RE.test(email) || email.length > MAX_EMAIL_LENGTH) {
    return fail("Please enter a valid email address.", 400);
  }

  // The gift is loaded rather than trusted from the request, so the email can
  // only ever describe something that actually exists and has not expired.
  const bouquet = await loadGift(id);
  if (!bouquet) return fail("This gift link has expired. Make a new link and try again.", 404);

  if (!(await claim(id, await senderHash(request)))) {
    return fail("That’s a few too many for now. Try again in a little while.", 429);
  }

  const resendKey = process.env.RESEND_API_KEY;
  const from = process.env.BOUQUET_EMAIL_FROM ?? process.env.WAITLIST_EMAIL_FROM;
  if (!resendKey || !from) {
    console.error("Gift email: RESEND_API_KEY / sender address are not set.");
    return fail("Sending by email isn’t available right now. Copy the link instead.", 503);
  }

  const content = {
    url: `${SITE}/g/${id}`,
    imageUrl: `${SITE}/g/${id}/opengraph-image`,
    to: bouquet.to,
    from: bouquet.from,
    note: bouquet.message,
  };

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
        // One gift to one address is one email, however many times a nervous
        // thumb hits send.
        "Idempotency-Key": `bouquet-gift-v1/${id}/${email}`,
      },
      body: JSON.stringify({
        from,
        to: [email],
        subject: subjectFor({ from: bouquet.from }),
        html: htmlFor(content),
        text: textFor(content),
        ...(process.env.WAITLIST_EMAIL_REPLY_TO ? { reply_to: process.env.WAITLIST_EMAIL_REPLY_TO } : {}),
      }),
      signal: AbortSignal.timeout(12_000),
    });
    if (!res.ok) {
      // Never log the address or the provider's body.
      console.error("Gift email: provider rejected the send.", res.status);
      return fail("That didn’t go through. Try again, or copy the link instead.", 502);
    }
    return NextResponse.json({ ok: true });
  } catch {
    console.error("Gift email: provider unreachable.");
    return fail("That didn’t go through. Try again, or copy the link instead.", 502);
  }
}
