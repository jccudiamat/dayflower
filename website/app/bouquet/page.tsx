import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import BouquetStudio from "./BouquetStudio";

export const metadata: Metadata = {
  title: "Free Digital Bouquet Creator | Dayflower",
  description: "Pick your flowers, wrap them with love, and add a personal note. Create and send a free digital bouquet by link, or download it as an image. No account needed.",
  alternates: { canonical: "https://mydayflower.com/bouquet" },
  // ⚠️ The <title> and meta description above stay explicit — they are what
  // search results show. The Open Graph card is what lands in a chat, and a
  // gift is meant to be a surprise, so it must never say bouquet or flowers.
  openGraph: { title: "A little something, just for you", description: "Made by hand on Dayflower. Open it when you have a minute.", url: "https://mydayflower.com/bouquet", type: "website" },
};

export default function BouquetPage() {
  return <><SiteHeader bouquet /><main className="bouquet-page"><BouquetStudio />
    <section className="bouquet-faq" aria-labelledby="bouquet-questions"><h2 id="bouquet-questions">Little things to know</h2>
      <details><summary>Is it free to make and send a bouquet?</summary><p>Yes. Pick your flowers, add a note, and share your bouquet without an account or payment.</p></details>
      <details><summary>How does the gift link work?</summary><p>Your link opens the bouquet in a browser, and the preview your chat app shows says only that you made someone something. It never gives away what is inside. Anyone with the link can open it and read the note, so keep it between you if it is personal.</p></details>
      <details><summary>Can I change it after sending?</summary><p>Each link is a snapshot of your bouquet. If you make changes, create and send a new link. The original link keeps its original flowers and message.</p></details>
      <details><summary>Can I keep my flowers?</summary><p>Yes. Download a PNG image of the bouquet and its note. Your unfinished bouquet is also saved in this browser when local storage is available. Shared gift links keep working for about 400 days, so download the image for anything you want to keep for good.</p></details>
    </section>
  </main><footer className="bouquet-footer"><Link href="/">Dayflower</Link><Link href="/photobooth">Make a photo strip</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer></>;
}
