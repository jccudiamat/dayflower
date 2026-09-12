"use client";

import { useEffect, useRef, useState, type PointerEvent } from "react";
import { ART_URL, HEIGHT, MAX_STEMS, WIDTH, arrange, decodeBouquet, encodeBouquet, flowers, hitStem, makeBouquet, papers, renderBouquet, validateBouquet, type Bouquet, type Stem } from "./model";
import "./bouquet.css";

const DRAFT_KEY = "dayflower-bouquet-v1";
const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));

function Sprite({ index, className = "" }: { index: number; className?: string }) {
  return <span aria-hidden="true" className={`bouquet-sprite ${className}`} style={{ backgroundPosition: `${index % 4 * 100 / 3}% ${Math.floor(index / 4) * 100}%` }} />;
}

export default function BouquetStudio() {
  const [bouquet, setBouquet] = useState<Bouquet>(makeBouquet);
  const [ready, setReady] = useState(false);
  const [art, setArt] = useState<HTMLImageElement | null>(null);
  const [artError, setArtError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const [step, setStep] = useState(0);
  const [selected, setSelected] = useState<number>();
  const [gift, setGift] = useState(false);
  const [preview, setPreview] = useState(false);
  const [opened, setOpened] = useState(false);
  const [badLink, setBadLink] = useState(false);
  const [notice, setNotice] = useState("");
  const [shareUrl, setShareUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const linkRef = useRef<HTMLTextAreaElement>(null);
  const revealRef = useRef<HTMLHeadingElement>(null);
  const drag = useRef<{ id: number; startX: number; startY: number; x: number; y: number } | null>(null);
  const active = bouquet.stems.find(s => s.id === selected);
  const viewing = gift || preview;

  useEffect(() => {
    let cancelled = false;
    function loadLocation() {
      if (cancelled) return;
      const hash = window.location.hash;
      if (hash) {
        const loaded = hash.startsWith("#gift=") ? decodeBouquet(hash.slice(6)) : null;
        if (loaded) { setBouquet(loaded); setGift(true); setBadLink(false); setOpened(false); }
        else { setBadLink(true); setGift(false); }
      } else {
        setGift(false); setBadLink(false);
        try {
          const stored = localStorage.getItem(DRAFT_KEY);
          const draft = stored ? validateBouquet(JSON.parse(stored)) : null;
          if (draft) setBouquet(draft);
        } catch { /* Storage may be disabled. The editor still works. */ }
      }
      setReady(true);
    }
    queueMicrotask(loadLocation);
    window.addEventListener("hashchange", loadLocation);
    return () => { cancelled = true; window.removeEventListener("hashchange", loadLocation); };
  }, []);

  useEffect(() => {
    const image = new Image();
    image.onload = () => { setArt(image); setArtError(false); };
    image.onerror = () => setArtError(true);
    image.src = ART_URL;
    return () => { image.onload = null; image.onerror = null; };
  }, [attempt]);

  useEffect(() => {
    if (!ready || gift || badLink) return;
    const timer = window.setTimeout(() => {
      try { localStorage.setItem(DRAFT_KEY, JSON.stringify(bouquet)); } catch { /* Optional local draft. */ }
    }, 300);
    return () => window.clearTimeout(timer);
  }, [bouquet, ready, gift, badLink]);

  useEffect(() => {
    if (canvasRef.current && art) renderBouquet(canvasRef.current, bouquet, art, viewing || step !== 0 ? undefined : selected);
  }, [art, bouquet, selected, viewing, opened, step, ready, badLink]);

  useEffect(() => {
    if (opened) revealRef.current?.focus();
  }, [opened]);

  function update(next: Bouquet) { setBouquet(next); setShareUrl(""); setNotice(""); }
  function updateStem(values: Partial<Stem>) {
    update({ ...bouquet, stems: bouquet.stems.map(stem => stem.id === selected ? { ...stem, ...values } : stem) });
  }
  function addFlower(flower: number) {
    if (bouquet.stems.length >= MAX_STEMS) return;
    const id = Math.max(0, ...bouquet.stems.map(s => s.id)) + 1;
    const stem = { id, flower, x: 360, y: 646, angle: (bouquet.stems.length % 5 - 2) * 13, scale: .94 };
    update({ ...bouquet, stems: [...bouquet.stems, stem] }); setSelected(id);
  }
  function point(event: PointerEvent<HTMLCanvasElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    return { x: (event.clientX - rect.left) * WIDTH / rect.width, y: (event.clientY - rect.top) * HEIGHT / rect.height };
  }
  function pointerDown(event: PointerEvent<HTMLCanvasElement>) {
    if (viewing || step !== 0) return;
    const p = point(event), stem = hitStem(bouquet.stems, p.x, p.y);
    setSelected(stem?.id);
    if (!stem) return;
    drag.current = { id: stem.id, startX: p.x, startY: p.y, x: stem.x, y: stem.y };
    event.currentTarget.setPointerCapture(event.pointerId);
  }
  function pointerMove(event: PointerEvent<HTMLCanvasElement>) {
    const moving = drag.current;
    if (!moving) return;
    const p = point(event);
    setBouquet(current => ({ ...current, stems: current.stems.map(s => s.id === moving.id ? { ...s, x: Math.round(clamp(moving.x + p.x - moving.startX, 220, 500)), y: Math.round(clamp(moving.y + p.y - moving.startY, 490, 690)) } : s) }));
    setShareUrl("");
  }
  function makeLink() {
    const url = `${window.location.origin}/bouquet#gift=${encodeBouquet(bouquet)}`;
    setShareUrl(url);
    return url;
  }
  async function copyLink() {
    const url = makeLink();
    try { await navigator.clipboard.writeText(url); setNotice("Link copied. Send a little happiness."); }
    catch { setNotice("Select and copy the gift link below."); linkRef.current?.focus(); linkRef.current?.select(); }
  }
  async function shareGift() {
    const url = makeLink();
    if (!navigator.share) { await copyLink(); return; }
    try { await navigator.share({ title: "A bouquet for you · Dayflower", text: "I picked these just for you.", url }); setNotice("Your bouquet is ready to send."); }
    catch (error) { if (!(error instanceof Error && error.name === "AbortError")) setNotice("Sharing is unavailable here. Copy the link below instead."); }
  }
  async function download() {
    if (!art || !bouquet.stems.length) return;
    setBusy(true); setNotice("");
    try {
      const canvas = document.createElement("canvas");
      renderBouquet(canvas, bouquet, art);
      const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error("Image export failed")), "image/png"));
      const url = URL.createObjectURL(blob), anchor = document.createElement("a");
      anchor.href = url; anchor.download = "dayflower-bouquet.png";
      document.body.appendChild(anchor); anchor.click(); anchor.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
      setNotice("Your bouquet image is ready. Check your downloads.");
    } catch { setNotice("The image could not be saved. Try again, or copy the gift link."); }
    finally { setBusy(false); }
  }
  function startFresh() {
    window.history.replaceState(null, "", window.location.pathname);
    setGift(false); setPreview(false); setOpened(false); setBadLink(false);
    setStep(0); setSelected(undefined); update(makeBouquet());
  }

  const artwork = <div className={`bouquet-artwork ${viewing ? "is-gift" : ""}`} style={{ background: papers[bouquet.paper].background }}>
    <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }} onLostPointerCapture={() => { drag.current = null; }} className={!viewing && step === 0 ? "is-editable" : ""} role="img" aria-label={`Bouquet of ${bouquet.stems.map(s => flowers[s.flower].name).join(", ") || "no flowers yet"}${bouquet.to ? ` for ${bouquet.to}` : ""}. ${bouquet.message}${bouquet.from ? ` From ${bouquet.from}.` : ""}`} />
    {!art && <div className="bouquet-art-loading" role="status">{artError ? <><p>The flowers couldn’t load.</p><button className="bouquet-button" onClick={() => { setArtError(false); setAttempt(n => n + 1); }}>Try again</button></> : "Gathering your flowers…"}</div>}
    {art && !bouquet.stems.length && <div className="bouquet-empty"><p>A little space for something lovely.</p><span>Choose a flower to begin.</span></div>}
  </div>;

  if (!ready) return <div className="bouquet-loading" role="status">Opening the flower shop…</div>;
  if (badLink) return <section className="bouquet-invalid"><p className="bouquet-eyebrow">DAYFLOWER BOUQUETS</p><h1>This bouquet link is incomplete.</h1><p>Ask the sender to copy and send the whole gift link, including everything after the #.</p><button className="bouquet-button primary" onClick={startFresh}>Make your own bouquet</button></section>;
  if (viewing) return <section className="bouquet-gift">
    {preview && <p className="bouquet-preview-label">A peek at what they’ll see <button onClick={() => { setPreview(false); setOpened(false); }}>Back to editing</button></p>}
    {!opened ? <div className="bouquet-envelope">
      <p className="bouquet-eyebrow">A DELIVERY FROM THE HEART</p>
      <Sprite index={5} className="bouquet-seal-flower" />
      <h1>{bouquet.to.trim() ? `${bouquet.to.trim()}, these are for you.` : "Someone’s thinking of you."}</h1>
      <p>{bouquet.from.trim() ? `${bouquet.from.trim()} picked you a little happiness.` : "A little bouquet, with a lot of love inside."}</p>
      <button className="bouquet-button primary" onClick={() => setOpened(true)}>Open your bouquet <span aria-hidden="true">♡</span></button>
    </div> : <div className="bouquet-revealed"><h1 ref={revealRef} tabIndex={-1}>A little bouquet. A lot of love.</h1>{artwork}<div className="bouquet-gift-actions"><button className="bouquet-button primary" disabled={!art || busy} onClick={download}>{busy ? "Saving…" : "Keep these flowers ↓"}</button><button className="bouquet-button" onClick={preview ? () => { setPreview(false); setOpened(false); } : startFresh}>{preview ? "Back to editing" : "Make one for someone"}</button></div><p className="bouquet-status" role="status">{notice}</p></div>}
  </section>;

  return <>
    <header className="bouquet-heading"><div><p className="bouquet-eyebrow">THE DAYFLOWER FLOWER SHOP</p><h1>A little bouquet.<br className="bouquet-mobile-break" /> <span>A lot of love.</span></h1><p>Pick a few blooms, tuck in a note, and make someone’s day.</p></div><span className="bouquet-free">Free to make & send <span aria-hidden="true">♡</span></span></header>
    <div className="bouquet-studio">
      <section className="bouquet-preview" aria-label="Your bouquet preview">{artwork}<p className="bouquet-preview-hint">{step === 0 ? "Your flowers, your way. Tap a bloom to move it." : "Made by you. Meant for them."}</p></section>
      <section className="bouquet-controls" aria-label="Bouquet creator">
        <div className="bouquet-steps" aria-label="Creation steps">{["Flowers", "Your note", "Send love"].map((label, i) => <button key={label} aria-current={step === i ? "step" : undefined} disabled={i > 0 && !bouquet.stems.length} onClick={() => { setStep(i); setSelected(undefined); setNotice(""); }}><span>{i + 1}</span>{label}</button>)}</div>
        {step === 0 && <div className="bouquet-panel">
          <div className="bouquet-section-heading"><h2>Pick their favorites</h2><span>{bouquet.stems.length}/{MAX_STEMS} stems</span></div>
          <p className="bouquet-help">Tap to add a flower. A little wild looks lovely.</p>
          <div className="bouquet-flower-grid">{flowers.map((flower, i) => <button key={flower.name} className="bouquet-flower" disabled={!art || bouquet.stems.length >= MAX_STEMS} aria-label={`Add ${flower.name}`} onClick={() => addFlower(i)}><Sprite index={i} /><span className="bouquet-flower-name">{flower.name}<span aria-hidden="true">+</span></span><small>{flower.detail}</small></button>)}</div>
          {bouquet.stems.length >= MAX_STEMS && <p className="bouquet-help">A full bunch! Remove a stem to add another.</p>}
          <div className="bouquet-starter"><span>Start with a little inspiration</span><div>{["Soft & sweet", "Love letter", "Pocket sunshine"].map((name, i) => <button key={name} onClick={() => { const next = makeBouquet(i); update({ ...bouquet, stems: next.stems, paper: next.paper }); setSelected(undefined); }}>{name}</button>)}</div></div>
          <fieldset className="bouquet-paper"><legend>Wrap it with love</legend><div>{papers.map((paper, i) => <button key={paper.name} aria-pressed={bouquet.paper === i} onClick={() => update({ ...bouquet, paper: i })}><span style={{ background: paper.background, borderColor: paper.ink }}>{bouquet.paper === i ? "✓" : ""}</span>{paper.name}</button>)}</div></fieldset>
          <details className="bouquet-arrange" open={selected !== undefined ? true : undefined}><summary>Arrange your stems <span>{bouquet.stems.length}</span></summary><div className="bouquet-stem-list">{bouquet.stems.map((stem, i) => <button aria-pressed={selected === stem.id} key={stem.id} onClick={() => setSelected(stem.id)}>{i + 1}. {flowers[stem.flower].name}</button>)}</div>
            {active && <div className="bouquet-adjust"><p>Adjust your {flowers[active.flower].name.toLowerCase()}</p><label>Left / right<input aria-label="Stem horizontal position" type="range" min={220} max={500} value={active.x} onChange={e => updateStem({ x: +e.target.value })} /></label><label>Up / down<input aria-label="Stem vertical position" type="range" min={490} max={690} value={active.y} onChange={e => updateStem({ y: +e.target.value })} /></label><label>Rotation<input aria-label="Stem rotation" type="range" min={-45} max={45} value={active.angle} onChange={e => updateStem({ angle: +e.target.value })} /></label><label>Size<input aria-label="Stem size" type="range" min={.7} max={1.15} step={.01} value={active.scale} onChange={e => updateStem({ scale: +e.target.value })} /></label><button className="bouquet-text-button" onClick={() => { update({ ...bouquet, stems: bouquet.stems.filter(s => s.id !== selected) }); setSelected(undefined); }}>Remove this stem</button></div>}
            <div className="bouquet-arrange-actions"><button onClick={() => { update({ ...bouquet, stems: arrange(bouquet.stems.map(s => s.flower)) }); setSelected(undefined); }}>Arrange for me</button><button disabled={!bouquet.stems.length} onClick={() => { update({ ...bouquet, stems: [] }); setSelected(undefined); }}>Clear flowers</button></div>
          </details>
          <button className="bouquet-button primary bouquet-next" disabled={!art || !bouquet.stems.length} onClick={() => { setStep(1); setSelected(undefined); }}>Write a little note <span aria-hidden="true">→</span></button>
        </div>}
        {step === 1 && <div className="bouquet-panel bouquet-note-panel"><p className="bouquet-eyebrow">THE BEST PART IS WHAT YOU SAY</p><h2>A few words, just for them.</h2><p className="bouquet-help">It doesn’t have to be poetry. It just has to be you.</p><label>Their name <span>optional</span><input maxLength={40} value={bouquet.to} placeholder="Someone special" onChange={e => update({ ...bouquet, to: e.target.value })} autoComplete="off" /></label><label>Your note<textarea maxLength={280} rows={5} value={bouquet.message} onChange={e => update({ ...bouquet, message: e.target.value })} placeholder="I saw these and thought of you…" /><small>{bouquet.message.length}/280</small></label><div className="bouquet-note-ideas"><span>A little help finding the words</span>{["Just because you’re you.", "Different places. Still my favorite person.", "You make the ordinary days feel special."].map(text => <button key={text} onClick={() => update({ ...bouquet, message: text })}>{text}</button>)}</div><label>From <span>optional</span><input maxLength={40} value={bouquet.from} placeholder="Your name" onChange={e => update({ ...bouquet, from: e.target.value })} autoComplete="name" /></label><button className="bouquet-button primary bouquet-next" onClick={() => setStep(2)}>Ready to make their day <span aria-hidden="true">→</span></button><button className="bouquet-text-button" onClick={() => setStep(0)}>Back to flowers</button></div>}
        {step === 2 && <div className="bouquet-panel bouquet-send-panel"><span className="bouquet-send-heart" aria-hidden="true">♡</span><p className="bouquet-eyebrow">HAPPINESS, READY FOR DELIVERY</p><h2>Good things are<br />meant to be shared.</h2><p>Send a little surprise. They’ll open your bouquet and the note you tucked inside.</p><button className="bouquet-button primary" onClick={copyLink}>Copy gift link <span aria-hidden="true">↗</span></button><button className="bouquet-button" onClick={shareGift}>Share bouquet</button><div className="bouquet-send-extras"><button onClick={() => { setPreview(true); setOpened(false); setNotice(""); }}>Preview their surprise</button><button disabled={!art || busy} onClick={download}>{busy ? "Saving…" : "Download image ↓"}</button></div>{shareUrl && <label className="bouquet-link-label">Your gift link<textarea ref={linkRef} readOnly value={shareUrl} rows={2} onFocus={e => e.target.select()} /></label>}<p role="status" className="bouquet-status">{notice}</p><p className="bouquet-link-note">No account needed. Anyone with the full link can open your bouquet and read your note.</p><button className="bouquet-text-button" onClick={() => setStep(1)}>Back to your note</button></div>}
      </section>
    </div>
  </>;
}
