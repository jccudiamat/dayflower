import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import BouquetStudio from "./BouquetStudio";
import { JsonLd, faqPage, breadcrumbs, openGraph, ORGANISATION, url } from "../lib/seo";

export const metadata: Metadata = {
  title: "Free Digital Bouquet Creator | Dayflower",
  description: "Pick your flowers, wrap them with love, and add a personal note. Create and send a free digital bouquet by link, or download it as an image. No account needed.",
  alternates: { canonical: url("/bouquet") },
  // ⚠️ The <title> and meta description above stay explicit: they are what
  // search results show. The Open Graph card is what lands in a chat, and a
  // gift is meant to be a surprise, so it must never say bouquet or flowers.
  openGraph: openGraph({ title: "A little something, just for you", description: "Made by hand on Dayflower. Open it when you have a minute.", path: "/bouquet", image: null }),
};

/**
 * Rendered twice, as <details> for readers and as FAQPage data for crawlers,
 * from one array, so the two can never drift.
 */
const questions = [
  ["Is it free to make and send a bouquet?", "Yes. Pick your flowers, add a note, and share your bouquet without an account or payment."],
  ["How does the gift link work?", "Your link opens the bouquet in a browser, and the preview your chat app shows says only that you made someone something. It never gives away what is inside. Anyone with the link can open it and read the note, so keep it between you if it is personal."],
  ["Can I change it after sending?", "Each link is a snapshot of your bouquet. If you make changes, create and send a new link. The original link keeps its original flowers and message."],
  ["Can I keep my flowers?", "Yes. Download a PNG image of the bouquet and its note. Your unfinished bouquet is also saved in this browser when local storage is available. Shared gift links keep working for about 400 days, so download the image for anything you want to keep for good."],
] as const;

export default async function BouquetPage() {
  return <><SiteHeader bouquet /><main className="bouquet-page"><BouquetStudio />
    <section className="bouquet-faq" aria-labelledby="bouquet-questions"><h2 id="bouquet-questions">Little things to know</h2>
      {questions.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}
    </section>
    <section className="bouquet-faq" aria-labelledby="bouquet-about"><h2 id="bouquet-about">Flowers you can send from anywhere</h2>
      <p>A digital bouquet is flowers that arrive as a link, so there is no florist, no delivery window, and no address to ask for. Choose from 54 illustrated blooms, wrap them in a paper you like, tuck in a photo and a handwritten-looking note, then send it by message or email. It is free, and neither of you needs an account.</p>
      <p>It suits the days a real delivery cannot reach: a partner in another country, a friend whose address you never got round to asking for, a birthday you remembered an hour before midnight. If you would like something to keep as well, download the bouquet as an image, or make a <Link href="/photobooth">photo strip</Link> to go with it. Looking for something physical instead? Our <Link href="/gifts">gift ideas</Link> are picked from Shopee Philippines.</p>
    </section>
  </main><footer className="bouquet-footer"><Link href="/">Dayflower</Link><Link href="/photobooth">Make a photo strip</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer>
    <JsonLd nodes={[
      { "@type": "WebApplication", "@id": url("/bouquet#app"), name: "Dayflower Digital Bouquet Creator", url: url("/bouquet"), applicationCategory: "DesignApplication", operatingSystem: "Web browser", browserRequirements: "Requires JavaScript.", publisher: { "@id": ORGANISATION["@id"] }, offers: { "@type": "Offer", price: "0", priceCurrency: "USD" }, featureList: "54 illustrated flowers, wrapping papers and vessels, photo inserts, a written note, shareable gift link, PNG download" },
      faqPage(questions),
      breadcrumbs([["Bouquet", "/bouquet"]]),
    ]} />
  </>;
}
