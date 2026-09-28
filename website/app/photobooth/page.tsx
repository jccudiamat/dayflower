import SiteHeader from "../components/SiteHeader";
import type { Metadata } from "next";
import Link from "next/link";
import Booth from "./Booth";
import { ExampleStrip } from "../components/Examples";
import { JsonLd, faqPage, breadcrumbs, openGraph, ORGANISATION, url } from "../lib/seo";

export const metadata: Metadata = {
  title: "Free Online Photo Booth & Photo Strip Maker | Dayflower",
  description: "Use your camera or upload photos to make free photo strips, collages, and postcards. Eight layouts, PNG downloads, no signup. Photos stay in your browser.",
  alternates: { canonical: url("/photobooth") },
  openGraph: openGraph({ title: "Free Online Photo Booth & Photo Strip Maker | Dayflower", description: "Use your camera or upload photos. Eight layouts, free PNG downloads, no signup.", path: "/photobooth", image: null }),
};
const faqs = [
  ["Is this online photo booth free?", "Yes. Create and download solo or couple photo strips without signing up or joining the waitlist."],
  ["Can we make a couple strip from different places?", "Yes. Collect both people’s photos on one device and choose You & me. Add one person to column A and the other to column B. This is a shared-photo layout, not a live video room."],
  ["Are my photos uploaded or stored?", "No. Photo selection, camera capture, cropping, and strip generation happen in your browser. We do not send your photos to our servers or keep a gallery. Clear all photos or close the page to end the session. Downloads stay on your device; sharing sends the image to the app you choose."],
  ["Can I use my phone camera?", "Yes, in browsers that support camera access over HTTPS. Allow camera access, select a slot, and take a photo after the three-second countdown. If access is unavailable, upload JPG, PNG, or WebP photos instead."],
  ["What can I customize?", "Choose from eight layouts: scrapbook, nine-photo recap, editorial collage, instant prints, film strip, postcard, couple, or classic booth. Pick a Rose, Cream, After dark, or Lilac palette. Change your caption, switch to black and white, and adjust the zoom and position of each photo. The PNG uses the same layout as the preview."],
  ["How do I save or share my strip?", "Fill every slot and select Create my image, then Download PNG. Share image opens supported devices’ share menus. On other devices, download the image and share it from your files or photos app."],
] as const;
export default async function PhotoboothPage() {
  return <>
    <SiteHeader photobooth />
    <main className="site-page mx-auto max-w-6xl px-5 py-10">
      <p className="text-sm font-semibold text-brand-dark">DAYFLOWER PHOTO BOOTH</p>
      <h1 className="mt-3 max-w-3xl text-3xl font-bold leading-tight sm:text-5xl">Free online photo booth<br />& photo strip maker.</h1>
      <p className="mt-4 max-w-2xl text-base leading-relaxed text-body">Use your camera or upload your favorite photos. This digital photo booth turns them into strips, scrapbook collages, and postcards you can download as a PNG. Eight free designs. No signup. Photos stay in your browser.</p>
      <Booth />
      <section className="grid items-start gap-10 py-10 lg:grid-cols-[1fr_auto] lg:gap-14"><div><h2 className="text-3xl font-bold">From camera roll to keepsake</h2><ol className="mt-7 grid gap-7 sm:grid-cols-3 lg:grid-cols-2">{[["01 · Add your moments", "Choose a template with two to nine photos. Use the camera or upload pictures you already love."],["02 · Make it feel like you", "Pick a frame, add a caption, and adjust each crop. Try black and white for a classic booth look."],["03 · Keep it or send it", "Create your PNG, download it, or share it with someone. Your original photos never leave this browser through the booth."]].map(([title, text]) => <li key={title}><h3 className="font-bold">{title}</h3><p className="mt-3 leading-relaxed text-body">{text}</p></li>)}</ol></div><div className="mx-auto pt-4 lg:mx-0"><ExampleStrip /></div></section>
      <section className="max-w-3xl py-10"><h2 className="text-3xl font-bold">Photo booth questions</h2><div className="mt-7 divide-y divide-border-soft">{faqs.map(([q,a]) => <details key={q} className="py-5"><summary className="cursor-pointer font-bold">{q}</summary><p className="mt-3 leading-relaxed text-body">{a}</p></details>)}</div></section>
      <section className="max-w-3xl pb-10"><h2 className="text-2xl font-bold">Make a strip that feels like you</h2><p className="mt-4 leading-8 text-body">For three portraits, start with The original. Choose You &amp; me for two columns of three photos, or Life lately for a nine-photo recap. Story designs export at 1080 × 1920; feed designs export at 1080 × 1350.</p><p className="mt-4 leading-8 text-body">Our <Link href="/journal/how-to-make-photo-strips" className="font-bold text-brand-dark underline underline-offset-4">guide to making photo strips online</Link> covers choosing a layout, adjusting crops, and saving your PNG. Making one together? Try these <Link href="/journal/long-distance-date-ideas#photo-strip" className="font-bold text-brand-dark underline underline-offset-4">photo prompts for a long-distance date</Link>.</p></section>
      <section className="rounded-3xl bg-blush p-8 text-ink sm:p-12"><h2 className="text-3xl font-bold">Add a little something.</h2><p className="my-5 max-w-xl leading-relaxed text-body">Pair your photo strip with a free digital bouquet. Pick their favorite flowers, tuck in a note, and send a gift link.</p><Link href="/bouquet" className="gradient-button">Make a digital bouquet</Link><p className="mt-5 text-sm"><Link href="/#app" className="underline underline-offset-4">Discover the upcoming Dayflower app</Link></p></section>
    </main>
    <footer className="mx-auto flex max-w-6xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer>
    <JsonLd nodes={[
      { "@type": "WebApplication", "@id": url("/photobooth#app"), name: "Dayflower Photo Booth", url: url("/photobooth"), applicationCategory: "MultimediaApplication", operatingSystem: "Web browser", browserRequirements: "Requires JavaScript. Camera access requires HTTPS and permission.", publisher: { "@id": ORGANISATION["@id"] }, offers: { "@type": "Offer", price: "0", priceCurrency: "USD" }, featureList: "Eight collage and photo strip templates, story and feed formats, camera capture, local image processing, PNG download" },
      faqPage(faqs),
      breadcrumbs([["Photo booth", "/photobooth"]]),
    ]} />
  </>;
}
