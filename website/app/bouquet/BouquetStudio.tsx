"use client";

import { useEffect, useMemo, useRef, useState, type ChangeEvent, type PointerEvent } from "react";
import { ART_URL, HEIGHT, MAX_PHOTOS, MAX_STEMS, WIDTH, arrange, decodeBouquet, encodeBouquet, flowers, hasContents, hitPhoto, hitStem, makeBouquet, papers, photoCount, photoFrames, renderBouquet, validateBouquet, type Bouquet, type Photo, type RenderAssets, type Stem } from "./model";
import { makeCutout, newPhoto, readPhoto } from "./photos";
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
  const [selectedPhoto, setSelectedPhoto] = useState<number>();
  const [photoImages, setPhotoImages] = useState<RenderAssets>({});
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState("");
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
  const fileRef = useRef<HTMLInputElement>(null);
  const drag = useRef<{ kind: "stem" | "photo"; id: number; startX: number; startY: number; x: number; y: number } | null>(null);
  const active = bouquet.stems.find(s => s.id === selected);
  const photos = useMemo(() => bouquet.photos ?? [], [bouquet.photos]);
  const activePhoto = photos.find(p => p.id === selectedPhoto);
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

  // Photos live in state as data URLs; the canvas needs decoded images. Keyed
  // by src so a re-add of the same photo reuses the decode, and so nothing is
  // dropped while a bouquet is being edited.
  useEffect(() => {
    const missing = photos.map(p => p.src).filter(src => !photoImages[src]);
    if (!missing.length) return;
    let cancelled = false;
    Promise.all(missing.map(async src => {
      const image = new Image();
      image.src = src;
      await image.decode();
      return [src, image] as const;
    })).then(pairs => {
      if (!cancelled) setPhotoImages(current => ({ ...current, ...Object.fromEntries(pairs) }));
    }).catch(() => { if (!cancelled) setPhotoError("A photo could not be opened. Try adding it again."); });
    return () => { cancelled = true; };
  }, [photos, photoImages]);

  useEffect(() => {
    if (!ready || gift || badLink) return;
    const timer = window.setTimeout(() => {
      try { localStorage.setItem(DRAFT_KEY, JSON.stringify(bouquet)); } catch { /* Optional local draft. */ }
    }, 300);
    return () => window.clearTimeout(timer);
  }, [bouquet, ready, gift, badLink]);

  useEffect(() => {
    if (canvasRef.current && art) {
      const editing = !viewing;
      renderBouquet(canvasRef.current, bouquet, art, editing && step === 0 ? selected : undefined,
        photoImages, editing && step === 1 ? selectedPhoto : undefined);
    }
  }, [art, bouquet, selected, selectedPhoto, photoImages, viewing, opened, step, ready, badLink]);

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
  function updatePhoto(values: Partial<Photo>) {
    update({ ...bouquet, photos: photos.map(photo => photo.id === selectedPhoto ? { ...photo, ...values } : photo) });
  }
  async function addPhoto(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    // Reset first: picking the same file twice must still fire a change event.
    event.target.value = "";
    if (!file || photoCount(bouquet) >= MAX_PHOTOS) return;
    setPhotoBusy(true); setPhotoError("");
    try {
      const src = await readPhoto(file);
      const id = Math.max(0, ...photos.map(p => p.id)) + 1;
      const photo = newPhoto(src, id, photos.length);
      update({ ...bouquet, photos: [...photos, photo] });
      setSelectedPhoto(id); setSelected(undefined);
    } catch (error) {
      setPhotoError(error instanceof Error ? error.message : "That photo could not be added.");
    } finally { setPhotoBusy(false); }
  }
  async function cutOut() {
    if (!activePhoto) return;
    setPhotoBusy(true); setPhotoError("");
    try {
      const src = await makeCutout(activePhoto.src);
      // Frame 2 is Cutout — the only frame that keeps transparency and skips
      // the paper card, so the lifted subject sits among the stems.
      updatePhoto({ src, frame: 2 });
    } catch (error) {
      setPhotoError(error instanceof Error ? error.message : "The background could not be removed.");
    } finally { setPhotoBusy(false); }
  }
  function point(event: PointerEvent<HTMLCanvasElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    return { x: (event.clientX - rect.left) * WIDTH / rect.width, y: (event.clientY - rect.top) * HEIGHT / rect.height };
  }
  function pointerDown(event: PointerEvent<HTMLCanvasElement>) {
    if (viewing || step > 1) return;
    const p = point(event);
    // Photos in front are drawn last, so they are grabbed first; stems come
    // next; photos tucked behind the flowers are the last thing you can catch.
    const front = hitPhoto(photos.filter(photo => photo.layer === "front"), p.x, p.y);
    const stem = front ? undefined : hitStem(bouquet.stems, p.x, p.y);
    const photo = front ?? (stem ? undefined : hitPhoto(photos.filter(item => item.layer === "back"), p.x, p.y));
    setSelected(stem?.id);
    setSelectedPhoto(photo?.id);
    if (photo) { setStep(1); drag.current = { kind: "photo", id: photo.id, startX: p.x, startY: p.y, x: photo.x, y: photo.y }; }
    else if (stem) { setStep(0); drag.current = { kind: "stem", id: stem.id, startX: p.x, startY: p.y, x: stem.x, y: stem.y }; }
    else return;
    event.currentTarget.setPointerCapture(event.pointerId);
  }
  function pointerMove(event: PointerEvent<HTMLCanvasElement>) {
    const moving = drag.current;
    if (!moving) return;
    const p = point(event);
    const x = moving.x + p.x - moving.startX, y = moving.y + p.y - moving.startY;
    // The clamps match validateBouquet, so a dragged piece can never land
    // somewhere a decoded gift link would be rejected for.
    if (moving.kind === "stem") {
      setBouquet(current => ({ ...current, stems: current.stems.map(s => s.id === moving.id ? { ...s, x: Math.round(clamp(x, 220, 500)), y: Math.round(clamp(y, 490, 690)) } : s) }));
    } else {
      setBouquet(current => ({ ...current, photos: (current.photos ?? []).map(item => item.id === moving.id ? { ...item, x: Math.round(clamp(x, 110, 610)), y: Math.round(clamp(y, 190, 570)) } : item) }));
    }
    setShareUrl("");
  }
  // encodeBouquet refuses a bouquet with photos: a data URL cannot ride in a
  // URL fragment. Returning null keeps that refusal a message rather than an
  // uncaught throw out of a click handler.
  function makeLink() {
    try {
      const url = `${window.location.origin}/bouquet#gift=${encodeBouquet(bouquet)}`;
      setShareUrl(url);
      return url;
    } catch (error) {
      setShareUrl("");
      setNotice(error instanceof Error ? error.message : "This bouquet could not be turned into a link.");
      return null;
    }
  }
  async function copyLink() {
    const url = makeLink();
    if (!url) return;
    try { await navigator.clipboard.writeText(url); setNotice("Link copied. Send a little happiness."); }
    catch { setNotice("Select and copy the gift link below."); linkRef.current?.focus(); linkRef.current?.select(); }
  }
  async function shareGift() {
    const url = makeLink();
    if (!url) return;
    if (!navigator.share) { await copyLink(); return; }
    try { await navigator.share({ title: "A bouquet for you · Dayflower", text: "I picked these just for you.", url }); setNotice("Your bouquet is ready to send."); }
    catch (error) { if (!(error instanceof Error && error.name === "AbortError")) setNotice("Sharing is unavailable here. Copy the link below instead."); }
  }
  async function download() {
    if (!art || !hasContents(bouquet)) return;
    setBusy(true); setNotice("");
    try {
      const canvas = document.createElement("canvas");
      renderBouquet(canvas, bouquet, art, undefined, photoImages);
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
    setStep(0); setSelected(undefined); setSelectedPhoto(undefined); setPhotoError(""); update(makeBouquet());
  }

  const artwork = <div className={`bouquet-artwork ${viewing ? "is-gift" : ""}`} style={{ background: papers[bouquet.paper].background }}>
    <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }} onLostPointerCapture={() => { drag.current = null; }} className={!viewing && step <= 1 ? "is-editable" : ""} role="img" aria-label={`Bouquet of ${bouquet.stems.map(s => flowers[s.flower].name).join(", ") || "no flowers yet"}${photoCount(bouquet) ? `, with ${photoCount(bouquet)} photo${photoCount(bouquet) > 1 ? "s" : ""}` : ""}${bouquet.to ? ` for ${bouquet.to}` : ""}. ${bouquet.message}${bouquet.from ? ` From ${bouquet.from}.` : ""}`} />
    {!art && <div className="bouquet-art-loading" role="status">{artError ? <><p>The flowers couldn’t load.</p><button className="bouquet-button" onClick={() => { setArtError(false); setAttempt(n => n + 1); }}>Try again</button></> : "Gathering your flowers…"}</div>}
    {art && !hasContents(bouquet) && <div className="bouquet-empty"><p>A little space for something lovely.</p><span>Choose a flower to begin.</span></div>}
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
      <section className="bouquet-preview" aria-label="Your bouquet preview">{artwork}<p className="bouquet-preview-hint">{step === 0 ? "Your flowers, your way. Tap a bloom to move it." : step === 1 ? "Drag a photo to tuck it in where you like." : "Made by you. Meant for them."}</p></section>
      <section className="bouquet-controls" aria-label="Bouquet creator">
        <div className="bouquet-steps" aria-label="Creation steps">{["Flowers", "Photos", "Your note", "Send love"].map((label, i) => <button key={label} aria-current={step === i ? "step" : undefined} disabled={i > 1 && !hasContents(bouquet)} onClick={() => { setStep(i); setSelected(undefined); setSelectedPhoto(undefined); setNotice(""); }}><span>{i + 1}</span>{label}</button>)}</div>
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
          <button className="bouquet-button primary bouquet-next" disabled={!art || !bouquet.stems.length} onClick={() => { setStep(1); setSelected(undefined); }}>Add a photo <span aria-hidden="true">→</span></button><button className="bouquet-text-button" disabled={!art || !bouquet.stems.length} onClick={() => { setStep(2); setSelected(undefined); }}>Skip to your note</button>
        </div>}
        {step === 1 && <div className="bouquet-panel">
          <div className="bouquet-section-heading"><h2>Tuck in a photo</h2><span>{photoCount(bouquet)}/{MAX_PHOTOS} photos</span></div>
          <p className="bouquet-help">Optional, and lovely. A photo sits among the stems, and it is saved into the image you download.</p>
          <p className="bouquet-photo-note">Photos stay on your device. They are not included in the gift link, so a bouquet with photos is one to download and send yourself.</p>
          <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" className="bouquet-file" onChange={addPhoto} />
          <button className="bouquet-button primary bouquet-photo-add" disabled={photoBusy || photoCount(bouquet) >= MAX_PHOTOS} onClick={() => fileRef.current?.click()}>{photoBusy ? "Working…" : "Choose a photo"}</button>
          {photoCount(bouquet) >= MAX_PHOTOS && <p className="bouquet-help">That is all the photos this bouquet can hold.</p>}
          {photoError && <p className="bouquet-photo-error" role="alert">{photoError}</p>}
          {photos.length > 0 && <div className="bouquet-photo-list">{photos.map((photo, i) => <button key={photo.id} aria-pressed={selectedPhoto === photo.id} aria-label={`Photo ${i + 1}`} onClick={() => { setSelectedPhoto(photo.id); setSelected(undefined); }}>
            {/* A data URL, already resized to 640px by readPhoto. next/image cannot optimise one. */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={photo.src} alt="" />
          </button>)}</div>}
          {activePhoto && <div className="bouquet-adjust">
            <p>This photo</p>
            <div className="bouquet-frames">{photoFrames.map((frame, i) => <button key={frame} aria-pressed={activePhoto.frame === i} onClick={() => updatePhoto({ frame: i })}>{frame}</button>)}</div>
            {activePhoto.frame === 0 && <label>Caption<input maxLength={35} value={activePhoto.caption} placeholder="a moment to keep" onChange={e => updatePhoto({ caption: e.target.value })} /></label>}
            <label>Left / right<input aria-label="Photo horizontal position" type="range" min={110} max={610} value={activePhoto.x} onChange={e => updatePhoto({ x: +e.target.value })} /></label>
            <label>Up / down<input aria-label="Photo vertical position" type="range" min={190} max={570} value={activePhoto.y} onChange={e => updatePhoto({ y: +e.target.value })} /></label>
            <label>Rotation<input aria-label="Photo rotation" type="range" min={-45} max={45} value={activePhoto.angle} onChange={e => updatePhoto({ angle: +e.target.value })} /></label>
            <label>Size<input aria-label="Photo size" type="range" min={.55} max={1.5} step={.01} value={activePhoto.scale} onChange={e => updatePhoto({ scale: +e.target.value })} /></label>
            <label>Zoom<input aria-label="Photo zoom" type="range" min={1} max={3} step={.01} value={activePhoto.zoom} onChange={e => updatePhoto({ zoom: +e.target.value })} /></label>
            <label>Move across<input aria-label="Photo crop across" type="range" min={0} max={100} value={activePhoto.cropX} onChange={e => updatePhoto({ cropX: +e.target.value })} /></label>
            <label>Move up<input aria-label="Photo crop up and down" type="range" min={0} max={100} value={activePhoto.cropY} onChange={e => updatePhoto({ cropY: +e.target.value })} /></label>
            <div className="bouquet-photo-layer"><span>Sits</span><div>{(["back", "front"] as const).map(layer => <button key={layer} aria-pressed={activePhoto.layer === layer} onClick={() => updatePhoto({ layer })}>{layer === "back" ? "Behind the flowers" : "In front"}</button>)}</div></div>
            <div className="bouquet-photo-actions">
              <button className="bouquet-text-button" disabled={photoBusy} onClick={cutOut}>{photoBusy ? "Working…" : "Lift off the background"}</button>
              <button className="bouquet-text-button" onClick={() => { update({ ...bouquet, photos: photos.filter(item => item.id !== selectedPhoto) }); setSelectedPhoto(undefined); }}>Remove this photo</button>
            </div>
          </div>}
          <button className="bouquet-button primary bouquet-next" disabled={!art || !hasContents(bouquet)} onClick={() => { setStep(2); setSelectedPhoto(undefined); }}>Write a little note <span aria-hidden="true">→</span></button>
          <button className="bouquet-text-button" onClick={() => { setStep(0); setSelectedPhoto(undefined); }}>Back to flowers</button>
        </div>}
        {step === 2 && <div className="bouquet-panel bouquet-note-panel"><p className="bouquet-eyebrow">THE BEST PART IS WHAT YOU SAY</p><h2>A few words, just for them.</h2><p className="bouquet-help">It doesn’t have to be poetry. It just has to be you.</p><label>Their name <span>optional</span><input maxLength={40} value={bouquet.to} placeholder="Someone special" onChange={e => update({ ...bouquet, to: e.target.value })} autoComplete="off" /></label><label>Your note<textarea maxLength={280} rows={5} value={bouquet.message} onChange={e => update({ ...bouquet, message: e.target.value })} placeholder="I saw these and thought of you…" /><small>{bouquet.message.length}/280</small></label><div className="bouquet-note-ideas"><span>A little help finding the words</span>{["Just because you’re you.", "Different places. Still my favorite person.", "You make the ordinary days feel special."].map(text => <button key={text} onClick={() => update({ ...bouquet, message: text })}>{text}</button>)}</div><label>From <span>optional</span><input maxLength={40} value={bouquet.from} placeholder="Your name" onChange={e => update({ ...bouquet, from: e.target.value })} autoComplete="name" /></label><button className="bouquet-button primary bouquet-next" onClick={() => setStep(3)}>Ready to make their day <span aria-hidden="true">→</span></button><button className="bouquet-text-button" onClick={() => setStep(0)}>Back to flowers</button></div>}
        {step === 3 && <div className="bouquet-panel bouquet-send-panel"><span className="bouquet-send-heart" aria-hidden="true">♡</span><p className="bouquet-eyebrow">HAPPINESS, READY FOR DELIVERY</p><h2>Good things are<br />meant to be shared.</h2><p>Send a little surprise. They’ll open your bouquet and the note you tucked inside.</p>{photoCount(bouquet) > 0 && <p className="bouquet-photo-note">Your photos travel in the image, not in a link. Download this bouquet and send the picture — or remove the photos to share a gift link instead.</p>}<button className="bouquet-button primary" disabled={photoCount(bouquet) > 0} onClick={copyLink}>Copy gift link <span aria-hidden="true">↗</span></button><button className="bouquet-button" disabled={photoCount(bouquet) > 0} onClick={shareGift}>Share bouquet</button><div className="bouquet-send-extras"><button onClick={() => { setPreview(true); setOpened(false); setNotice(""); }}>Preview their surprise</button><button className={photoCount(bouquet) > 0 ? "bouquet-emphasis" : undefined} disabled={!art || busy} onClick={download}>{busy ? "Saving…" : "Download image ↓"}</button></div>{shareUrl && <label className="bouquet-link-label">Your gift link<textarea ref={linkRef} readOnly value={shareUrl} rows={2} onFocus={e => e.target.select()} /></label>}<p role="status" className="bouquet-status">{notice}</p><p className="bouquet-link-note">No account needed. Anyone with the full link can open your bouquet and read your note.</p><button className="bouquet-text-button" onClick={() => setStep(2)}>Back to your note</button></div>}
      </section>
    </div>
  </>;
}
