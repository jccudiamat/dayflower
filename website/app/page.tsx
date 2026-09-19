import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import HomeNav from "./components/HomeNav";
import WaitlistForm from "./components/WaitlistForm";
import AppPhones from "./components/AppPhones";
import Parallax from "./components/scene/Parallax";
import Scenery from "./components/scene/Scenery";
import HeroPigeon from "./components/scene/HeroPigeon";
import { SignPost, Mailbox } from "./components/scene/Props";
import { Petals, Fireflies } from "./components/scene/Drift";
import "./components/scene/scene.css";
import "./components/phones.css";
import "./home.css";
import { JsonLd, ORGANISATION, WEBSITE, url } from "./lib/seo";

export const metadata: Metadata = {
  // ⚠️ Deliberately the umbrella, not a keyword. Each tool page owns its own
  // head term: /bouquet owns "digital bouquet", /photobooth owns "photo
  // booth". Repeating those here would put the homepage in a fight with the
  // page that actually answers the query, and split the signal between them.
  title: "Dayflower | Little ways to make their day",
  description:
    "Make a digital bouquet, create a photo keepsake, find a thoughtful gift, or read the journal. Explore Dayflower’s free website tools and join the waitlist for our private app for two.",
  alternates: { canonical: url() },
};

/**
 * The four things you can actually do on the website today, in the order the
 * reference lays them out. Each one goes to the real tool; none of them is a
 * mockup of a tool that does not exist.
 */
const tools = [
  {
    name: "Bouquet",
    description: "Send flowers that feel like yours.",
    href: "/bouquet",
    tone: "is-bouquet",
    art: { src: "/models/bouquet-sample.webp", alt: "A wrapped bouquet of roses, daisies and tulips with a photo tucked in among the stems", width: 720, height: 625 },
  },
  {
    name: "Photo Booth",
    description: "Turn moments into keepsakes.",
    href: "/photobooth",
    tone: "is-booth",
    art: null,
  },
  {
    name: "Gifts",
    description: "Thoughtful ideas for the person you know best.",
    href: "/gifts",
    tone: "is-gifts",
    art: { src: "/bouquet/reveal-box.webp", alt: "A pink gift box tied with a wide ribbon and a few flowers", width: 512, height: 512 },
  },
  {
    name: "Journal",
    description: "Ideas, prompts and a more connected you.",
    href: "/journal",
    tone: "is-journal",
    art: { src: "/bouquet/reveal-letter.webp", alt: "A bundle of handwritten letters tied with a ribbon", width: 512, height: 512 },
  },
] as const;

const features = [
  { title: "Daily moments", note: "Photos, moods, heartbeats", icon: <path d="M12 20.6s-8-5-8-10.4A4.7 4.7 0 0 1 12 7a4.7 4.7 0 0 1 8 3.2c0 5.4-8 10.4-8 10.4Z" /> },
  { title: "Stay in sync", note: "Local time and distance", icon: <><circle cx="12" cy="12" r="8.4" /><path d="M12 7.4v5l3.2 2" /></> },
  { title: "Look forward", note: "Countdowns, plans, dates", icon: <><rect x="3.6" y="5.2" width="16.8" height="15.2" rx="3" /><path d="M3.6 10h16.8M8.4 3.4v3.4M15.6 3.4v3.4" /></> },
  { title: "Keep what matters", note: "Memories, journals, milestones", icon: <><rect x="3.6" y="4.6" width="16.8" height="15.6" rx="3.4" /><path d="M12 16.4s-3.6-2.3-3.6-4.8a2.1 2.1 0 0 1 3.6-1.4 2.1 2.1 0 0 1 3.6 1.4c0 2.5-3.6 4.8-3.6 4.8Z" /></> },
];

const values = [
  {
    title: "Just yours",
    body: ["No followers. No public feed.", "No likes to chase."],
    icon: <><rect x="5" y="10.4" width="14" height="9.6" rx="2.6" /><path d="M8.2 10.4V8a3.8 3.8 0 0 1 7.6 0v2.4" /><path d="M12 14v2.4" /></>,
  },
  {
    title: "For all kinds of couples",
    body: ["Long distance, same city,", "anywhere in between."],
    icon: <path d="M12 20.4s-7.6-4.7-7.6-9.8A4.5 4.5 0 0 1 12 7.2a4.5 4.5 0 0 1 7.6 3.4c0 5.1-7.6 9.8-7.6 9.8Z" />,
  },
  {
    title: "Built with care",
    body: ["A more intentional way", "to stay connected."],
    icon: <><circle cx="9" cy="8.4" r="3.2" /><circle cx="16.4" cy="9.6" r="2.4" /><path d="M3.8 19.4a5.2 5.2 0 0 1 10.4 0" /><path d="M15.4 14.6a4.4 4.4 0 0 1 4.8 4.8" /></>,
  },
];

export default async function Home() {
  return (
    <>
      <HomeNav />
      <main id="top" className="dayflower-home">
        {/* ── Morning ─────────────────────────────────────────────────────
            The scenery is a sibling of the copy, never its container: the
            headline, both buttons and the scroll cue are ordinary HTML that
            would stand on a plain gradient if every layer below failed. */}
        <section className="home-hero" aria-labelledby="hero-title">
          <Parallax className="home-hero-scene">
            <Scenery time="dawn" />
            <SignPost />
            <p className="scene-note scene-note-dawn">
              Good things
              <br />
              bloom,
              <br />
              always. ♡
            </p>
            <Petals />
          </Parallax>
          <HeroPigeon />

          <div className="home-hero-copy">
            <h1 id="hero-title">
              Be part of
              <br />
              their day.
            </h1>
            <p className="home-hero-lede">
              Little ways to stay close through
              <br />
              the moments in between.
            </p>
            <div className="home-hero-actions">
              <Link className="home-cta" href="/#explore">
                Explore Dayflower <span aria-hidden="true">→</span>
              </Link>
              <Link className="home-cta-plain" href="/#waitlist">
                Join the waitlist
              </Link>
            </div>
          </div>

          <a className="home-scroll" href="#explore">
            Scroll <span aria-hidden="true">↓</span>
          </a>
        </section>

        {/* ── Create ──────────────────────────────────────────────────────── */}
        <section id="explore" className="home-create" aria-labelledby="create-title">
          <div className="home-shell home-create-grid">
            <div className="home-intro">
              <p className="home-eyebrow">CREATE</p>
              <h2 id="create-title">
                What will you make
                <br />
                of today?
              </h2>
              <p className="home-lede">Turn feelings into something meaningful.</p>
            </div>

            <div className="home-cards">
              {tools.map((tool) => (
                <Link key={tool.name} href={tool.href} className={`home-card ${tool.tone}`}>
                  <span className="home-card-art">
                    {tool.art ? (
                      <Image
                        src={tool.art.src}
                        alt={tool.art.alt}
                        width={tool.art.width}
                        height={tool.art.height}
                        sizes="(max-width: 700px) 90vw, 240px"
                      />
                    ) : (
                      <BoothArt />
                    )}
                  </span>
                  <span className="home-card-name">{tool.name}</span>
                  <span className="home-card-desc">{tool.description}</span>
                  <span className="home-card-go" aria-hidden="true">
                    →
                  </span>
                </Link>
              ))}
            </div>
          </div>
        </section>

        {/* ── The app ─────────────────────────────────────────────────────── */}
        <section id="app" className="home-app" aria-labelledby="app-title">
          <div className="home-shell home-app-grid">
            <div className="home-intro">
              <p className="home-eyebrow">APP</p>
              <h2 id="app-title">
                A private space
                <br />
                for your everyday
                <br />
                moments.
              </h2>
              <p className="home-lede">The Dayflower app. Made for the two of you.</p>
              {/* ⚠️ The reference says "Learn more" here. There is no app page
                  to learn more on yet, and sending somebody to a signup form
                  under that label is a small lie, so the button says what it
                  actually does. */}
              <Link className="home-pill" href="/#waitlist">
                Join the waitlist <span aria-hidden="true">→</span>
              </Link>
            </div>

            <figure className="home-app-stage">
              <AppPhones />
              <figcaption>App preview · illustrative sample content</figcaption>
            </figure>

            <ul className="home-features">
              {features.map((f) => (
                <li key={f.title}>
                  <svg viewBox="0 0 24 24" aria-hidden className="home-feature-icon">
                    {f.icon}
                  </svg>
                  <div>
                    <p className="home-feature-title">{f.title}</p>
                    <p className="home-feature-note">{f.note}</p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* ── Who it is for ───────────────────────────────────────────────── */}
        <section id="about" className="home-values" aria-labelledby="values-title">
          <div className="home-shell home-values-grid">
            <div className="home-intro">
              <p className="home-eyebrow">FOR REAL RELATIONSHIPS</p>
              <h2 id="values-title">
                Made for all
                <br />
                kinds of couples.
              </h2>
              <p className="home-lede">
                Whether you&rsquo;re near or far, Dayflower helps you stay present in the little
                things that make a big difference.
              </p>
              <Link className="home-pill" href="/long-distance">
                Learn more <span aria-hidden="true">→</span>
              </Link>
            </div>

            <ul className="home-value-list">
              {values.map((v) => (
                <li key={v.title}>
                  <svg viewBox="0 0 24 24" aria-hidden className="home-value-icon">
                    {v.icon}
                  </svg>
                  <p className="home-value-title">{v.title}</p>
                  <p className="home-value-body">
                    {v.body[0]}
                    <br />
                    {v.body[1]}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* ── Night ───────────────────────────────────────────────────────
            The same valley, later. Nothing says so in words, and it does not
            need to. */}
        <section id="waitlist" className="home-night" aria-labelledby="night-title">
          <Parallax className="home-night-scene">
            <Scenery time="night" />
            <Mailbox />
            <p className="scene-note scene-note-night">
              Same moon.
              <br />
              Same us. ♡
            </p>
            <Fireflies />
          </Parallax>

          <div className="home-night-copy">
            <h2 id="night-title">
              A little closer.
              <br />
              Even from here.
            </h2>
            <p>Be among the first couples to try Dayflower together.</p>
            <WaitlistForm />
            <p className="home-night-invite">
              Invite your favorite person. <span aria-hidden="true">♡</span>
            </p>
            <small>A signup confirmation, then a launch email. No newsletter.</small>
          </div>
        </section>
      </main>

      <footer className="home-footer">
        <div className="home-shell home-footer-grid">
          <Link href="/" className="home-footer-brand">
            <Image src="/mark.png" width={26} height={26} alt="" />
            Dayflower
          </Link>
          <nav aria-label="Footer navigation">
            <Link href="/#explore">Explore</Link>
            <Link href="/bouquet">Bouquet</Link>
            <Link href="/photobooth">Photo booth</Link>
            <Link href="/gifts">Gifts</Link>
            <Link href="/journal">Journal</Link>
            <Link href="/long-distance">Long distance</Link>
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
          </nav>
          <p className="home-footer-line">A calmer, kinder internet for two.</p>
        </div>
        <p className="home-footer-copy">© {new Date().getFullYear()} Dayflower</p>
      </footer>

      <JsonLd
        nodes={[
          { "@type": "WebPage", "@id": url("/#webpage"), url: url(), name: "Dayflower", isPartOf: { "@id": WEBSITE["@id"] }, about: { "@id": ORGANISATION["@id"] }, inLanguage: "en" },
          // The four tools, as the site's own table of contents. Named here so
          // a crawler that only reads the graph still learns the site has four
          // things in it and where each one lives.
          {
            "@type": "ItemList",
            name: "Dayflower website tools",
            itemListElement: tools.map((tool, i) => ({
              "@type": "ListItem",
              position: i + 1,
              name: tool.name,
              description: tool.description,
              url: url(tool.href),
            })),
          },
        ]}
      />
    </>
  );
}

/**
 * The booth, which has no single object to photograph the way a bouquet or a
 * gift box does. A strip of prints is what it makes, so a strip of prints is
 * what the card shows.
 */
function BoothArt() {
  return (
    <span className="home-strip">
      <span className="home-strip-print">
        <Image src="/models/cove.webp" alt="" width={720} height={960} sizes="90px" />
        <Image src="/models/sunset.webp" alt="" width={720} height={960} sizes="90px" />
        <Image src="/models/cove.webp" alt="" width={720} height={960} sizes="90px" />
        <em className="note">you &amp; me</em>
      </span>
      <span className="sr-only">A photo strip of three pictures</span>
    </span>
  );
}
