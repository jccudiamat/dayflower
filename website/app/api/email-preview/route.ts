import { html } from "../../../emails/waitlist-confirmation";
export function GET() {
  if (process.env.NODE_ENV === "production") return new Response(null, { status: 404 });
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "X-Robots-Tag": "noindex, nofollow", "Cache-Control": "no-store" } });
}
