import { createHmac } from "node:crypto";
import { isIP } from "node:net";
import { InputError } from "./request";

export type Action = "gift-create" | "waitlist" | "gift-email" | "gift-read";

export function privateHash(value: string) {
  // The server-only key is a secure fallback, never a public constant.
  const secret = process.env.RATE_LIMIT_SALT || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!secret) throw new Error("Rate limiter is not configured.");
  return createHmac("sha256", secret).update(value).digest("hex");
}

export function senderKey(request: Request) {
  // Vercel overwrites X-Forwarded-For. Never trust forwarded headers on an
  // arbitrary self-hosted server; share a conservative fallback bucket there.
  const ip = process.env.VERCEL === "1" ? request.headers.get("x-forwarded-for")?.split(",")[0].trim() : undefined;
  return privateHash(`sender:${ip && isIP(ip) ? ip : "unknown"}`);
}

export async function rateLimit(request: Request, action: Action, recipient?: string, id?: string) {
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Rate limiter is not configured.");
  const response = await fetch(`${url}/rest/v1/rpc/claim_website_request`, {
    method: "POST", cache: "no-store",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_action: action, p_sender: senderKey(request), p_recipient: recipient ? privateHash(`recipient:${recipient}`) : null, p_gift: id ?? null }),
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error("Rate limiter unavailable.");
  const granted: unknown = await response.json();
  if (granted === false) throw new InputError("Too many requests. Please try again in an hour.", 429);
  if (granted !== true) throw new Error("Invalid rate limiter response.");
}
