import type { BeforeSendEvent } from "@vercel/analytics/next";

// Gift IDs are bearer credentials. Only known public page paths may reach
// analytics, and query strings/fragments may contain personal information.
const publicPaths = new Set([
  "/", "/bouquet", "/photobooth", "/gifts", "/journal", "/long-distance",
  "/privacy", "/terms", "/journal/long-distance-date-ideas",
  "/journal/digital-bouquet-messages", "/journal/how-to-make-photo-strips",
]);

export function publicAnalyticsEvent(event: BeforeSendEvent): BeforeSendEvent | null {
  try {
    const url = new URL(event.url);
    if (!publicPaths.has(url.pathname) || url.hash.includes("gift=")) return null;
    url.search = "";
    url.hash = "";
    return { ...event, url: url.toString() };
  } catch {
    return null;
  }
}
