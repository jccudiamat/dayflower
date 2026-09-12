import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import SiteHeader from "../../components/SiteHeader";
import BouquetStudio from "../../bouquet/BouquetStudio";
import { loadGift } from "../../lib/gift";

/**
 * A gift someone was sent. Server-rendered so the crawler behind a chat or
 * mail preview can actually read it — which is the whole reason this route
 * exists rather than everything living in a `#gift=` fragment.
 *
 * ⚠️ **Nothing on this page may name what is inside.** The title, the
 * description and the card all appear in the recipient's notifications before
 * they have opened anything, and the surprise is the point. "Bouquet" and
 * "flowers" belong on /bouquet, which is the shop, not the gift.
 */

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const bouquet = await loadGift(id);
  if (!bouquet) return { title: "This gift link has expired", robots: { index: false, follow: false } };

  const to = bouquet.to.trim();
  // First person on purpose: the card sits directly under the sender's own
  // message, so it should read as them speaking, not as the site announcing.
  const title = to ? `${to}, I made this for you` : "I made this for you";
  const description = "Open when you have a minute.";
  return {
    title,
    description,
    // A gift is private to the two of them; it should never turn up in search.
    robots: { index: false, follow: false },
    openGraph: { title, description, url: `https://mydayflower.com/g/${id}`, type: "website" },
    twitter: { card: "summary_large_image", title, description },
  };
}

export default async function GiftPage({ params }: Props) {
  const { id } = await params;
  const bouquet = await loadGift(id);
  if (!bouquet) notFound();

  return <><SiteHeader bouquet /><main className="bouquet-page"><BouquetStudio gift={bouquet} />
  </main><footer className="bouquet-footer"><Link href="/">Dayflower</Link><Link href="/bouquet">Make one yourself</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer></>;
}
