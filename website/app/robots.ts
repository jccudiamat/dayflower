import type { MetadataRoute } from "next";
import { url } from "./lib/seo";

export default function robots(): MetadataRoute.Robots {
  return {
    // ⚠️ /g/ is NOT disallowed here on purpose. Those pages carry
    // `robots: noindex` in their metadata, and a crawler blocked by robots.txt
    // never fetches the page, never sees the noindex, and will happily index
    // the bare URL anyway. Blocking it would be the thing that leaks it.
    rules: { userAgent: "*", allow: "/", disallow: "/api/" },
    sitemap: url("/sitemap.xml"),
    host: url(),
  };
}
