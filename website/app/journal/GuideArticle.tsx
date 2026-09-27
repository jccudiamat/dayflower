import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "../components/SiteHeader";
import { JsonLd, breadcrumbs, openGraph, ORGANISATION, url } from "../lib/seo";
import { guideDate, guides, type GuideSlug } from "./guides";

export function guideMetadata(slug: GuideSlug): Metadata {
  const guide = guides[slug];
  return { title: `${guide.title} | Dayflower`, description: guide.description, alternates: { canonical: url(`/journal/${slug}`) }, openGraph: openGraph({ title: guide.title, description: guide.description, path: `/journal/${slug}`, type: "article", publishedTime: guideDate, modifiedTime: guideDate, authors: ["Dayflower"], image: url(`/journal/${slug}/opengraph-image`) }) };
}

export default function GuideArticle({ slug }: { slug: GuideSlug }) {
  const guide = guides[slug];
  const path = `/journal/${slug}`;
  return <><SiteHeader /><main className="mx-auto max-w-3xl px-5 py-12 sm:py-20"><nav aria-label="Breadcrumb" className="mb-8 text-sm text-brand-dark"><Link href="/journal" className="underline underline-offset-4">Dayflower Journal</Link><span aria-hidden="true"> / </span><span>Practical guides</span></nav><article>
    <header className="border-b border-border-soft pb-8"><h1 className="text-3xl font-bold leading-tight sm:text-5xl">{guide.title}</h1><p className="mt-6 text-lg leading-8 text-body">{guide.intro}</p><p className="mt-5 text-sm text-body">By <Link href="/" className="underline">Dayflower</Link> · <time dateTime={guideDate}>September 27, 2026</time> · {guide.minutes} min read</p><Link href={guide.tool} className="mt-6 inline-flex min-h-12 items-center rounded-full bg-[#754766] px-6 py-3 text-sm font-bold text-white">{guide.action} ↗</Link></header>
    <nav aria-label="In this guide" className="my-8 rounded-2xl border border-border-soft bg-surface p-6"><h2 className="font-bold">In this guide</h2><ul className="mt-4 space-y-3">{guide.sections.map(section => <li key={section.id}><a href={`#${section.id}`} className="text-sm text-brand-dark underline underline-offset-4">{section.title}</a></li>)}</ul></nav>
    {guide.sections.map(section => <section key={section.id} id={section.id} className="scroll-mt-44 border-b border-border-soft py-8"><h2 className="text-2xl font-bold leading-snug">{section.title}</h2>{section.paragraphs.map(p => <p key={p.slice(0, 40)} className="mt-5 leading-8 text-body">{p}</p>)}{"bullets" in section && <ul className="mt-5 space-y-4 rounded-2xl bg-surface p-6">{section.bullets.map(item => <li key={item} className="border-l-2 border-[#dca8bd] pl-4 leading-7 text-body">{item}</li>)}</ul>}</section>)}
    <aside className="mt-10 rounded-2xl bg-surface p-7"><h2 className="text-xl font-bold">Make something together</h2><p className="mt-4 leading-7 text-body">Try our <Link href={guide.tool} className="font-bold text-brand-dark underline">{slug === "digital-bouquet-messages" ? "free digital bouquet creator" : "free online photo booth"}</Link>, or choose one of these <Link href="/journal/long-distance-date-ideas" className="font-bold text-brand-dark underline">seven long-distance date ideas</Link> for your next evening together.</p><p className="mt-4 leading-7 text-body"><Link href={`/journal/${slug === "digital-bouquet-messages" ? "how-to-make-photo-strips" : "digital-bouquet-messages"}`} className="text-brand-dark underline">{slug === "digital-bouquet-messages" ? "Next: how to make photo strips online" : "Next: what to write on a digital bouquet"} →</Link></p></aside>
  </article></main><footer className="mx-auto flex max-w-3xl flex-wrap gap-6 px-5 py-8 text-sm text-body"><Link href="/">Dayflower</Link><Link href="/journal">Journal</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></footer><JsonLd nodes={[
    { "@type": "BlogPosting", "@id": url(`${path}#article`), headline: guide.title, description: guide.description, datePublished: guideDate, dateModified: guideDate, mainEntityOfPage: url(path), url: url(path), image: url(`${path}/opengraph-image`), inLanguage: "en", author: { "@id": ORGANISATION["@id"] }, publisher: { "@id": ORGANISATION["@id"] } },
    breadcrumbs([["Journal", "/journal"], [guide.title, path]]),
  ]} /></>;
}
