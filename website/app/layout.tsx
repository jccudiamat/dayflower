import type { Metadata, Viewport } from "next";
import { Quicksand, Lora } from "next/font/google";
import "./globals.css";
import { connection } from "next/server";
import { JsonLd, ORGANISATION, WEBSITE, SITE, SITE_NAME } from "./lib/seo";
import { Analytics } from "@vercel/analytics/next";

const quicksand = Quicksand({
  variable: "--font-quicksand",
  subsets: ["latin"],
});

const lora = Lora({
  variable: "--font-lora",
  subsets: ["latin"],
  style: ["italic", "normal"],
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: "Dayflower | One flower a day, across any distance",
  description:
    "A private app for exactly two people. Somewhere to land on each other every day when you can't be in the same room. Join the waitlist.",
  applicationName: SITE_NAME,
  // ⚠️ Inherited defaults only. `alternates.canonical` is deliberately NOT
  // set here: metadata inherits down the tree, so a canonical on the layout
  // would tell Google that every page on the site is the homepage.
  openGraph: { siteName: SITE_NAME, locale: "en_US", type: "website" },
  twitter: { card: "summary_large_image" },
  robots: {
    index: true,
    follow: true,
    // Without these, Google truncates the snippet and refuses to show a
    // large image preview for a domain it does not yet recognise.
    googleBot: { index: true, follow: true, "max-snippet": -1, "max-image-preview": "large", "max-video-preview": -1 },
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fffdf8" },
    { media: "(prefers-color-scheme: dark)", color: "#171027" },
  ],
  colorScheme: "light",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Nonces are unique to a request, so HTML must never be prerendered/cached.
  await connection();
  return (
    <html lang="en" className={`${quicksand.variable} ${lora.variable} antialiased`}>
      <body>
        {children}
        {/* The publisher and the site itself, declared once at the root so
            every page carries the same entity rather than each asserting its
            own. Page-level nodes reference these two by `@id`. */}
        <JsonLd nodes={[ORGANISATION, WEBSITE]} />
        {/* Page views, cookielessly.

            ⚠️ Needs no CSP change and no nonce, which is not obvious given
            `script-src` here has no `unsafe-inline` and carries
            `strict-dynamic`. It works because the component injects its tag
            with `createElement` inside an effect: a script created by an
            already-trusted script inherits that trust, which is the whole
            point of `strict-dynamic`. A parser-inserted tag would be
            dropped. Its beacons go to same-origin `/_vercel/insights/*`, so
            `connect-src 'self'` already covers them.

            If a future version switches to rendering the tag server-side,
            this goes silently dead rather than erroring — check for the
            script in the DOM before trusting an empty dashboard. */}
        <Analytics />
      </body>
    </html>
  );
}
