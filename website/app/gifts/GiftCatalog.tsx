"use client";

import Image from "next/image";
import { useState } from "react";
import products from "./products.json";

const categories = ["All types", ...new Set(products.map(p => p.category))];
const pesos = (value: number) => new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP", maximumFractionDigits: 0 }).format(value);

export default function GiftCatalog() {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All types");
  const [recipient, setRecipient] = useState("All");
  const [budget, setBudget] = useState(0);
  const filtered = products.filter(p =>
    `${p.name} ${p.merchant} ${p.category}`.toLowerCase().includes(query.trim().toLowerCase()) &&
    (category === "All types" || p.category === category) &&
    (recipient === "All" || p.recipients.includes(recipient)) &&
    (!budget || (p.priceMax ?? p.price) <= budget));
  const reset = () => { setQuery(""); setCategory("All types"); setRecipient("All"); setBudget(0); };

  return <section aria-label="Gift collection" className="mt-10">
    <div className="grid gap-4 rounded-3xl border border-border-soft bg-surface p-5 sm:grid-cols-2 lg:grid-cols-4">
      <label className="text-sm font-semibold">Search gifts<input type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Flowers, mugs, coffee…" className="mt-2 min-h-12 w-full rounded-xl border border-border-soft bg-background px-3 text-base font-normal" /></label>
      <label className="text-sm font-semibold">Gift type<select value={category} onChange={e => setCategory(e.target.value)} className="mt-2 min-h-12 w-full rounded-xl border border-border-soft bg-background px-3 text-base font-normal">{categories.map(c => <option key={c}>{c}</option>)}</select></label>
      <label className="text-sm font-semibold">For whom<select value={recipient} onChange={e => setRecipient(e.target.value)} className="mt-2 min-h-12 w-full rounded-xl border border-border-soft bg-background px-3 text-base font-normal">{["All", "Partner", "Family", "Friends"].map(r => <option key={r}>{r}</option>)}</select></label>
      <label className="text-sm font-semibold">Budget<select value={budget} onChange={e => setBudget(Number(e.target.value))} className="mt-2 min-h-12 w-full rounded-xl border border-border-soft bg-background px-3 text-base font-normal"><option value={0}>Any budget</option>{[200,500,1000].map(b => <option key={b} value={b}>Up to {pesos(b)}</option>)}</select></label>
    </div>
    <div className="my-6 flex items-center justify-between gap-4"><p role="status" className="text-sm text-body">{filtered.length} {filtered.length === 1 ? "gift idea" : "gift ideas"}</p><button onClick={reset} className="min-h-11 text-sm font-semibold text-brand-dark underline underline-offset-4">Clear filters</button></div>
    {filtered.length === 0 ? <div className="rounded-3xl bg-surface-subtle p-8 text-center"><h2 className="text-xl font-bold">No gifts match just yet.</h2><p className="mt-3 text-body">Try another gift type, search, or budget.</p></div> :
      <div className="grid grid-cols-1 gap-5 min-[360px]:grid-cols-2 lg:grid-cols-3">
        {filtered.map(p => <article key={p.id} className="flex min-w-0 flex-col overflow-hidden rounded-3xl border border-border-soft bg-surface">
          <div className="relative aspect-square bg-white"><Image src={p.image} alt={p.name} fill sizes="(max-width: 359px) 90vw, (max-width: 1023px) 45vw, 320px" className="object-contain" /></div>
          <div className="flex flex-1 flex-col p-4 sm:p-6">
            <p className="text-xs font-bold text-brand-dark">{p.category}</p><h2 className="mt-2 text-lg font-bold leading-snug">{p.name}</h2><p className="mt-2 text-sm text-body">{p.merchant}</p>
            <p className="mt-4 font-bold">{pesos(p.price)}{p.priceMax ? ` to ${pesos(p.priceMax)}` : ""}</p>{p.voucher && <p className="text-xs text-muted">After voucher</p>}
            <a href={p.url} target="_blank" rel="noopener noreferrer" aria-label={`View ${p.name} on Shopee (opens in a new tab)`} className="mt-5 flex min-h-12 items-center justify-center rounded-full bg-[#733952] px-3 py-2 text-center text-sm font-bold text-white hover:bg-[#592a40]">Open Shopee ↗</a>
          </div>
        </article>)}
      </div>}
  </section>;
}
