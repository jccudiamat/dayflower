import SiteHeader from "./components/SiteHeader";
import Image from "next/image";
import type { Metadata } from "next";
import ProductTour from "./components/ProductTour";
import Link from "next/link";
import WaitlistForm from "./components/WaitlistForm";
import "./home.css";
import { JsonLd, faqPage, ORGANISATION, WEBSITE, url } from "./lib/seo";

export const metadata: Metadata = {
  // ⚠️ Deliberately the umbrella, not a keyword. Each tool page owns its own
  // head term: /bouquet owns "digital bouquet", /photobooth owns "photo
  // booth". Repeating those here would put the homepage in a fight with the
  // page that actually answers the query, and split the signal between them.
  title: "Dayflower | Little ways to make their day",
  description: "Make a digital bouquet, create a photo keepsake, find a thoughtful gift, or read the journal. Explore Dayflower’s free website tools and join the waitlist for our private app for two.",
  alternates: { canonical: url() },
};

const tools = [
  { number: "01", name: "Bouquet", label: "Flowers, with a little more you.", description: "Choose from 54 flowers, tuck in photos and a note, then send your bouquet as a little surprise.", href: "/bouquet", action: "Make a bouquet", note: "Free to create & send", className: "is-bouquet" },
  { number: "02", name: "Booth", label: "Make a memory you can keep.", description: "Turn your favorite photos into a scrapbook, collage, postcard, or photo strip. Eight layouts, ready to download.", href: "/photobooth", action: "Open the booth", note: "Free · no account needed", className: "is-booth" },
  { number: "03", name: "Gifts", label: "A little something, picked for them.", description: "Browse thoughtful finds for your partner, family, and friends, with gift ideas from Shopee Philippines.", href: "/gifts", action: "Browse gifts", note: "Curated gift ideas", className: "is-gifts" },
  { number: "04", name: "Journal", label: "A few ideas for feeling closer.", description: "Find long-distance date ideas and small ways to make room for each other, wherever life has you.", href: "/journal", action: "Read the journal", note: "Ideas for your time together", className: "is-journal" },
];

/**
 * The homepage FAQ, in one place because it is rendered twice: as <details>
 * for readers, and as FAQPage structured data for machines. Two copies of an
 * answer drift apart, and a page whose markup contradicts its own text is
 * worse than one with no markup at all.
 */
const questions = [

      ["What can I use right now?", "The bouquet creator and photo booth are free to use in your browser, without an account. You can also browse our gift picks and read the journal."],
      ["Is the Dayflower app available?", "The app is in private testing. Join the waitlist and we’ll email you when it’s ready for you and your partner to try."],
      ["Who is Dayflower for?", "The website is for anyone making a thoughtful gesture for a partner, friend, or family member. The app is a private space for a couple, designed for everyday connection across any distance."],
      ["What happens when I join the waitlist?", "We’ll send a signup confirmation, then a launch email when the app is ready. Joining the waitlist doesn’t create an app account or sign your partner up."],
] as const;

export default async function Home() {
  return <><SiteHeader /><main id="top" className="dayflower-home">
    <section className="home-hero">
      <div className="home-hero-copy"><p className="home-eyebrow">LITTLE THINGS. MEANINGFUL CONNECTIONS.</p>
        <h1>Make their day.<br /><span>Stay close, every day.</span></h1>
        <p>A bouquet for no reason. A photo worth keeping. A small reminder that they’re on your mind. Find a little way to show up for someone you love.</p>
        <div className="home-hero-actions"><Link className="home-primary" href="/#waitlist">Join the app waitlist</Link><a href="#explore" className="home-text-link">Explore the website <span aria-hidden="true">↓</span></a></div>
        <p className="home-availability">Website tools are ready to use. The app is in private testing.</p>
      </div>
      <div className="home-letter"><p className="home-letter-to note">For your favorite person.</p><Image src="/bouquet/reveal-envelope.webp" alt="An ivory envelope sealed with a burgundy heart and a sprig of flowers" width={512} height={512} priority className="home-letter-art" /><p className="home-letter-note">A little something can mean everything.</p><span className="home-letter-signature">with love, Dayflower</span></div>
    </section>
    <section id="explore" className="home-explore" aria-labelledby="explore-title"><div className="home-section-intro"><div><p className="home-eyebrow">HERE FOR THE LITTLE GESTURES</p><h2 id="explore-title">What will you make of today?</h2></div><p>Make something, find something, or plan a moment together. It all starts here.</p></div>
      <div className="home-tools">{tools.map(tool => <article key={tool.name} className={`home-tool ${tool.className}`}><div className="home-tool-top"><span>{tool.number}</span><p>{tool.note}</p></div><h3>{tool.name}</h3><p className="home-tool-label">{tool.label}</p><p className="home-tool-description">{tool.description}</p><Link href={tool.href}>{tool.action}<span aria-hidden="true">↗</span></Link></article>)}</div>
    </section>
    <ProductTour />
    <section className="home-questions" aria-labelledby="questions-title"><div><p className="home-eyebrow">A FEW THINGS TO KNOW</p><h2 id="questions-title">The website now.<br />The app to come.</h2></div><div>{questions
    .map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}</div></section>
    <section id="waitlist" className="home-waitlist"><div><p className="home-eyebrow">YOUR OWN LITTLE SPACE FOR TWO</p><h2>A little closer.<br /><span>Even from here.</span></h2><p>Be among the first to try the Dayflower app together. Leave your email and we’ll let you know when it’s ready.</p><WaitlistForm dark /><small>A signup confirmation, then a launch email. No newsletter.</small></div></section>
  </main><footer className="home-footer"><Link href="/" className="home-footer-brand"><Image src="/mark.png" width={24} height={24} alt="" />Dayflower</Link><nav aria-label="Footer navigation"><Link href="/bouquet">Bouquet</Link><Link href="/long-distance">Long distance</Link><Link href="/photobooth">Booth</Link><Link href="/gifts">Gifts</Link><Link href="/journal">Journal</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></nav><p>© {new Date().getFullYear()} Dayflower</p></footer>
    <JsonLd nodes={[
      { "@type": "WebPage", "@id": url("/#webpage"), url: url(), name: "Dayflower", isPartOf: { "@id": WEBSITE["@id"] }, about: { "@id": ORGANISATION["@id"] }, inLanguage: "en" },
      faqPage(questions),
      // The four tools, as the site's own table of contents. Named here so a
      // crawler that only reads the graph still learns the site has four
      // things in it and where each one lives.
      { "@type": "ItemList", name: "Dayflower website tools", itemListElement: tools.map((tool, i) => ({ "@type": "ListItem", position: i + 1, name: tool.name, description: tool.description, url: url(tool.href) })) },
    ]} />
  </>;
}
