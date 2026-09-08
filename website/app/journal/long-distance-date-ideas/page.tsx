import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../../components/SiteHeader";

const title = "7 long-distance date ideas for a quiet night in";
const description = "Low-pressure long-distance date ideas with simple plans, conversation prompts, and options for busy schedules or different time zones.";
const url = "https://mydayflower.com/journal/long-distance-date-ideas";
export const metadata: Metadata = {
  title: `${title} | Dayflower Journal`, description,
  alternates: { canonical: url },
  openGraph: { title, description, url, type: "article", publishedTime: "2026-09-08", authors: ["Dayflower"] },
};

const ideas = [
  { id: "same-snack", title: "Make the same snack, in different kitchens", time: "20–30 minutes · A little energy", paragraphs: [
    "Choose something both of you already have the ingredients for: toast with a favorite topping, instant noodles, or a mug of hot chocolate. The point is having a small activity in common, so there is no need to match every ingredient or order anything special.",
    "Start your call while you prepare it, then sit down to eat together. Give each version a ridiculous restaurant name. If one of you is having breakfast and the other is winding down, make different meals and keep the shared table.",
  ], prompt: "What would you make me if I turned up at your door tonight?" },
  { id: "photo-strip", title: "Make a photo strip from both sides of the call", time: "15–25 minutes · Something to keep", paragraphs: [
    "Agree on three photo prompts: your face right now, something within arm’s reach, and your most dramatic pretend magazine cover. Each person takes their photos and sends the ones they want to include to the other.",
    "Collect the pictures on one device, arrange them together, and add a caption that only the two of you would understand. You do not need matching backgrounds or perfect lighting. The contrast between your two evenings is part of the memory.",
  ], prompt: "What should we call this very unofficial episode of our lives?" },
  { id: "tiny-tour", title: "Give a tiny tour of your ordinary day", time: "10–15 minutes · Low energy", paragraphs: [
    "Show three things rather than trying to summarize your whole day: the cup you kept refilling, the view from your window, and something you meant to put away. Let your partner ask one question about each.",
    "This works as a short video call, but it can also be three photos with voice notes. Skip anything private at work or anything that includes someone who has not agreed to be photographed. An ordinary detail you chose to share is enough.",
  ], prompt: "Which tiny part of today would have been better with you here?" },
  { id: "listening-party", title: "Trade three songs and their stories", time: "20–30 minutes · A quieter call", paragraphs: [
    "Each choose a song for your mood, a song from your past, and a song you want the other person to hear. Take turns explaining the choice before you listen. You can each play your own copy and count down together; perfect synchronization is optional.",
    "Keep it to three each so choosing tracks does not become homework. If your schedules do not overlap, send the list with one sentence per song and listen when you have a quiet moment. Agree that a reply can wait until the next day.",
  ], prompt: "Where does this song take you when you hear it?" },
  { id: "parallel-evening", title: "Spend half an hour doing your own things together", time: "30 minutes · No performance required", paragraphs: [
    "Read, sketch, fold laundry, or work on separate puzzles while your call stays open. Say what you are about to do, settle in, and check back at the end. There is no obligation to fill every pause with a question.",
    "Agree on the kind of company you both want first. One person expecting a deep conversation while the other plays a game can make an otherwise gentle plan feel disappointing. Try: ‘Would quiet company feel good tonight, or do you want my full attention?’",
  ], prompt: "What is one thing you want to tell me before we say goodnight?" },
  { id: "next-visit", title: "Plan one small moment for your next visit", time: "15–20 minutes · A little daydreaming", paragraphs: [
    "Pick one moment rather than building an entire itinerary: the first breakfast, a walk, or what you will cook on a rainy afternoon. Each bring one suggestion and decide what sounds good to both of you.",
    "If travel dates or money are uncertain, label this a wish list rather than a promise. You can also imagine a day in a fictional city or design your ideal stay-at-home Sunday. Stop if planning brings more pressure than enjoyment tonight.",
  ], prompt: "What ordinary thing are you most looking forward to doing together?" },
  { id: "voice-note", title: "Leave a date for the other person to open later", time: "5–10 minutes each · Different time zones", paragraphs: [
    "When a live call means someone loses sleep, make the date asynchronous. Send one photo, a short voice note, and a question. Give it a theme, such as ‘a little walk with me’ or ‘three good things from Tuesday.’",
    "Let your partner open it when they have time and send their own version back. Decide on a relaxed window, such as sometime over the weekend, instead of watching for a read receipt. This is an invitation to share, not a test of how quickly someone responds.",
  ], prompt: "What would you have pointed out to me if we had been together today?" },
];

export default function Article() {
  return <><SiteHeader />
    <main className="mx-auto max-w-3xl px-5 py-12 sm:py-20">
      <nav aria-label="Breadcrumb" className="mb-8 text-sm text-brand-dark"><Link href="/journal" className="underline underline-offset-4">Dayflower Journal</Link><span aria-hidden="true"> / </span><span>Date ideas</span></nav>
      <article>
        <header className="border-b border-border-soft pb-9">
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">Together, from wherever</p>
          <h1 className="mt-5 text-4xl font-bold leading-tight sm:text-5xl">{title}</h1>
          <p className="mt-6 text-lg leading-relaxed text-body">Some nights, you want time together without another elaborate plan. These dates leave room for tired evenings, small budgets, and the fact that your clocks might not agree.</p>
          <p className="mt-6 text-sm text-muted">By Dayflower · <time dateTime="2026-09-08">September 8, 2026</time> · 6 min read</p>
        </header>
        <section className="py-9" aria-labelledby="before-title">
          <h2 id="before-title" className="text-2xl font-bold">Before you pick a date</h2>
          <p className="mt-4 leading-8 text-body">Ask how much energy you each have and agree on an end time. A lovely twenty-minute call can be enough. Choose one idea, use a calling app you already know, and leave yourselves permission to change the plan.</p>
          <p className="mt-4 leading-8 text-body">If it is late for one of you, start with the voice-note date. If conversation feels hard after a long day, try the snack or quiet-company idea. You do not have to turn every call into a special occasion.</p>
        </section>
        <nav aria-label="In this article" className="rounded-3xl border border-border-soft bg-surface p-6 sm:p-8">
          <h2 className="font-bold">Choose your evening</h2>
          <ol className="mt-4 list-decimal space-y-3 pl-5 text-brand-dark">{ideas.map(idea => <li key={idea.id}><a href={`#${idea.id}`} className="underline underline-offset-4">{idea.title}</a></li>)}</ol>
        </nav>
        {ideas.map((idea, i) => <section key={idea.id} id={idea.id} className="scroll-mt-44 border-b border-border-soft py-9">
          <p className="text-sm font-semibold text-brand-dark">{idea.time}</p>
          <h2 className="mt-3 text-2xl font-bold leading-snug">{i + 1}. {idea.title}</h2>
          {idea.paragraphs.map(paragraph => <p key={paragraph.slice(0, 35)} className="mt-5 leading-8 text-body">{paragraph}</p>)}
          {idea.id === "photo-strip" && <p className="mt-5 leading-8 text-body">You can use the <Link href="/photobooth" className="font-semibold text-brand-dark underline underline-offset-4">free Dayflower photo booth</Link> for this. Choose the couple layout, add both sets of photos on one device, and save the finished PNG. No account is required, and the booth processes photos in your browser. It is not a shared live camera room; exchange your pictures through your usual messaging app first.</p>}
          <p className="mt-5 rounded-2xl bg-surface p-5 leading-relaxed text-body"><strong>A question to try:</strong> “{idea.prompt}”</p>
        </section>)}
        <section className="py-9"><h2 className="text-2xl font-bold">An easy plan for tonight</h2><p className="mt-4 leading-8 text-body">Spend five minutes catching up, fifteen minutes on one activity, and five minutes saying goodbye without rushing. Before you hang up, decide whether you want to do it again or choose something different next time. Keeping the plan small makes it easier to fit into an actual evening.</p></section>
        <aside className="rounded-3xl bg-dark-canvas p-7 text-on-dark sm:p-9"><h2 className="text-2xl font-bold">Keep a little piece of tonight.</h2><p className="my-5 leading-relaxed text-on-dark-muted">Make a photo strip you can both save. Dayflower’s photo booth is free to use now; our private app for two is still in testing.</p><Link href="/photobooth" className="gradient-button">Make a photo strip</Link><p className="mt-5 text-sm"><Link href="/#waitlist" className="underline underline-offset-4">Join the app waitlist</Link></p></aside>
      </article>
    </main>
    <footer className="mx-auto flex max-w-3xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/journal">Journal</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({ "@context": "https://schema.org", "@type": "BlogPosting", headline: title, description, datePublished: "2026-09-08", dateModified: "2026-09-08", mainEntityOfPage: url, author: { "@type": "Organization", name: "Dayflower", url: "https://mydayflower.com" }, publisher: { "@type": "Organization", name: "Dayflower", logo: { "@type": "ImageObject", url: "https://mydayflower.com/mark.png" } } }) }} />
  </>;
}
