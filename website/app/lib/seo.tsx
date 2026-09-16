import { headers } from "next/headers";

/** Canonical origin. Everything that emits an absolute URL reads it from here. */
export const SITE = "https://mydayflower.com";
export const SITE_NAME = "Dayflower";

export const url = (path = "") => `${SITE}${path}`;

/**
 * The publisher, written once.
 *
 * ⚠️ Referenced by `@id` from every other node rather than repeated inline.
 * Search engines merge nodes that share an `@id`, so one Organization the
 * whole site points at reads as a single entity; four copies with drifting
 * details read as four.
 */
export const ORGANISATION = {
  "@type": "Organization",
  "@id": url("/#organisation"),
  name: SITE_NAME,
  // People search the domain, not the brand: "mydayflower" is what gets
  // typed. Naming it here is how the string gets attached to this entity
  // rather than left to Google to guess.
  alternateName: "mydayflower",
  url: SITE,
  logo: { "@type": "ImageObject", url: url("/mark.png"), width: 512, height: 512 },
  // ⚠️ "Dayflower" is also a real plant (Commelina communis), so the brand
  // competes with Wikipedia and every gardening site for its own name. These
  // say which Dayflower this is.
  knowsAbout: ["Long-distance relationships", "Digital bouquets", "Photo booths", "Gift ideas"],
  description:
    "Dayflower makes small, free tools for showing someone you are thinking of them: a digital bouquet, a photo booth, and gift ideas, alongside a private app for two.",
} as const;

export const WEBSITE = {
  "@type": "WebSite",
  "@id": url("/#website"),
  name: SITE_NAME,
  alternateName: "mydayflower",
  url: SITE,
  publisher: { "@id": ORGANISATION["@id"] },
  inLanguage: "en",
} as const;

/**
 * A complete `openGraph` block. Use this instead of writing the object by hand.
 *
 * 🔴 **Metadata merges shallowly, so a page that declares `openGraph` replaces
 * the root layout's entirely.** It does not extend it. Every page that set
 * its own Open Graph object was therefore shipping with no `og:site_name`, no
 * `og:locale`, and, worse, no `og:image`: declaring the field also suppresses
 * the inherited `opengraph-image` file from an ancestor segment. The tags
 * simply were not in the HTML, and nothing warns you.
 *
 * Pass `image: null` for a segment that has its own `opengraph-image.tsx`
 * (`/bouquet`, `/photobooth`, `/g/[id]`): a file in the *same* segment still
 * applies, and those three deliberately do not use the branded card.
 */
export function openGraph({ title, description, path, type = "website", image = url("/opengraph-image"), ...rest }: {
  title: string;
  description: string;
  path: string;
  type?: "website" | "article";
  image?: string | null;
  publishedTime?: string;
  modifiedTime?: string;
  authors?: string[];
}) {
  return {
    siteName: SITE_NAME,
    locale: "en_US",
    type,
    title,
    description,
    url: url(path),
    ...(image ? { images: [image] } : {}),
    ...rest,
  };
}

/** Turns our FAQ pairs into the shape schema.org wants. */
export const faqPage = (pairs: readonly (readonly [string, string])[]) => ({
  "@type": "FAQPage",
  mainEntity: pairs.map(([question, answer]) => ({
    "@type": "Question",
    name: question,
    acceptedAnswer: { "@type": "Answer", text: answer },
  })),
});

/** Home › Section › Page. Home is implied by the site, so it is item 1. */
export const breadcrumbs = (trail: readonly (readonly [string, string])[]) => ({
  "@type": "BreadcrumbList",
  itemListElement: [["Home", "/"], ...trail].map(([name, path], i) => ({
    "@type": "ListItem",
    position: i + 1,
    name,
    item: url(path),
  })),
});

/**
 * One `<script type="application/ld+json">`, carrying the request nonce.
 *
 * ⚠️ The nonce is not optional. Our CSP has no `unsafe-inline` for scripts,
 * and CSP blocks *every* inline `<script>` element by type, including ones
 * the browser never executes. A nonce-less block of JSON-LD is simply
 * dropped, silently, and the page ships with no structured data at all.
 *
 * Emits a single `@graph` so the nodes can cross-reference by `@id`.
 */
export async function JsonLd({ nodes }: { nodes: readonly object[] }) {
  const nonce = (await headers()).get("x-nonce") ?? undefined;
  return (
    <script
      nonce={nonce}
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify({ "@context": "https://schema.org", "@graph": nodes }),
      }}
    />
  );
}
