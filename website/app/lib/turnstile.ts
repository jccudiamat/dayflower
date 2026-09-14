import { InputError } from "./request";

/** Every email consumes one token. Never trust a browser's verified flag. */
export async function verifyDelivery(token: unknown) {
  if (typeof token !== "string" || !token.length || token.length > 2048 || /\s/.test(token)) {
    throw new InputError("Complete the security check before sending.", 403);
  }
  const secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) throw new InputError("Security verification is unavailable. Please try again later.", 503);
  let result: { success?: boolean; hostname?: string; action?: string };
  try {
    const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST", cache: "no-store",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ secret, response: token }),
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error("Verification unavailable");
    result = await response.json();
  } catch {
    throw new InputError("Security verification is unavailable. Please try again.", 503);
  }
  const hosts = new Set(["mydayflower.com", "www.mydayflower.com"]);
  if (process.env.NODE_ENV !== "production") { hosts.add("localhost"); hosts.add("127.0.0.1"); }
  if (!result || result.success !== true || !hosts.has(result.hostname ?? "") || result.action !== "gift-email") {
    throw new InputError("The security check expired or failed. Please verify again.", 403);
  }
}
