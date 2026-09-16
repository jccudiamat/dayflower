import type { MetadataRoute } from "next";
import { url } from "./lib/seo";

/**
 * ⚠️ `lastModified` is a hand-kept date per route, deliberately not
 * `new Date()`. A lastmod that moves every build is a lastmod that lies about
 * every page on every deploy, and crawlers that catch a site doing it stop
 * trusting the field, which costs you the one signal it was there to send.
 * Bump the date here when a page's content actually changes.
 *
 * `changeFrequency` and `priority` are ignored by Google outright; they stay
 * only because other crawlers still read them.
 */
const pages = [
  ["", "2026-09-16", 1],
  ["/bouquet", "2026-09-16", 1],
  ["/photobooth", "2026-09-16", 1],
  ["/long-distance", "2026-09-16", 0.9],
  ["/gifts", "2026-09-16", 0.7],
  ["/journal", "2026-09-16", 0.6],
  ["/journal/long-distance-date-ideas", "2026-09-08", 0.8],
  ["/privacy", "2026-09-16", 0.2],
  ["/terms", "2026-09-16", 0.2],
] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  return pages.map(([path, lastModified, priority]) => ({
    url: url(path),
    lastModified,
    changeFrequency: "monthly",
    priority,
  }));
}
