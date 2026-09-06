import Image from "next/image";
import Link from "next/link";
import PolaroidStack from "./components/PolaroidStack";
import RotatingWord from "./components/RotatingWord";
import WaitlistForm from "./components/WaitlistForm";
import { Card } from "./components/ui";
import { headlineWords, lines, polaroids, stripBlooms } from "./lib/content";

/**
 * The landing page is a waitlist page and nothing more.
 *
 * It deliberately does **not** show the app's screens, its feature list, the
 * flower meanings, or the roadmap — all of that was on here until 2026-09-06
 * and amounted to a build spec anyone could copy. The job now is to make a
 * stranger want in and hand over an email; anything past that is a leak.
 *
 * The artwork stays because it is the one thing that can't be lifted from a
 * screenshot — but it appears without names or meanings attached.
 */
export default function Home() {
  return (
    <div className="min-h-screen">
      {/* ── Nav ─────────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-50 border-b border-border-soft bg-bg/85 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between gap-4 px-5">
          <a href="#top" className="flex shrink-0 items-center gap-2 text-lg font-bold">
            <Image src="/mark.png" alt="" width={360} height={360} className="h-7 w-7" />
            Dayflower
          </a>
          <a href="#waitlist" className="gradient-button !h-10 !px-5 text-sm">
            Join the waitlist
          </a>
        </div>
      </header>

      <main id="top">
        {/* ── Hero ──────────────────────────────────────────────────────── */}
        <section className="bg-dark-canvas text-on-dark">
          <div className="mx-auto grid max-w-5xl items-center gap-14 px-5 py-20 sm:py-28 lg:grid-cols-[1.05fr_0.95fr]">
            <div>
              <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-dark-border bg-dark-surface px-4 py-1.5 text-xs font-semibold text-on-dark-muted">
                In private testing
              </p>
              {/* min-height reserves the tallest wrap. Without it a long word
                  ("reminder") pushes the headline onto an extra line on
                  narrow screens and the paragraph and form below it jump
                  every time the word changes. 1.25 = leading-tight, so 5em is
                  four lines and 2.5em is two. */}
              <h1 className="min-h-[5em] text-4xl font-bold leading-tight sm:min-h-[2.5em] sm:text-5xl">
                <span className="sr-only">
                  One flower a day, across any distance.
                </span>
                <span aria-hidden>
                  One <RotatingWord words={headlineWords} /> a day,
                  <br />
                  across any distance.
                </span>
              </h1>
              <p className="mt-5 max-w-md text-[15.5px] leading-relaxed text-on-dark-muted">
                A private app for exactly two people — somewhere to land on
                each other every day when you can&rsquo;t be in the same room.
              </p>
              <div className="mt-8" id="waitlist">
                <WaitlistForm dark />
                <p className="mt-3 pl-1 text-xs text-on-dark-muted">
                  Free at launch. One email when it&rsquo;s ready — nothing else.
                </p>
              </div>
            </div>

            {/* The app's own polaroid, stacked and throwable. */}
            <div className="pt-6 lg:pt-0">
              <PolaroidStack cards={polaroids} />
            </div>
          </div>
        </section>

        {/* ── Three lines ───────────────────────────────────────────────── */}
        <section className="mx-auto max-w-5xl px-5 py-20 sm:py-24">
          <div className="grid gap-4 sm:grid-cols-3">
            {lines.map((l) => (
              <Card key={l.title}>
                <span className="text-2xl" aria-hidden>{l.emoji}</span>
                <h2 className="mt-3 text-[17px] font-bold">{l.title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-body">{l.text}</p>
              </Card>
            ))}
          </div>
        </section>

        {/* ── Artwork ───────────────────────────────────────────────────────
            Full-bleed and uncaptioned: the point is that it looks like
            nothing else, not what any single one of them means. */}
        <section className="bg-dark-canvas pt-4">
          <div className="grid grid-cols-3 gap-1 sm:grid-cols-6">
            {stripBlooms.map((id) => (
              <div key={id} className="bloom-tile !rounded-none">
                <Image
                  src={`/flowers/${id}.webp`}
                  alt=""
                  width={512}
                  height={512}
                  sizes="(max-width: 640px) 34vw, 17vw"
                />
              </div>
            ))}
          </div>
        </section>

        {/* ── Closing CTA ───────────────────────────────────────────────── */}
        <section className="bg-dark-canvas pb-24 pt-20 text-on-dark">
          <div className="mx-auto flex max-w-2xl flex-col items-center px-5 text-center">
            <h2 className="text-3xl font-bold leading-tight sm:text-4xl">
              Send the first one{" "}
              <span className="gradient-text">when we open.</span>
            </h2>
            <p className="mt-4 max-w-md text-[15px] leading-relaxed text-on-dark-muted">
              Dayflower is in private testing. Leave an address and we&rsquo;ll
              write once, on the day it&rsquo;s ready.
            </p>
            <div className="mt-8 flex w-full justify-center">
              <WaitlistForm dark />
            </div>
          </div>
        </section>
      </main>

      {/* ── Footer ──────────────────────────────────────────────────────── */}
      <footer className="border-t border-border-soft py-10">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-4 px-5 text-sm text-muted sm:flex-row">
          <p className="flex items-center gap-2 font-semibold text-body">
            <Image src="/mark.png" alt="" width={360} height={360} className="h-5 w-5" />
            Dayflower
          </p>
          <div className="flex gap-6">
            <Link href="/privacy" className="hover:text-ink">Privacy</Link>
            <Link href="/terms" className="hover:text-ink">Terms</Link>
          </div>
          <p>© {new Date().getFullYear()} Dayflower</p>
        </div>
      </footer>
    </div>
  );
}
