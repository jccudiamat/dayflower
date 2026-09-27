import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import HomeNav from "./components/HomeNav";
import WaitlistForm from "./components/WaitlistForm";
import { JsonLd, faqPage, openGraph, ORGANISATION, WEBSITE, url } from "./lib/seo";
import "./home.css";

const title = "Dayflower | Free Digital Bouquets & Photo Keepsakes";
const description = "Create and send a free digital bouquet or make a photo strip, collage, or postcard. No account needed. Discover Dayflower’s upcoming private app for couples.";

export const metadata: Metadata = {
  title, description,
  alternates: { canonical: url() },
  openGraph: openGraph({ title, description, path: "" }),
};

const questions = [
  ["What can I use right now?", "The digital bouquet creator and photo booth are ready to use in your browser. You can also browse gift ideas and read the journal. The Dayflower app is in private testing."],
  ["Are the website tools free?", "Yes. Creating and sharing a digital bouquet, and making and downloading a photo keepsake, are free. You do not need an account or a place on the app waitlist. Physical gifts linked from our gift guide are sold separately by sellers on Shopee."],
  ["Can I send something to someone far away?", "Yes. Send a digital bouquet as a link they can open in their browser, or download a photo keepsake to share in your usual chat. For a couple photo strip, collect both people’s photos on one device; the booth is not a live video room."],
  ["Who is Dayflower for?", "The website tools are for anyone making a thoughtful gesture for a partner, friend, or family member. The upcoming app is a private space for couples to share everyday life, near or far."],
  ["What happens when I join the app waitlist?", "We’ll send a signup confirmation, then a launch email when the app is ready. Joining does not create an app account or sign your partner up. There is no newsletter."],
] as const;

const screens = [
  { name: "Home", x: 16, note: "A little window into their day.", alt: "Dayflower Home preview with a daily photo, moods, local times, and an upcoming anniversary" },
  { name: "Chat", x: 270, note: "Your everyday conversation.", alt: "Dayflower Chat preview with messages and shared daily photos" },
  { name: "Dayflower", x: 520, note: "Small gestures, just because.", alt: "Dayflower preview with flowers, bouquets, cards, a photo booth, and a shared garden" },
  { name: "Memories", x: 770, note: "The little things, kept together.", alt: "Dayflower Memories preview with a timeline of flowers, photo strips, and journal entries" },
  { name: "Together", x: 1022, note: "More to look forward to.", alt: "Dayflower Together preview with shared plans, reminders, trips, and activities" },
] as const;

function PhotoStrip() {
  return <div className="home-photo-strip">
    <Image src="/models/sunset.webp" alt="A woman at the beach at sunset" width={720} height={960} sizes="180px" />
    <Image src="/models/cove.webp" alt="A man on a boat in a turquoise cove" width={720} height={960} sizes="180px" />
    <span className="note">a little us, to keep.</span>
  </div>;
}

export default function Home() {
  return <div className="home-page">
    <HomeNav />
    <main id="main-content" className="dayflower-home">
      <section className="home-hero home-shell" aria-labelledby="hero-title">
        <div className="home-hero-copy">
          <p className="home-eyebrow">SMALL GESTURES. REAL CONNECTION.</p>
          <h1 id="hero-title">A little something.<br /><em>Just for them.</em></h1>
          <p className="home-lede">Send a digital bouquet or turn your favorite photos into a keepsake. Free little ways to make someone’s day, wherever they are.</p>
          <div className="home-actions">
            <Link className="home-button" href="/bouquet">Make a bouquet <span aria-hidden="true">↗</span></Link>
            <Link className="home-button home-button-secondary" href="/photobooth">Try the photo booth <span aria-hidden="true">↗</span></Link>
          </div>
          <p className="home-reassurance">Free to create and share. No account needed.</p>
          <a className="home-app-hint" href="#app">Looking for the couples app? See what’s coming <span aria-hidden="true">↓</span></a>
        </div>
        <div className="home-keepsakes" aria-label="Examples of a digital bouquet and a photo keepsake">
          <figure className="home-bouquet-preview">
            <p className="home-sample-label">A LITTLE SOMETHING FOR YOU</p>
            <Image src="/models/bouquet-sample.webp" alt="Roses, daisies, and tulips wrapped in cream paper with a photo tucked between the flowers" width={720} height={625} sizes="(max-width: 600px) 64vw, 340px" preload />
            <figcaption className="note">Just because you’re you.</figcaption>
          </figure>
          <div className="home-strip-preview"><PhotoStrip /></div>
        </div>
      </section>

      <section id="explore" className="home-tools-section home-shell" aria-labelledby="tools-title">
        <div className="home-section-heading"><div><p className="home-eyebrow">READY WHEN YOU ARE</p><h2 id="tools-title">Make their day, today.</h2></div><p>Open a tool. Make it yours.<br />Send a little love.</p></div>
        <div className="home-tools">
          <article className="home-tool"><span className="home-tool-number">01 / FLOWERS, FROM ANYWHERE</span><h3>Send a digital bouquet.</h3><p>Choose your flowers and wrapping, tuck in photos and a personal note, then share a link or download your bouquet.</p><Link href="/bouquet">Create a free bouquet <span aria-hidden="true">↗</span></Link></article>
          <article className="home-tool"><span className="home-tool-number">02 / MORE THAN A CAMERA ROLL</span><h3>Make a photo keepsake.</h3><p>Turn your photos into a strip, collage, or postcard. Choose a layout, add a caption, and download an image to keep or share.</p><Link href="/photobooth">Open the free photo booth <span aria-hidden="true">↗</span></Link></article>
        </div>
        <div className="home-more"><Link href="/gifts"><span>Something you can send to their door</span><strong>Gift ideas from Shopee Philippines <span aria-hidden="true">↗</span></strong></Link><Link href="/journal"><span>A little inspiration for your time together</span><strong>Read the Dayflower journal <span aria-hidden="true">↗</span></strong></Link></div>
      </section>

      <section id="app" className="home-app" aria-labelledby="app-title">
        <div className="home-shell">
          <div className="home-app-heading"><p className="home-eyebrow">THE DAYFLOWER APP · COMING SOON</p><h2 id="app-title">Your everyday.<br /><em>A little closer.</em></h2><p className="home-lede">A private space for the two of you. Share your day, leave a little love, and keep the moments that make your story.</p><a className="home-button" href="#waitlist">Join the app waitlist <span aria-hidden="true">↗</span></a><p className="home-app-status">In private testing. Not available to download yet.</p></div>
          <p className="home-swipe-hint">Scroll through the five app previews →</p>
          <div className="home-screens" role="region" aria-label="Five Dayflower app previews, scroll horizontally to see more" tabIndex={0}>
            {screens.map(screen => <figure key={screen.name}>
              {/* CSS windows preserve the supplied contact sheet and its UI. */}
              <div className="home-screen-window"><Image src="/models/app-preview.jpg" alt={screen.alt} width={1280} height={853} sizes="1280px" style={{ left: `${-screen.x / 244 * 100}%` }} /></div>
              <figcaption><h3>{screen.name}</h3><p>{screen.note}</p></figcaption>
            </figure>)}
          </div>
          <p className="home-preview-note">App design previews. Features and appearance may change before launch.</p>
          <Link className="home-distance-link" href="/long-distance">Across time zones? Explore our ideas for long-distance couples <span aria-hidden="true">↗</span></Link>
        </div>
      </section>

      <section className="home-questions home-shell" aria-labelledby="questions-title"><div><p className="home-eyebrow">GOOD TO KNOW</p><h2 id="questions-title">The website now.<br />The app to come.</h2><p>Two ways to stay close.<br />Here’s what’s ready today.</p></div><div className="home-question-list">{questions.map(([q, a]) => <details key={q}><summary>{q}<span aria-hidden="true">+</span></summary><p>{a}</p></details>)}</div></section>

      <section id="waitlist" className="home-waitlist home-shell" aria-labelledby="waitlist-title"><div className="home-waitlist-inner"><div><p className="home-eyebrow">SOMETHING TO LOOK FORWARD TO</p><h2 id="waitlist-title">Be the first to know.</h2><p>Leave your email. We’ll let you know when the Dayflower app is ready for you and your partner.</p></div><div className="home-signup"><WaitlistForm /><p>A signup confirmation, then a launch email. No newsletter.</p><Link href="/privacy">How we use your email</Link></div></div></section>
    </main>
    <footer className="home-footer home-shell"><div><Link href="/" className="home-brand"><Image src="/mark.png" width={26} height={26} alt="" />Dayflower</Link><p>Little ways to be there.</p></div><nav aria-label="Footer navigation"><Link href="/bouquet">Digital bouquet</Link><Link href="/photobooth">Photo booth</Link><Link href="/gifts">Gift ideas</Link><Link href="/journal">Journal</Link><Link href="/long-distance">Long distance</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></nav><small>© {new Date().getFullYear()} Dayflower</small></footer>
    <JsonLd nodes={[
      { "@type": "WebPage", "@id": url("/#webpage"), url: url(), name: title, description, isPartOf: { "@id": WEBSITE["@id"] }, about: { "@id": ORGANISATION["@id"] }, inLanguage: "en" },
      { "@type": "ItemList", name: "Free Dayflower tools", itemListElement: [["Digital bouquet creator", "/bouquet"], ["Photo booth and keepsake maker", "/photobooth"]].map(([name, path], i) => ({ "@type": "ListItem", position: i + 1, name, url: url(path) })) },
      faqPage(questions),
    ]} />
  </div>;
}
