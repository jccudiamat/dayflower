import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import BouquetStudio from "./BouquetStudio";

export const metadata: Metadata = {
  title: "Free Digital Bouquet Creator | Dayflower",
  description: "Pick your flowers, wrap them with love, and add a personal note. Create and send a free digital bouquet by link, or download it as an image. No account needed.",
  alternates: { canonical: "https://mydayflower.com/bouquet" },
  openGraph: { title: "A little bouquet, a lot of love | Dayflower", description: "Someone is thinking of you. Open your digital flowers, made with love.", url: "https://mydayflower.com/bouquet", type: "website" },
};

export default function BouquetPage() {
  return <><SiteHeader bouquet /><main className="bouquet-page"><BouquetStudio />
    <section className="bouquet-faq" aria-labelledby="bouquet-questions"><h2 id="bouquet-questions">Little things to know</h2>
      <details><summary>Is it free to make and send a bouquet?</summary><p>Yes. Pick your flowers, add a note, and share your bouquet without an account or payment.</p></details>
      <details><summary>How does the gift link work?</summary><p>Your flowers and note are included in the link itself. Send the whole link so the recipient can open their gift in a browser. Anyone with that link can read the note. Keep it between you if it is personal.</p></details>
      <details><summary>Can I change it after sending?</summary><p>Each link is a snapshot of your bouquet. If you make changes, create and send a new link. The original link keeps its original flowers and message.</p></details>
      <details><summary>Can I keep my flowers?</summary><p>Yes. Download a PNG image of the bouquet and its note. Your unfinished bouquet is also saved in this browser when local storage is available. Gift links work while this website remains available.</p></details>
    </section>
  </main><footer className="bouquet-footer"><Link href="/">Dayflower</Link><Link href="/photobooth">Make a photo strip</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer></>;
}
