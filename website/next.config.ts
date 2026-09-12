import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingIncludes: {
    "/g/*/opengraph-image": ["./public/bouquet/reveal-*.png"],
  },
};

export default nextConfig;
