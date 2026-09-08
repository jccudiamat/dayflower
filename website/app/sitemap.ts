import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  return ["", "/photobooth", "/privacy", "/terms"].map(path => ({ url: `https://mydayflower.com${path}`, changeFrequency: "monthly", priority: path === "" || path === "/photobooth" ? 1 : .3 }));
}
