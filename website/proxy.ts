import { NextRequest, NextResponse } from "next/server";
import { isIP } from "node:net";
import { rateLimit } from "./app/lib/rate-limit";
import { failure } from "./app/lib/request";
import { giftId } from "./app/lib/input";

// A bounded, per-instance burst guard stops repeat traffic before body reads
// or database calls. Persistent limits in Postgres remain authoritative.
const bursts = new Map<string, { count: number; until: number }>();
let sweepAt = 0;
let total = { count: 0, until: 0 };
function burstAllowed(request: NextRequest) {
  const now = Date.now();
  if (now >= total.until) total = { count: 0, until: now + 60_000 };
  if (++total.count > 600) return false;
  if (now > sweepAt) { for (const [key, value] of bursts) if (value.until <= now) bursts.delete(key); sweepAt = now + 10_000; }
  const candidate = process.env.VERCEL === "1" ? request.headers.get("x-forwarded-for")?.split(",")[0].trim() : undefined;
  const key = candidate && isIP(candidate) ? candidate : "unknown";
  let bucket = bursts.get(key);
  if (!bucket || bucket.until <= now) {
    if (bursts.size >= 2000) return false;
    bucket = { count: 0, until: now + 60_000 }; bursts.set(key, bucket);
  }
  return ++bucket.count <= 60;
}

export async function proxy(request: NextRequest) {
  if (!burstAllowed(request)) return new NextResponse("Too many requests. Please try again shortly.", { status: 429, headers: { "Retry-After": "60", "Cache-Control": "no-store" } });
  const path = request.nextUrl.pathname;
  if (path.startsWith("/g/")) {
    const id = path.split("/")[2];
    if (!giftId(id)) return new NextResponse("Gift not found.", { status: 404 });
    try { await rateLimit(request, "gift-read"); } catch (error) { return failure(error); }
  }
  if (path.startsWith("/api/") || path.endsWith("/opengraph-image")) return NextResponse.next();
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");
  const dev = process.env.NODE_ENV === "development";
  const policy = [
    "default-src 'self'", `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ""}`,
    "script-src-attr 'none'", "style-src 'self' 'unsafe-inline'", "img-src 'self' data: blob:",
    "font-src 'self'", `connect-src 'self'${dev ? " ws: wss:" : ""}`, "media-src 'self' blob:",
    "object-src 'none'", "base-uri 'none'", "form-action 'self'", "frame-ancestors 'none'",
    ...(!dev ? ["upgrade-insecure-requests"] : []),
  ].join("; ");
  const headers = new Headers(request.headers);
  headers.set("x-nonce", nonce); headers.set("Content-Security-Policy", policy);
  const response = NextResponse.next({ request: { headers } });
  response.headers.set("Content-Security-Policy", policy);
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}

export const config = { matcher: ["/", "/bouquet", "/photobooth", "/g/:path*", "/gifts", "/journal/:path*", "/privacy", "/terms", "/api/:path*"] };
