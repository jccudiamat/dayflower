import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import WaitlistForm from "../components/WaitlistForm";
import { JsonLd, faqPage, breadcrumbs, openGraph, ORGANISATION, url } from "../lib/seo";

const title = "Long-Distance Relationship Ideas, Date Nights & Free Tools";
const description =
  "Practical ideas for long-distance couples: date nights that survive a time difference, free ways to send flowers and photos, and gifts that travel. Plus Dayflower, a private app for two.";

export const metadata: Metadata = {
  title: `${title} | Dayflower`,
  description,
  alternates: { canonical: url("/long-distance") },
  openGraph: openGraph({ title, description, path: "/long-distance" }),
};

/**
 * The hub for everything we have about distance.
 *
 * ⚠️ **This is a pillar page, not a doorway page.** The line between the two
 * is whether it answers the question itself or only funnels: a page built to
 * rank for "long distance relationship" and then punt every visitor
 * elsewhere is precisely what Google's doorway-page policy demotes. So the
 * substance lives here (the time-zone maths, what each idea costs in
 * energy) and the links out are offers rather than the point.
 */

const timeGaps = [
  { hours: "1–3 hours apart", plan: "Share an evening. One of you eats dinner while the other has a late snack; neither has to move a meal.", strain: "Easy to keep up most nights." },
  { hours: "4–8 hours apart", plan: "Look for a morning and afternoon or evening overlap. Try one agreed call slot, with voice notes between calls.", strain: "Check work hours and bedtimes before committing to a daily call." },
  { hours: "9+ hours apart", plan: "Try a morning-to-evening call if your schedules allow it. Otherwise leave a photo, a note, or a bouquet for them to open later.", strain: "A weekend call may be easier than a weekday routine." },
];

const ideas = [
  { title: "Send flowers without an address", body: "A digital bouquet arrives as a link, so there is no florist in their city to find, no delivery window, and no asking for an address you may not have. Pick the flowers, tuck in a note, send it in the same chat you always use.", href: "/bouquet", action: "Make a bouquet" },
  { title: "Make one photo out of two evenings", body: "Take your own photos, collect them on one device, and lay them out side by side. Two different kitchens in one strip says more about the week than either picture does alone.", href: "/photobooth", action: "Open the photo booth" },
  { title: "Send something that can actually be delivered", body: "When you do want a parcel to land, it helps to shop where they are rather than where you are. Our picks are Shopee Philippines listings, sorted by who they suit and what they cost.", href: "/gifts", action: "Browse gift ideas" },
  { title: "Have a date that fits a tired Tuesday", body: "Seven plans built for low energy and mismatched clocks, each with a rough time cost and a question to ask if the conversation stalls.", href: "/journal/long-distance-date-ideas", action: "Read the date ideas" },
];

const questions = [
  ["What can long-distance couples actually do together online?", "The plans that last are the small ones: cooking the same snack on a call, trading three songs with the story behind each, or keeping a call open while you both do your own thing. Making something you can both keep, like a photo strip or a bouquet, gives an evening a result, which helps on the nights when neither of you has much to say."],
  ["How do you handle a big time difference?", "Write down each person’s available hours in both local times, including work and sleep. Choose an overlap that suits both of you, and check it again when daylight saving time changes. If there is no comfortable overlap, exchange voice notes or photos and plan a call for another day."],
  ["How can I send flowers to a partner in another country?", "Create a free digital bouquet and share its link in your usual chat. They can open it in a browser without an account or a delivery address. If you want physical flowers instead, compare florists that deliver to their address and check the delivery date and total price."],
  ["Is there an app just for two people?", "Dayflower is one. It is a private space for a couple rather than a social network. Flowers, messages, calls, shared photos and everyday moments, with nobody else in it. It is in private testing, and the waitlist below is how you hear when it opens."],
  ["What if we cannot fit in a date this week?", "Make the plan smaller, or choose another day together. One photo with a short voice note is a way to share a moment without coordinating a live call. Agree on a comfortable reply window so it feels like an invitation rather than another deadline."],
] as const;

export default async function LongDistancePage() {
  return <>
    <SiteHeader />
    <main className="mx-auto max-w-4xl px-5 py-10 sm:py-16">
      <p className="text-xs font-bold uppercase tracking-[0.18em] text-brand-dark">Dayflower · for couples apart</p>
      <h1 className="mt-4 max-w-3xl text-3xl font-bold leading-tight sm:text-5xl">Long-distance relationship ideas for everyday connection.</h1>
      <p className="mt-6 max-w-2xl text-lg leading-relaxed text-body">Most advice for long-distance couples is either a list of grand gestures nobody has the energy for, or a reminder to communicate. This page is the smaller stuff: what to do on an ordinary Tuesday, how to plan around a time difference that is not going to change, and a few free tools for sending something across it.</p>

      <section className="mt-14" aria-labelledby="clock">
        <h2 id="clock" className="text-2xl font-bold sm:text-3xl">Start with the clock, not the ideas</h2>
        <p className="mt-4 max-w-2xl leading-relaxed text-body">Start with the hours you both have available. The same time difference can be easy or awkward depending on work, sleep, and family commitments. Use these starting points to choose a plan you both have room for.</p>
        <div className="mt-7 overflow-x-auto">
          <table className="w-full min-w-[34rem] border-collapse text-left text-sm">
            <thead><tr className="border-b border-border-soft">
              <th scope="col" className="py-3 pr-4 font-bold">Time difference</th>
              <th scope="col" className="py-3 pr-4 font-bold">What tends to work</th>
              <th scope="col" className="py-3 font-bold">What it costs</th>
            </tr></thead>
            <tbody>{timeGaps.map(gap => <tr key={gap.hours} className="border-b border-border-soft align-top">
              <th scope="row" className="py-4 pr-4 font-semibold">{gap.hours}</th>
              <td className="py-4 pr-4 leading-relaxed text-body">{gap.plan}</td>
              <td className="py-4 leading-relaxed text-muted">{gap.strain}</td>
            </tr>)}</tbody>
          </table>
        </div>
        <p className="mt-5 max-w-2xl text-sm leading-relaxed text-muted">A rough guide, not a rule. A night owl and an early riser nine hours apart may overlap more easily than two people on the same schedule three hours apart.</p>
      </section>

      <section className="mt-14" aria-labelledby="ideas">
        <h2 id="ideas" className="text-2xl font-bold sm:text-3xl">Four things you can do this week</h2>
        <div className="mt-7 grid gap-6 sm:grid-cols-2">{ideas.map(idea => <article key={idea.title} className="rounded-3xl border border-border-soft bg-surface p-6 sm:p-7">
          <h3 className="text-lg font-bold leading-snug">{idea.title}</h3>
          <p className="my-4 leading-relaxed text-body">{idea.body}</p>
          <Link href={idea.href} className="font-bold text-brand-dark underline underline-offset-4">{idea.action} →</Link>
        </article>)}</div>
      </section>

      <section className="mt-14 max-w-3xl" aria-labelledby="questions">
        <h2 id="questions" className="text-2xl font-bold sm:text-3xl">Questions people ask</h2>
        <div className="mt-6 divide-y divide-border-soft">{questions.map(([q, a]) => <details key={q} className="py-5">
          <summary className="cursor-pointer font-bold">{q}</summary>
          <p className="mt-3 leading-relaxed text-body">{a}</p>
        </details>)}</div>
      </section>

      <section className="mt-14 rounded-3xl bg-dark-canvas p-8 text-on-dark sm:p-12">
        <h2 className="text-2xl font-bold sm:text-3xl">A private space for the two of you.</h2>
        <p className="my-5 max-w-xl leading-relaxed text-on-dark-muted">Dayflower is an app for exactly two people: flowers, messages, calls, and the small everyday things, with nobody else in it. It is in private testing. Leave your email and we will tell you when it opens.</p>
        <WaitlistForm dark />
        <p className="mt-5 text-sm text-on-dark-muted">A signup confirmation, then a launch email. No newsletter.</p>
      </section>
    </main>
    <footer className="mx-auto flex max-w-4xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/bouquet">Bouquet</Link><Link href="/photobooth">Photo booth</Link><Link href="/gifts">Gifts</Link><Link href="/journal">Journal</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer>
    <JsonLd nodes={[
      { "@type": "WebPage", "@id": url("/long-distance#webpage"), url: url("/long-distance"), name: title, description, inLanguage: "en", about: { "@id": ORGANISATION["@id"] } },
      faqPage(questions),
      breadcrumbs([["Long distance", "/long-distance"]]),
    ]} />
  </>;
}
