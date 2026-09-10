import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import GiftCatalog from "./GiftCatalog";

export const metadata: Metadata = {
  title: "Gift Ideas for Couples, Family & Friends | Dayflower",
  description: "Find thoughtful gifts on Shopee Philippines, from flowers and photo keepsakes to coffee, jewelry and little comforts. Browse by gift type, recipient and peso budget.",
  alternates: { canonical: "https://mydayflower.com/gifts" },
  openGraph: { title: "A little something. A lot of love. | Dayflower Gifts", description: "Thoughtful Shopee Philippines finds for the people you love.", url: "https://mydayflower.com/gifts", type: "website" },
};

export default function GiftsPage() {
  return <><SiteHeader /><main className="mx-auto max-w-5xl px-5 py-10 sm:py-16">
    <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">Dayflower gift guide</p>
    <h1 className="mt-4 max-w-2xl text-3xl font-bold leading-tight sm:text-5xl">A little something.<br />A lot of love.</h1>
    <p className="mt-5 max-w-2xl text-base leading-relaxed text-body">Flowers that last, photos they can carry, and something for their morning coffee. Find a thoughtful gift for your partner, family, or friends.</p>
    <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted">Shopee Philippines · Prices in PHP, checked 10 September 2026. This is a saved collection; prices, variants, and availability may change. Check the seller’s listing for delivery and personalization details.</p>
    <GiftCatalog />
    <p className="mt-8 text-sm leading-relaxed text-muted">Product photos belong to the sellers. Links open Shopee in a new tab. Orders, payment, and delivery are handled on Shopee.</p>
    <section className="mt-12 rounded-3xl bg-dark-canvas p-7 text-on-dark sm:p-10"><h2 className="text-2xl font-bold">Make a little memory, too.</h2><p className="my-4 max-w-xl leading-relaxed text-on-dark-muted">A photo strip makes a personal extra for a gift. Make yours in our free photo booth, with no account needed.</p><Link href="/photobooth" className="gradient-button !max-w-full !whitespace-normal text-center">Make a photo strip ↗</Link></section>
    </main><footer className="mx-auto flex max-w-5xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/photobooth">Photo booth</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer></>;
}
