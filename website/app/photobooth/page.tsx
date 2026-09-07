import SiteHeader from "../components/SiteHeader";
import type { Metadata } from "next";
import Link from "next/link";
import Booth from "./Booth";

export const metadata: Metadata = {
  title: "Free Photo Booth, Collage & Photo Dump Maker | Dayflower",
  description: "Make scrapbook collages, photo dumps, postcards, and solo or couple photo strips. Add photos and save a story or feed-sized PNG. No login. Photos stay on your device.",
  alternates: { canonical: "https://mydayflower.com/photobooth" },
  openGraph: { title: "Free Photo Booth — Dayflower", description: "Solo moments. Two-person keepsakes. Make a photo strip for free, without an account.", url: "https://mydayflower.com/photobooth", type: "website" },
};
const faqs = [
  ["Is this online photo booth free?", "Yes. Create and download solo or couple photo strips without signing up or joining the waitlist."],
  ["Can we make a couple strip from different places?", "Yes. Collect both people’s photos on one device and choose You & me. Add one person to column A and the other to column B. This is a shared-photo layout, not a live video room."],
  ["Are my photos uploaded or stored?", "No. Photo selection, camera capture, cropping, and strip generation happen in your browser. We do not send your photos to our servers or keep a gallery. Clear all photos or close the page to end the session. Downloads stay on your device; sharing sends the image to the app you choose."],
  ["Can I use my phone camera?", "Yes, in browsers that support camera access over HTTPS. Allow camera access, select a slot, and take a photo after the three-second countdown. If access is unavailable, upload JPG, PNG, or WebP photos instead."],
  ["What can I customize?", "Choose from eight layouts: scrapbook, nine-photo recap, editorial collage, instant prints, film strip, postcard, couple, or classic booth. Pick a Rose, Cream, After dark, or Lilac palette. Change your caption, switch to black and white, and adjust the zoom and position of each photo. The PNG uses the same layout as the preview."],
  ["How do I save or share my strip?", "Fill every slot and select Create my image, then Download PNG. Share image opens supported devices’ share menus. On other devices, download the image and share it from your files or photos app."],
];
function AdSpace({ id }: { id: string }) { return <aside id={id} className="ad-reservation" aria-label="Reserved advertising space">ADVERTISEMENT<small>Reserved space</small></aside>; }
export default function PhotoboothPage() {
  return <>
    <SiteHeader photobooth />
    <main className="mx-auto max-w-6xl px-5 py-10">
      <p className="text-sm font-semibold text-brand-dark">DAYFLOWER PHOTO BOOTH</p>
      <h1 className="mt-3 text-3xl font-bold leading-tight sm:text-5xl">Good moments deserve more than a camera roll.</h1>
      <p className="mt-4 max-w-2xl text-base leading-relaxed text-body">Turn your favorites into a scrapbook, a photo dump, or a keepsake for two. Eight free designs. Ready to save and share. No account needed.</p>
      <Booth />
      <AdSpace id="photobooth-ad-after-editor" />
      <section className="py-10"><h2 className="text-3xl font-bold">From camera roll to keepsake</h2><ol className="mt-7 grid gap-7 sm:grid-cols-3">{[["01 · Add your moments", "Choose a template with two to nine photos. Use the camera or upload pictures you already love."],["02 · Make it feel like you", "Pick a frame, add a caption, and adjust each crop. Try black and white for a classic booth look."],["03 · Keep it or send it", "Create your PNG, download it, or share it with someone. Your original photos never leave this browser through the booth."]].map(([title, text]) => <li key={title}><h3 className="font-bold">{title}</h3><p className="mt-3 leading-relaxed text-body">{text}</p></li>)}</ol></section>
      <section className="max-w-3xl py-10"><h2 className="text-3xl font-bold">Photo booth questions</h2><div className="mt-7 divide-y divide-border-soft">{faqs.map(([q,a]) => <details key={q} className="py-5"><summary className="cursor-pointer font-bold">{q}</summary><p className="mt-3 leading-relaxed text-body">{a}</p></details>)}</div></section>
      <AdSpace id="photobooth-ad-before-footer" />
      <section className="rounded-3xl bg-dark-canvas p-8 text-on-dark sm:p-12"><h2 className="text-3xl font-bold">Keep the little things going.</h2><p className="my-5 max-w-xl leading-relaxed text-on-dark-muted">Dayflower is also a private app for two, with home-screen widgets, flowers, calls, and shared moments. Get a little closer, every day.</p><Link href="/#waitlist" className="gradient-button">Explore Dayflower</Link></section>
    </main>
    <footer className="mx-auto flex max-w-6xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({ "@context": "https://schema.org", "@type": "WebApplication", name: "Dayflower Photo Booth", url: "https://mydayflower.com/photobooth", applicationCategory: "MultimediaApplication", operatingSystem: "Web browser", browserRequirements: "Requires JavaScript. Camera access requires HTTPS and permission.", offers: { "@type": "Offer", price: "0", priceCurrency: "USD" }, featureList: "Eight collage and photo strip templates, story and feed formats, camera capture, local image processing, PNG download" }) }} />
  </>;
}
