import Image from "next/image";
import { ChatSnapshot, HomeSnapshot } from "./Snapshots";
import "./snapshots.css";

export default function ProductTour() {
  return (
    <>
      <section className="mx-auto max-w-5xl px-5 pb-16 pt-20 sm:pt-24">
        <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">Inside Dayflower</p>
        <h2 className="mt-5 max-w-2xl text-3xl font-bold leading-tight sm:text-5xl">Close to them.<br />Right on your home screen.</h2>
        <p className="mt-6 max-w-2xl text-base leading-relaxed text-body">Dayflower starts on your home screen. See their My Day photo and send a heart with a tap, without opening the app. Open Dayflower when you want to keep talking, make a call, or plan your next visit.</p>
        <p className="mt-4 text-xs text-muted">Currently in private testing. Screen previews below use illustrative sample content.</p>
        <nav aria-label="Explore app features" className="mt-8 flex flex-wrap gap-3 text-sm font-semibold">
          {[['Home-screen widgets', '#widgets'], ['Connection', '#connection'], ['Daily check-ins', '#check-ins'], ['Plans & memories', '#plans']].map(([label, href]) => <a key={href} href={href} className="rounded-full border border-border-soft bg-surface px-5 py-3 hover:bg-surface-subtle">{label} <span aria-hidden>↗</span></a>)}
        </nav>
      </section>

      <section id="widgets" className="scroll-mt-24 bg-dark-canvas text-on-dark">
        <div className="mx-auto grid max-w-5xl items-center gap-12 px-5 py-20 md:grid-cols-2 md:gap-16">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-g-pink">01 / Widgets first</p>
            <h2 className="mt-5 text-3xl font-bold leading-tight sm:text-4xl">Their day at a glance.<br />Your heart, one tap away.</h2>
            <div className="mt-8 space-y-7">
              <div><h3 className="text-xl font-bold">My Day, on your home screen</h3><p className="mt-3 text-base leading-relaxed text-on-dark-muted">A photo from their day becomes a little window into it. See their shared moment and react from the widget, without opening a conversation.</p></div>
              <div><h3 className="text-xl font-bold">Tap to send a heart</h3><p className="mt-3 text-base leading-relaxed text-on-dark-muted">Keep the heart card beside it. A tap sends your partner a heartbeat in the background. A small “thinking of you,” right where your day already happens.</p></div>
            </div>
            <p className="mt-7 text-xs leading-relaxed text-on-dark-muted">Shown here: the Android home-screen widget experience. Illustrative previews with sample content.</p>
          </div>
          <div className="rounded-[32px] border border-dark-border bg-gradient-to-br from-dark-raised to-dark-surface p-5 sm:p-8">
            <p className="mb-5 text-center text-xs tracking-widest text-on-dark-muted">A LITTLE CLOSER, AT A GLANCE</p>
            <figure className="relative overflow-hidden rounded-3xl">
              <Image src="/flowers/garden_path.webp" alt="Sample My Day widget with a garden photo" width={512} height={512} sizes="(max-width: 768px) 90vw, 430px" className="aspect-[4/3] w-full object-cover" />
              <figcaption className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 to-transparent px-5 pb-5 pt-12"><p className="text-xs font-semibold">Alex · My Day</p><p className="mt-2 text-lg font-semibold">Wish you were on this walk.</p><p className="mt-3 text-xl" aria-label="Example widget reactions">♡ &nbsp; 🥰 &nbsp; ✨</p></figcaption>
            </figure>
            <div className="mt-5 rounded-3xl border border-dark-border bg-dark-canvas p-6 text-center">
              <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-on-dark-muted">Heartbeat</p>
              <p className="my-2 text-5xl text-g-pink" aria-hidden>♥</p>
              <p className="text-lg font-bold">Tap to send a heart</p>
              <p className="mt-2 text-xs text-on-dark-muted">You sent 3 · Alex sent 5</p>
            </div>
            <p className="mt-5 text-center text-[11px] text-on-dark-muted">Widget preview · sample activity</p>
          </div>
        </div>
      </section>

      <section id="connection" className="scroll-mt-24 border-y border-border-soft bg-surface-subtle">
        <div className="mx-auto grid max-w-5xl items-center gap-12 px-5 py-16 sm:py-24 md:grid-cols-2 md:gap-20">
          <div className="order-2 flex flex-col items-center md:order-1">
            <div aria-hidden="true"><ChatSnapshot /></div>
            <p className="mt-6 text-xs text-body">Flowers · illustrative app preview</p>
          </div>
          <div className="order-1 md:order-2">
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">02 / Keep the conversation close</p>
            <h2 className="mt-5 text-3xl font-bold leading-tight sm:text-4xl">A flower.<br />A few words.<br />Their voice.</h2>
            <p className="mt-6 text-base leading-relaxed text-body">Send an illustrated flower with a personal note, then keep talking in your shared conversation. When you want to hear each other, start a voice or video call from the chat.</p>
            <ul className="mt-7 space-y-4 text-sm font-semibold text-body">
              <li>✿ &nbsp; Flowers and personal notes</li>
              <li>↗ &nbsp; Messages and shared photos</li>
              <li>♡ &nbsp; Voice and video calls</li>
            </ul>
          </div>
        </div>
      </section>

      <section id="check-ins" className="mx-auto grid max-w-5xl scroll-mt-24 items-center gap-12 px-5 py-20 sm:py-24 md:grid-cols-2 md:gap-20">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">03 / Be part of their day</p>
          <h2 className="mt-5 text-3xl font-bold leading-tight sm:text-4xl">A check-in can be<br />as small as a tap.</h2>
          <p className="mt-6 text-base leading-relaxed text-body">Share how you’re feeling with a mood check-in. Send a heartbeat when you’re thinking of them. Home brings those small updates together with your partner’s local time and your shared activity.</p>
          <div className="mt-8 grid grid-cols-2 gap-5 border-t border-border-soft pt-6">
            <div><h3 className="font-bold">Mood check-ins</h3><p className="mt-2 text-sm leading-relaxed text-body">Let them know how today feels.</p></div>
            <div><h3 className="font-bold">Heartbeat gestures</h3><p className="mt-2 text-sm leading-relaxed text-body">A little “thinking of you” between conversations.</p></div>
          </div>
        </div>
        <div className="flex flex-col items-center">
          <div aria-hidden="true"><HomeSnapshot /></div>
          <p className="mt-6 text-xs text-body">Home · illustrative app preview</p>
        </div>
      </section>

      <section id="plans" className="scroll-mt-24 bg-dark-canvas text-on-dark">
        <div className="mx-auto max-w-5xl px-5 py-20 sm:py-24">
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-g-pink">04 / Make room for your life together</p>
          <h2 className="mt-5 max-w-xl text-3xl font-bold leading-tight sm:text-4xl">The next visit.<br />The everyday plans.<br />The memories you keep.</h2>
          <p className="mt-6 max-w-xl text-base leading-relaxed text-on-dark-muted">There’s more to a relationship than the conversation. Keep dates, practical plans, and little keepsakes close, too.</p>
          <div className="mt-12 grid gap-5 sm:grid-cols-2">
            {[
              { tag: 'EVENTS', title: 'Count down to being together.', text: 'Keep reunions, birthdays, anniversaries, and other important dates in your Events calendar.' },
              { tag: 'BOOTH & STRIP', title: 'Make a keepsake from your photos.', text: 'Create photo strips with a choice of templates in the app’s photo booth.' },
              { tag: 'REMINDERS & FINANCES', title: 'Give everyday plans a home.', text: 'Set reminders and track income, expenses, savings, and investments in dedicated tools.' },
              { tag: 'CHAPTERS', title: 'Remember more than the highlights.', text: 'Set goals at the start of the month and write a review at the end. Build a year of monthly Chapters to look back on.' },
            ].map((feature) => <article key={feature.tag} className="rounded-2xl border border-dark-border bg-dark-surface p-7 sm:p-8"><p className="text-[10px] font-bold tracking-[0.16em] text-g-pink">{feature.tag}</p><h3 className="mt-5 text-xl font-bold">{feature.title}</h3><p className="mt-3 text-sm leading-relaxed text-on-dark-muted">{feature.text}</p></article>)}
          </div>
        </div>
      </section>
    </>
  );
}
