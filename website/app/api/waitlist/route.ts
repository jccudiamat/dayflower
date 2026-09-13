import { sendConfirmation } from "../../../emails/send-confirmation";
import { subject, html, text } from "../../../emails/waitlist-confirmation";
import { emailAddress, onlyKeys } from "../../lib/input";
import { checkRequest, failure, InputError, readJson } from "../../lib/request";
import { rateLimit } from "../../lib/rate-limit";

export async function POST(request: Request) {
  try {
    checkRequest(request);
    const body = await readJson(request, 2048);
    const normalized = emailAddress(body.email);
    if (!onlyKeys(body, ["email"]) || !normalized) throw new InputError("Please enter a valid email address.");
    await rateLimit(request, "waitlist", normalized);
    const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) throw new Error("Waitlist unavailable.");
    const res = await fetch(`${url}/rest/v1/waitlist`, {
      method: "POST", cache: "no-store",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ email: normalized, source: "landing" }), signal: AbortSignal.timeout(8000),
    });
    const error = !res.ok ? await res.json().catch(() => null) : null;
    if (!res.ok && !(res.status === 409 && error?.code === "23505")) throw new Error("Waitlist unavailable.");
    const confirmation = await sendConfirmation(normalized, { subject, html, text }, {
      supabaseUrl: url, serviceKey: key, resendKey: process.env.RESEND_API_KEY,
      from: process.env.WAITLIST_EMAIL_FROM, replyTo: process.env.WAITLIST_EMAIL_REPLY_TO,
    });
    return Response.json({ ok: true, confirmation }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) { return failure(error); }
}
