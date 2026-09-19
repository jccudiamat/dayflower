import type { Metadata } from "next";
import Link from "next/link";
import DayflowerWorld from "./DayflowerWorld";
import SiteHeader from "../components/SiteHeader";
import WaitlistForm from "../components/WaitlistForm";
import { openGraph, url } from "../lib/seo";
import "./world.css";

const title = "Be part of their day";
const description =
  "A private space for two. Send a bouquet, keep a photo, and stay close through the small moments in between. Wander through a day with Dayflower.";

export const metadata: Metadata = {
  title: `${title} | Dayflower`,
  description,
  alternates: { canonical: url("/world") },
  openGraph: openGraph({ title, description, path: "/world" }),
  // ⚠️ Staging, so it stays out of the index until it replaces the homepage.
  // Two pages of ours competing for the same words would split the signal,
  // and this one is not finished.
  robots: { index: false, follow: false },
};

/**
 * The Dayflower world.
 *
 * 🔴 **Every word on this page is HTML.** The canvas behind it is scenery with
 * `pointer-events: none` and `aria-hidden`; nothing here needs it to be
 * understood, reached by keyboard, or read by a crawler. Turn WebGL off and
 * the page still says the same things over a painted sky. That constraint is
 * section 29 of the brief, and it is also the only way this page can carry the
 * homepage's search weight when it eventually takes its place.
 */
export default function WorldPage() {
  return (
    <>
      <DayflowerWorld />
      <div className="world-page">
        <SiteHeader />

        <main>
          <section className="world-act" aria-labelledby="hero">
            <div className="world-panel">
              <p className="world-eyebrow">Dayflower</p>
              <h1 id="hero">
                Be part of their day.
                <span>Even from here.</span>
              </h1>
              <p className="world-lede">
                Little ways to stay close through the moments in between. A bouquet for
                a Tuesday. A photo from their walk home. The small things that usually
                go unsaid.
              </p>
              <div className="world-actions">
                <Link className="world-primary" href="/bouquet">Make a bouquet</Link>
                <Link className="world-secondary" href="#waitlist">Join the waitlist</Link>
              </div>
              <p className="world-hint">
                <span aria-hidden>↓</span> Wander through our day
              </p>
            </div>
          </section>

          <section className="world-act" aria-labelledby="make">
            <div className="world-panel">
              <p className="world-eyebrow">Morning</p>
              <h2 id="make">What will you make of today?</h2>
              <p className="world-lede">
                The website tools are free and need no account. Pick a few flowers,
                write the part that matters, and send it in the same chat you always
                use.
              </p>
              <div className="world-actions">
                <Link className="world-primary" href="/bouquet">Make a bouquet</Link>
                <Link className="world-secondary" href="/photobooth">Open the photo booth →</Link>
              </div>
            </div>
          </section>

          <section className="world-act" aria-labelledby="distance">
            <div className="world-panel">
              <p className="world-eyebrow">Afternoon</p>
              <h2 id="distance">Different places. Same day.</h2>
              <p className="world-lede">
                Know when they are waking up, working, winding down, or probably
                asleep, without doing the timezone maths every time you want to say
                something.
              </p>
              <div className="world-actions">
                <Link className="world-secondary" href="/long-distance">For couples apart →</Link>
              </div>
            </div>
          </section>

          <section className="world-act world-act-narrow" id="waitlist" aria-labelledby="closing">
            <div className="world-panel">
              <p className="world-eyebrow">Night</p>
              <h2 id="closing">A little closer. Even from here.</h2>
              <p className="world-lede">
                Dayflower is a private app for exactly two people, and it is in private
                testing. Be among the first couples to try it together.
              </p>
              <div style={{ marginTop: 26 }}>
                <WaitlistForm />
              </div>
              <p className="world-lede" style={{ fontSize: 13 }}>
                A signup confirmation, then a launch email. No newsletter.
              </p>
            </div>
          </section>
        </main>
      </div>
    </>
  );
}
