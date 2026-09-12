import { html as waitlistHtml } from "../../../emails/waitlist-confirmation";
import { htmlFor } from "../../../emails/bouquet-gift";

/** Dev-only: renders an email in the browser so it can be looked at. */
export function GET(request: Request) {
  if (process.env.NODE_ENV === "production") return new Response(null, { status: 404 });
  const which = new URL(request.url).searchParams.get("template");
  const html = which === "gift"
    ? htmlFor({
        url: "https://mydayflower.com/g/GBdIg5FMvfUm",
        imageUrl: "https://mydayflower.com/g/GBdIg5FMvfUm/opengraph-image",
        to: "Sheena",
        from: "Jc",
        note: "A little reminder that you make my world a lovelier place.",
      })
    : waitlistHtml;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "X-Robots-Tag": "noindex, nofollow", "Cache-Control": "no-store" } });
}
