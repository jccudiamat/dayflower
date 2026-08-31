import Link from "next/link";
import WaitlistForm from "./components/WaitlistForm";
import { Card, SectionLabel, Tag, TickList, TwoToneHeading } from "./components/ui";
import {
  boothTemplates,
  competitors,
  coreFeatures,
  dayInTheLife,
  flowers,
  freeTier,
  niceToHaves,
  onboardingSteps,
  premiumTier,
  principles,
  roadmap,
  screens,
} from "./lib/content";

export default function Home() {
  return (
    <div className="min-h-screen">
      {/* ── Nav ─────────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-50 border-b border-border-soft bg-bg/85 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-5">
          <a href="#top" className="flex shrink-0 items-center gap-2 text-lg font-bold">
            <span aria-hidden>🌷</span> Dayflower
          </a>
          <nav className="hidden items-center gap-6 text-sm font-semibold text-body lg:flex">
            <a href="#concept" className="hover:text-ink">Concept</a>
            <a href="#features" className="hover:text-ink">Features</a>
            <a href="#tour" className="hover:text-ink">App tour</a>
            <a href="#pricing" className="hover:text-ink">Pricing</a>
            <a href="#roadmap" className="hover:text-ink">Roadmap</a>
          </nav>
          <a href="#waitlist" className="gradient-button !h-10 !px-5 text-sm">
            Join the waitlist
          </a>
        </div>
      </header>

      <main id="top">
        {/* ── Hero ──────────────────────────────────────────────────────── */}
        <section className="bg-dark-canvas text-on-dark">
          <div className="mx-auto grid max-w-6xl items-center gap-14 px-5 py-20 sm:py-28 lg:grid-cols-[1.1fr_0.9fr]">
            <div>
              <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-dark-border bg-dark-surface px-4 py-1.5 text-xs font-semibold text-on-dark-muted">
                For long-distance couples · iOS &amp; Android
              </p>
              <h1 className="text-4xl font-bold leading-tight sm:text-5xl">
                One flower a day,
                <br />
                <span className="gradient-text">across any distance.</span>
              </h1>
              <p className="mt-5 max-w-md text-[15.5px] leading-relaxed text-on-dark-muted">
                Dayflower isn&rsquo;t a messaging app. It&rsquo;s a ritual app — one
                primary gesture per day, done with intention. Exchange a tulip
                with a note, send heartbeats they can feel, and count down to the
                next time you&rsquo;re in the same room.
              </p>
              <div className="mt-8" id="waitlist">
                <WaitlistForm dark />
                <p className="mt-3 pl-1 text-xs text-on-dark-muted">
                  Free at launch. One email when it&rsquo;s ready — nothing else.
                </p>
              </div>
            </div>

            {/* Nest preview — mirrors the in-app dashboard */}
            <div className="mx-auto w-full max-w-sm">
              <div className="float-soft rounded-[24px] border border-dark-border bg-dark-surface p-6">
                <div className="flex items-baseline justify-between">
                  <p className="text-sm font-bold">Evening, Bunny 🌷</p>
                  <p className="text-xs text-on-dark-muted">Day 42</p>
                </div>
                <p className="mt-1 text-xs text-on-dark-muted">
                  Sunshine · 14:08 in London
                </p>

                <div className="mt-5 flex flex-col items-center rounded-[18px] bg-dark-raised px-6 pb-6 pt-7 text-center">
                  <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-on-dark-muted">
                    Today&rsquo;s Dayflower
                  </p>
                  <div className="mt-4 flex h-20 w-20 items-center justify-center rounded-t-full rounded-b-[18px] bg-dark-canvas text-4xl">
                    🌷
                  </div>
                  <p className="mt-3 text-base font-bold">Classic Tulip</p>
                  <p className="note text-sm text-on-dark-muted">
                    Declaration of love
                  </p>
                  <p className="note mt-3 text-[15px] leading-relaxed">
                    &ldquo;Six hours ahead, still thinking of you.&rdquo;
                  </p>
                  <p className="mt-2 text-xs text-on-dark-muted">
                    — Sunshine · ✓ Seen
                  </p>
                </div>

                <div className="mt-3 flex items-center justify-between rounded-full bg-dark-raised px-5 py-3">
                  <span className="text-sm font-semibold">Tapped 5× today</span>
                  <span className="pulse-ring relative flex h-9 w-9 items-center justify-center rounded-full bg-dark-canvas text-lg">
                    💓
                  </span>
                </div>

                <div className="mt-3 grid grid-cols-3 gap-2 text-center">
                  {[
                    ["42", "streak"],
                    ["1.2k", "hearts"],
                    ["87", "days apart"],
                  ].map(([stat, label]) => (
                    <div key={label} className="rounded-[14px] bg-dark-raised px-2 py-3">
                      <p className="text-lg font-bold tabular-nums">{stat}</p>
                      <p className="text-[10px] uppercase tracking-wider text-on-dark-muted">
                        {label}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── Concept & principles ──────────────────────────────────────── */}
        <section id="concept" className="mx-auto max-w-6xl px-5 py-20 sm:py-24">
          <SectionLabel>The concept</SectionLabel>
          <TwoToneHeading lead="Not a feed. Not a thread." accent="A ritual." />
          <p className="mt-4 max-w-2xl text-[15px] leading-relaxed text-body">
            The name plays on <em>tulip</em> and <em>two lips</em> — the flower
            you exchange, and the intimacy of speaking only to each other. Every
            day, partners trade one digital flower carrying a personalized note.
            That single exchange is the whole product. Everything else exists to
            keep you present between them.
          </p>

          <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {principles.map((p) => (
              <Card key={p.title}>
                <span className="text-2xl" aria-hidden>{p.emoji}</span>
                <h3 className="mt-3 text-base font-bold">{p.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-body">{p.text}</p>
              </Card>
            ))}
          </div>
        </section>

        {/* ── Flower language ───────────────────────────────────────────── */}
        <section className="bg-surface-subtle/60 py-20 sm:py-24">
          <div className="mx-auto max-w-6xl px-5">
            <SectionLabel>The flower language</SectionLabel>
            <TwoToneHeading lead="Every variety" accent="means something." />
            <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-body">
              You aren&rsquo;t picking a sticker. Each flower carries a meaning,
              so choosing one is already saying something before you write a word.
            </p>
            <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {flowers.map((f) => (
                <Card key={f.name} className="flex items-center gap-4">
                  <span
                    className="flex h-13 w-13 shrink-0 items-center justify-center rounded-[14px] text-2xl"
                    style={{ backgroundColor: `${f.color}1F` }}
                    aria-hidden
                  >
                    {f.emoji}
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-[15px] font-bold">{f.name}</p>
                    <p className="note truncate text-sm text-muted">{f.meaning}</p>
                  </div>
                </Card>
              ))}
              <Card className="flex items-center justify-center text-center">
                <p className="text-sm leading-relaxed text-muted">
                  Plus rare &amp; seasonal varieties
                  <br />
                  <span className="font-semibold text-secondary-brand">coming with Premium</span>
                </p>
              </Card>
            </div>
          </div>
        </section>

        {/* ── Core features ─────────────────────────────────────────────── */}
        <section id="features" className="mx-auto max-w-6xl px-5 py-20 sm:py-24">
          <SectionLabel>Core features</SectionLabel>
          <TwoToneHeading lead="Small gestures," accent="big closeness." />
          <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-body">
            The six pillars the app is built on — the daily ritual, and everything
            that keeps you close between one flower and the next.
          </p>
          <div className="mt-12 grid gap-5 lg:grid-cols-2">
            {coreFeatures.map((f) => (
              <Card key={f.title} className="flex flex-col">
                <div className="flex items-start justify-between gap-3">
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[14px] bg-surface-subtle text-2xl" aria-hidden>
                    {f.emoji}
                  </span>
                  {f.status && <Tag>{f.status}</Tag>}
                </div>
                <h3 className="mt-4 text-lg font-bold">{f.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-body">{f.summary}</p>
                <div className="mt-4 border-t border-border-soft pt-4">
                  <TickList items={f.points} />
                </div>
              </Card>
            ))}
          </div>
        </section>

        {/* ── App tour ──────────────────────────────────────────────────── */}
        <section id="tour" className="bg-dark-canvas py-20 text-on-dark sm:py-24">
          <div className="mx-auto max-w-6xl px-5">
            <SectionLabel dark>The app, screen by screen</SectionLabel>
            <TwoToneHeading lead="Five tabs and" accent="one daily loop." />
            <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-on-dark-muted">
              Nest · Tulip · Booth · Dates · Us — with the composer and settings
              a tap away. Here&rsquo;s what lives on each one.
            </p>
            <div className="mt-12 grid gap-5 md:grid-cols-2">
              {screens.map((s) => (
                <div
                  key={s.route}
                  className="rounded-[18px] border border-dark-border bg-dark-surface p-6"
                >
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-lg font-bold">{s.name}</h3>
                    <code className="rounded-full bg-dark-raised px-3 py-1 text-[11px] text-on-dark-muted">
                      {s.route}
                    </code>
                  </div>
                  <p className="mt-2 text-sm leading-relaxed text-on-dark-muted">
                    {s.tagline}
                  </p>
                  <ul className="mt-4 space-y-2.5 border-t border-dark-border pt-4 text-sm">
                    {s.points.map((p) => (
                      <li key={p} className="flex gap-2.5">
                        <span className="mt-px shrink-0 text-g-pink" aria-hidden>·</span>
                        <span className="text-on-dark-muted">{p}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Booth templates ───────────────────────────────────────────── */}
        <section className="mx-auto max-w-6xl px-5 py-20 sm:py-24">
          <SectionLabel>Photo booth</SectionLabel>
          <TwoToneHeading lead="Ten templates," accent="one shared album." />
          <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-body">
            Pick a frame, upload one or two photos, write a caption — then wait
            while it develops, because a booth that develops instantly isn&rsquo;t
            a booth.
          </p>
          <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {boothTemplates.map((t) => (
              <Card key={t.n} className="flex gap-4">
                <span
                  className="flex h-16 w-12 shrink-0 items-center justify-center rounded-[10px] border border-border-soft text-lg font-bold"
                  style={{ backgroundColor: t.swatch, color: t.ink }}
                  aria-hidden
                >
                  {t.n}
                </span>
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="text-[15px] font-bold">{t.name}</h3>
                    <span className="rounded-full bg-surface-subtle px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-secondary-brand">
                      {t.type}
                    </span>
                  </div>
                  <p className="mt-1 text-[13px] leading-relaxed text-body">
                    {t.style}
                  </p>
                </div>
              </Card>
            ))}
          </div>
        </section>

        {/* ── A day with Dayflower + onboarding ────────────────────────────── */}
        <section className="bg-surface-subtle/60 py-20 sm:py-24">
          <div className="mx-auto max-w-6xl px-5">
            <SectionLabel>How it feels day to day</SectionLabel>
            <TwoToneHeading lead="A morning gesture," accent="an all-day presence." />
            <div className="mt-12 grid gap-5 lg:grid-cols-[2fr_1fr]">
              <div className="grid gap-4 sm:grid-cols-3">
                {dayInTheLife.map((slot) => (
                  <Card key={slot.time}>
                    <span className="text-2xl" aria-hidden>{slot.emoji}</span>
                    <h3 className="mt-3 text-base font-bold">{slot.time}</h3>
                    <ul className="mt-3 space-y-2 text-sm text-body">
                      {slot.points.map((p) => (
                        <li key={p} className="flex gap-2">
                          <span className="mt-px shrink-0 text-brand" aria-hidden>·</span>
                          <span>{p}</span>
                        </li>
                      ))}
                    </ul>
                  </Card>
                ))}
              </div>
              <Card>
                <h3 className="text-base font-bold">Getting set up</h3>
                <p className="mt-1.5 text-sm text-body">
                  Seven steps, most of them optional.
                </p>
                <ol className="mt-4 space-y-3 border-t border-border-soft pt-4 text-sm text-body">
                  {onboardingSteps.map((step, i) => (
                    <li key={step} className="flex gap-3">
                      <span className="gradient-text shrink-0 font-bold tabular-nums">
                        {String(i + 1).padStart(2, "0")}
                      </span>
                      <span>{step}</span>
                    </li>
                  ))}
                </ol>
              </Card>
            </div>
          </div>
        </section>

        {/* ── Beyond the MVP ────────────────────────────────────────────── */}
        <section className="mx-auto max-w-6xl px-5 py-20 sm:py-24">
          <SectionLabel>Already designed, shipping after launch</SectionLabel>
          <TwoToneHeading lead="Beyond" accent="the first release." />
          <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {niceToHaves.map((n) => (
              <Card key={n.title} className="flex flex-col">
                <div className="flex items-start justify-between gap-2">
                  <span className="text-2xl" aria-hidden>{n.emoji}</span>
                  {n.tag && <Tag>{n.tag}</Tag>}
                </div>
                <h3 className="mt-3 text-[15px] font-bold">{n.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-body">{n.text}</p>
              </Card>
            ))}
          </div>
        </section>

        {/* ── Pricing ───────────────────────────────────────────────────── */}
        <section id="pricing" className="bg-surface-subtle/60 py-20 sm:py-24">
          <div className="mx-auto max-w-6xl px-5">
            <SectionLabel>Pricing</SectionLabel>
            <TwoToneHeading lead="Free to love." accent="Premium to bloom." />
            <div className="mt-12 grid gap-6 lg:grid-cols-2">
              <div className="rounded-[24px] border border-border-soft bg-surface p-8">
                <h3 className="text-xl font-bold">Free</h3>
                <p className="mt-1 text-sm text-body">
                  The full daily ritual, forever free.
                </p>
                <p className="mt-5 text-3xl font-bold">
                  $0
                  <span className="text-base font-semibold text-muted"> / month</span>
                </p>
                <div className="mt-6">
                  <TickList items={freeTier} />
                </div>
              </div>
              <div className="rounded-[24px] bg-dark-canvas p-8 text-on-dark">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-xl font-bold">Dayflower Premium</h3>
                  <span className="rounded-full bg-dark-raised px-3 py-1 text-[11px] font-bold text-on-dark-muted">
                    PER COUPLE
                  </span>
                </div>
                <p className="mt-1 text-sm text-on-dark-muted">
                  One subscription covers both of you.
                </p>
                <p className="mt-5 text-3xl font-bold">
                  $4.99
                  <span className="text-base font-semibold text-on-dark-muted">
                    {" "}/ month
                  </span>
                </p>
                <div className="mt-6">
                  <TickList items={premiumTier} dark />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── Roadmap ───────────────────────────────────────────────────── */}
        <section id="roadmap" className="bg-dark-canvas py-20 text-on-dark sm:py-24">
          <div className="mx-auto max-w-6xl px-5">
            <SectionLabel dark>Future builds</SectionLabel>
            <TwoToneHeading lead="Where Dayflower" accent="is going next." />
            <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-on-dark-muted">
              Captured so nothing gets lost. These aren&rsquo;t scheduled or
              prioritized yet — they&rsquo;re the shape of what the app wants to
              become.
            </p>
            <div className="mt-12 space-y-10">
              {roadmap.map((group) => (
                <div key={group.group}>
                  <div className="flex items-center gap-3">
                    <span className="text-xl" aria-hidden>{group.emoji}</span>
                    <h3 className="text-lg font-bold">{group.group}</h3>
                    <span className="h-px flex-1 bg-dark-border" />
                  </div>
                  <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    {group.items.map((item) => (
                      <div
                        key={item.name}
                        className="rounded-[18px] border border-dark-border bg-dark-surface p-5"
                      >
                        <div className="flex items-start justify-between gap-2">
                          <h4 className="text-[15px] font-bold">{item.name}</h4>
                          {item.tag && <Tag>{item.tag}</Tag>}
                        </div>
                        <p className="mt-2 text-sm leading-relaxed text-on-dark-muted">
                          {item.text}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Competitive landscape ─────────────────────────────────────── */}
        <section className="mx-auto max-w-6xl px-5 py-20 sm:py-24">
          <SectionLabel>Why Dayflower</SectionLabel>
          <TwoToneHeading lead="Simpler on purpose," accent="and more felt." />
          <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-body">
            Other couple apps ask for more of your time. Dayflower asks for one
            gesture and gives you the rest of the day back.
          </p>
          <div className="mt-10 overflow-x-auto rounded-[18px] border border-border-soft bg-surface">
            <table className="w-full min-w-[640px] border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-border-soft">
                  <th className="px-6 py-4 text-[11px] font-bold uppercase tracking-[0.14em] text-muted">App</th>
                  <th className="px-6 py-4 text-[11px] font-bold uppercase tracking-[0.14em] text-muted">Core feature</th>
                  <th className="px-6 py-4 text-[11px] font-bold uppercase tracking-[0.14em] text-muted">How Dayflower differs</th>
                </tr>
              </thead>
              <tbody>
                {competitors.map((c) => (
                  <tr key={c.app} className="border-b border-border-soft last:border-0">
                    <td className="px-6 py-4 font-bold">{c.app}</td>
                    <td className="px-6 py-4 text-body">{c.core}</td>
                    <td className="px-6 py-4 text-body">{c.diff}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-6 flex flex-wrap gap-2">
            {[
              "Simpler",
              "More ritual",
              "Premium design",
              "Always-visible widgets",
              "Symbolic, not functional",
            ].map((d) => (
              <span
                key={d}
                className="rounded-full border border-border-soft bg-surface px-4 py-2 text-sm font-semibold text-body"
              >
                {d}
              </span>
            ))}
          </div>
        </section>

        {/* ── Final CTA ─────────────────────────────────────────────────── */}
        <section className="bg-dark-canvas py-20 text-on-dark sm:py-24">
          <div className="mx-auto flex max-w-3xl flex-col items-center px-5 text-center">
            <span className="text-4xl" aria-hidden>🌷</span>
            <h2 className="mt-4 text-3xl font-bold leading-tight sm:text-4xl">
              Be first when <span className="gradient-text">Dayflower blooms.</span>
            </h2>
            <p className="note mt-4 max-w-md text-[15.5px] text-on-dark-muted">
              &ldquo;Distance means so little when someone means so much.&rdquo;
            </p>
            <div className="mt-8 flex w-full justify-center">
              <WaitlistForm dark />
            </div>
          </div>
        </section>
      </main>

      {/* ── Footer ────────────────────────────────────────────────────────── */}
      <footer className="border-t border-border-soft">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-5 py-8 text-sm text-muted sm:flex-row">
          <p className="font-semibold">🌷 Dayflower</p>
          <nav className="flex gap-5">
            <Link href="/terms" className="hover:text-ink">Terms</Link>
            <Link href="/privacy" className="hover:text-ink">Privacy</Link>
          </nav>
          <p>© {new Date().getFullYear()} Dayflower</p>
        </div>
      </footer>
    </div>
  );
}
