import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  return ["", "/bouquet", "/photobooth", "/gifts", "/journal", "/journal/long-distance-date-ideas", "/privacy", "/terms"].map(path => ({ url: `https://mydayflower.com${path}`, changeFrequency: "monthly", priority: path === "" || path === "/photobooth" || path === "/bouquet" ? 1 : .3 }));
}
