import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  images: {
    dangerouslyAllowSVG: false,
    remotePatterns: [],
    localPatterns: [{ pathname: "/mark.png", search: "" }, { pathname: "/flowers/**", search: "" }, { pathname: "/gifts/**", search: "" }, { pathname: "/bouquet/**", search: "" }],
    qualities: [75],
  },
  async headers() {
    return [{ source: "/:path*", headers: [
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "X-Frame-Options", value: "DENY" },
      { key: "Referrer-Policy", value: "no-referrer" },
      { key: "Permissions-Policy", value: "camera=(self), microphone=(), geolocation=(), payment=(), usb=()" },
      { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
    ] }];
  },
  outputFileTracingIncludes: {
    "/g/*/opengraph-image": ["./public/bouquet/reveal-*.png"],
  },
};

export default nextConfig;
