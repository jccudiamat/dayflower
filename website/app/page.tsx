import SiteHeader from "./components/SiteHeader";
import Image from "next/image";
import type { Metadata } from "next";
import ProductTour from "./components/ProductTour";
import Link from "next/link";
import PolaroidStack from "./components/PolaroidStack";
import RotatingWord from "./components/RotatingWord";
import WaitlistForm from "./components/WaitlistForm";
import { headlineWords, polaroids } from "./lib/content";

/** Landing page grounded in the current Flutter app. */
export const metadata: Metadata = { alternates: { canonical: "https://mydayflower.com" } };
export default function Home() {
  return (
    <div className="min-h-screen">
      {/* ── Nav ─────────────────────────────────────────────────────────── */}
      <SiteHeader />

      <main id="top">
        {/* ── Hero ──────────────────────────────────────────────────────── */}
        <section className="bg-dark-canvas text-on-dark">
          <div className="mx-auto grid max-w-5xl items-center gap-9 px-5 py-10 sm:gap-14 sm:py-20 lg:grid-cols-[1.05fr_0.95fr]">
            <div>
              <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-dark-border bg-dark-surface px-4 py-1.5 text-xs font-semibold text-on-dark-muted">
                In private testing
              </p>
              {/* Keep the mobile headline stable; animate only on wider screens. */}
              <h1 className="text-[clamp(28px,8.2vw,32px)] font-bold leading-[1.18] sm:min-h-[2.5em] sm:text-5xl sm:leading-tight">
                <span className="sr-only">
                  One flower a day, across any distance.
                </span>
                <span aria-hidden className="sm:hidden">One <span className="gradient-text">flower</span> a day,<br />across any distance.</span>
                <span aria-hidden className="hidden sm:inline">
                  One <RotatingWord words={headlineWords} /> a day,
                  <br />
                  across any distance.
                </span>
              </h1>
              <p className="mt-5 max-w-md text-[15.5px] leading-relaxed text-on-dark-muted">
                A private app for exactly two people — somewhere to land on
                each other every day when you can&rsquo;t be in the same room.
              </p>
              <div className="mt-8 scroll-mt-36 sm:scroll-mt-24" id="waitlist">
                <div className="mb-7 sm:hidden">
                  <Link href="/photobooth" className="gradient-button !h-12 !px-6">Make a photo strip ↗</Link>
                  <p className="mt-2 text-xs text-on-dark-muted">Free photo booth · No account needed</p>
                </div>
                <p className="mb-3 text-sm font-semibold text-on-dark-muted sm:hidden">Want the app? Join the waitlist.</p>
                <WaitlistForm dark />
                <p className="mt-3 pl-1 text-xs text-on-dark-muted">
                  Free at launch. A confirmation now, a launch email when it&rsquo;s ready.
                </p>
              </div>
            </div>

            {/* The app's own polaroid, stacked and throwable. */}
            <div className="pt-6 lg:pt-0">
              <PolaroidStack cards={polaroids} />
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-5xl px-5 py-14" aria-labelledby="free-booth-title">
          <div className="rounded-3xl border border-border-soft bg-surface-subtle p-7 sm:p-10">
            <p className="text-sm font-bold text-brand-dark">TRY SOMETHING TOGETHER</p>
            <h2 id="free-booth-title" className="mt-3 text-3xl font-bold">Your next photo strip starts here.</h2>
            <p className="my-5 max-w-xl leading-relaxed text-body">A solo moment or a keepsake for two. Take or upload photos, choose a frame, and save your strip. Free, with no account required.</p>
            <Link href="/photobooth" className="gradient-button !max-w-full !whitespace-normal text-center">Open the photo booth ↗</Link>
          </div>
        </section>
        <ProductTour />

        <section className="mx-auto grid max-w-5xl gap-10 px-5 py-20 sm:py-24 md:grid-cols-[0.8fr_1.2fr] md:gap-20" aria-labelledby="questions-title">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">Before you join</p>
            <h2 id="questions-title" className="mt-5 text-3xl font-bold leading-tight">A few things<br />you might be wondering.</h2>
          </div>
          <div className="divide-y divide-border-soft border-y border-border-soft">
            {[
              { question: "Who is Dayflower for?", answer: "Couples who want to feel more connected in everyday life. Especially when distance, time zones, or busy schedules keep you apart." },
              { question: "Can we use it yet?", answer: "Not quite. Dayflower is in private testing. Join the waitlist and we’ll email you when it’s ready to try." },
              { question: "Is it a social network?", answer: "Dayflower is a space for you and your partner. There’s no public feed or audience to post for." },
              { question: "What happens when I join the waitlist?", answer: "You’ll receive a signup confirmation, then an email when Dayflower is ready. Joining doesn’t create an app account or sign your partner up." },
            ].map((item) => (
              <details key={item.question} className="group py-5">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-base font-bold [&::-webkit-details-marker]:hidden">
                  {item.question}<span aria-hidden className="text-xl font-normal text-brand-dark group-open:rotate-45">+</span>
                </summary>
                <p className="mt-4 pr-6 text-[15px] leading-relaxed text-body">{item.answer}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="bg-dark-canvas px-5 py-20 text-on-dark sm:py-24">
          <div className="mx-auto flex max-w-2xl flex-col items-center text-center">
            <Image src="/mark.png" alt="" width={360} height={360} className="mb-6 h-12 w-12" />
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-g-pink">Something to look forward to</p>
            <h2 className="mt-5 text-3xl font-bold leading-tight sm:text-4xl">A little closer,<br /><span className="gradient-text">even from here.</span></h2>
            <p className="mt-5 max-w-md text-base leading-relaxed text-on-dark-muted">Be among the first to try Dayflower with your partner. Leave your email and we&rsquo;ll let you know when it&rsquo;s ready.</p>
            <div className="mt-8 flex w-full justify-center"><WaitlistForm dark /></div>
            <p className="mt-4 text-xs text-on-dark-muted">A signup confirmation, then a launch email. No newsletter.</p>
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
