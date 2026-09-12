"use client";

import { useEffect, useMemo, useRef, useState, type ChangeEvent, type FormEvent, type PointerEvent } from "react";
import { ART_URL, DEFAULT_PRINT_OPACITY, EXTRA_ART_URLS, HEIGHT, MAX_PHOTOS, MAX_STEMS, VESSEL_H, VESSEL_W, WIDTH, WRAPPER_URL, WRAP_PIVOT, angleToward, arrange, fitScale, layeredItems, decodeBouquet, encodeBouquet, flowerSprite, flowers, hasContents, hitPhoto, hitStem, makeBouquet, papers, photoCount, photoFrames, photoAngleToward, photoScaleHandle, photoTiltHandle, prints, singleStem, renderBouquet, renderVessel, reorder, stemHandle, stemScaleHandle, topZ, validateBouquet, vessels, type Bouquet, type Photo, type RenderAssets, type Stem } from "./model";
import { makeCutout, newPhoto, readPhoto } from "./photos";
import { SPECIAL_WRAPPER_URL, REVEAL_ART, backgrounds, borders, bouquetColors } from "./model";
import "./bouquet.css";

const DRAFT_KEY = "dayflower-bouquet-v1";
const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));

function Sprite({ index, className = "" }: { index: number; className?: string }) {
  const sprite = flowerSprite(index);
  return <span aria-hidden="true" className={`bouquet-sprite ${className}`} style={{
    backgroundImage: `url('${sprite.url}')`,
    backgroundSize: `400% ${sprite.rows * 100}%`,
    // Percentage background-position is a ratio, not an offset: with N rows the
    // last one sits at 100%, so the step is 100/(N-1), not 100/N.
    backgroundPosition: `${sprite.index % 4 * 100 / 3}% ${Math.floor(sprite.index / 4) * 100 / (sprite.rows - 1)}%`,
  }} />;
}

function VesselView({ bouquet, art, assets, onPickStem }: {
  bouquet: Bouquet; art: HTMLImageElement | null; assets: RenderAssets;
  /** Present only in the editor; the recipient's copy is not adjustable. */
  onPickStem?: (flower: number) => void;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  const swipe = useRef<number | null>(null);
  useEffect(() => { if (ref.current) renderVessel(ref.current, bouquet, art, assets); }, [bouquet, art, assets]);

  const single = (bouquet.vessel ?? 0) === 4 && onPickStem;
  const step = (delta: number) => onPickStem?.((singleStem(bouquet) + delta + flowers.length) % flowers.length);

  const canvas = <canvas ref={ref} width={VESSEL_W} height={VESSEL_H} className="bouquet-vessel-art" role="img"
    aria-label={`${vessels[bouquet.vessel ?? 0].name}${single ? `, showing ${flowers[singleStem(bouquet)].name}` : ""}${bouquet.to.trim() ? `, addressed to ${bouquet.to.trim()}` : ""}`} />;
  if (!single) return canvas;

  return <div className="bouquet-stem-picker">
    <button type="button" className="bouquet-stem-arrow" aria-label="Previous flower" onClick={() => step(-1)}><span aria-hidden="true">‹</span></button>
    <div className="bouquet-stem-swipe"
      onPointerDown={e => { swipe.current = e.clientX; }}
      onPointerUp={e => {
        // A flick either way changes the bloom; anything shorter is a tap and
        // should not move it by accident.
        if (swipe.current === null) return;
        const travel = e.clientX - swipe.current;
        swipe.current = null;
        if (Math.abs(travel) > 30) step(travel < 0 ? 1 : -1);
      }}
      onPointerCancel={() => { swipe.current = null; }}>
      {canvas}
    </div>
    <button type="button" className="bouquet-stem-arrow" aria-label="Next flower" onClick={() => step(1)}><span aria-hidden="true">›</span></button>
    <p className="bouquet-stem-name">{flowers[singleStem(bouquet)].name} <span>Swipe, or use the arrows</span></p>
  </div>;
}

export default function BouquetStudio({ gift: served }: { gift?: Bouquet } = {}) {
  const [bouquet, setBouquet] = useState<Bouquet>(() => served ?? makeBouquet());
  const [ready, setReady] = useState(!!served);
  const [art, setArt] = useState<HTMLImageElement | null>(null);
  const [artError, setArtError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const [step, setStep] = useState(0);
  const [selected, setSelected] = useState<number>();
  const [selectedPhoto, setSelectedPhoto] = useState<number>();
  const [photoImages, setPhotoImages] = useState<RenderAssets>({});
  const [sheets, setSheets] = useState<RenderAssets>({});
  const [lostSheets, setLostSheets] = useState<string[]>([]);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState("");
  const [search, setSearch] = useState("");
  const [gift, setGift] = useState(!!served);
  const [preview, setPreview] = useState(false);
  const [opened, setOpened] = useState(false);
  const [badLink, setBadLink] = useState(false);
  const [notice, setNotice] = useState("");
  const [shareUrl, setShareUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState("");
  const [emailState, setEmailState] = useState<"idle" | "sending" | "sent">("idle");
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const linkRef = useRef<HTMLTextAreaElement>(null);
  const revealRef = useRef<HTMLHeadingElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const drag = useRef<{ kind: "stem" | "photo" | "tilt" | "size" | "photoTilt" | "photoSize"; id: number; startX: number; startY: number; x: number; y: number; grab?: number; from?: number } | null>(null);
  const active = bouquet.stems.find(s => s.id === selected);
  const plain = (text: string) => text.toLowerCase().replace(/[’']/g, "'");
  const matches = useMemo(() => {
    const needle = plain(search.trim());
    // Meanings are searchable too, so "calm" finds Lavender — people remember
    // what a flower is for more often than what it is called.
    return flowers
      .map((flower, i) => ({ flower, i }))
      .filter(({ flower }) => !needle || plain(flower.name).includes(needle) || plain(flower.detail).includes(needle));
  }, [search]);
  const photos = useMemo(() => bouquet.photos ?? [], [bouquet.photos]);
  const activePhoto = photos.find(p => p.id === selectedPhoto);
  const viewing = gift || preview;

  useEffect(() => {
    // A served gift is already decided; there is no hash to read and no draft
    // to restore over the top of someone else's present.
    if (served) return;
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
  }, [served]);

  useEffect(() => {
    const image = new Image();
    image.onload = () => { setArt(image); setArtError(false); };
    image.onerror = () => setArtError(true);
    image.src = ART_URL;
    return () => { image.onload = null; image.onerror = null; };
  }, [attempt]);

  // The wrapper's two layers and the four extra flower sheets. A stem whose
  // sheet has not arrived is skipped by renderBouquet rather than drawn wrong,
  // so these simply fill in as they load.
  useEffect(() => {
    let cancelled = false;
    for (const url of [WRAPPER_URL, SPECIAL_WRAPPER_URL, ...Object.values(REVEAL_ART), ...EXTRA_ART_URLS]) {
      const image = new Image();
      // Clearing the whole list up front would be a synchronous setState in an
      // effect body; retiring each url as it arrives says the same thing and
      // keeps a retry from blanking the warning before it has succeeded.
      image.onload = () => {
        if (cancelled) return;
        setSheets(current => ({ ...current, [url]: image }));
        setLostSheets(current => current.includes(url) ? current.filter(item => item !== url) : current);
      };
      // renderBouquet skips a stem whose sheet is absent *silently*, so a sheet
      // that fails to arrive would otherwise let someone add invisible flowers.
      // Its blooms come out of the picker instead.
      image.onerror = () => { if (!cancelled) setLostSheets(current => current.includes(url) ? current : [...current, url]); };
      image.src = url;
    }
    return () => { cancelled = true; };
  }, [attempt]);

  const assets = useMemo(() => ({ ...sheets, ...photoImages }), [sheets, photoImages]);

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
    if (!ready || gift || badLink || served) return;
    const timer = window.setTimeout(() => {
      try { localStorage.setItem(DRAFT_KEY, JSON.stringify(bouquet)); } catch { /* Optional local draft. */ }
    }, 300);
    return () => window.clearTimeout(timer);
  }, [bouquet, ready, gift, badLink, served]);

  useEffect(() => {
    if (canvasRef.current && art) {
      const editing = !viewing;
      renderBouquet(canvasRef.current, bouquet, art, editing && step === 0 ? selected : undefined,
        assets, editing && step === 1 ? selectedPhoto : undefined);
    }
  }, [art, bouquet, selected, selectedPhoto, assets, viewing, opened, step, ready, badLink]);

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
    const stem = { id, flower, x: 360, y: 646, angle: (bouquet.stems.length % 5 - 2) * 13, scale: .94, z: topZ(bouquet) };
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
      const photo = { ...newPhoto(src, id, photos.length), z: topZ(bouquet) };
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
    const x = (event.clientX - rect.left) * WIDTH / rect.width;
    const y = (event.clientY - rect.top) * HEIGHT / rect.height;
    // renderBouquet shrinks a too-tall arrangement about the tie so nothing is
    // clipped; undo exactly that here, or every drag lands offset from the
    // flower the finger is actually on.
    const fit = fitScale(bouquet);
    if (fit >= 1) return { x, y };
    return {
      x: WRAP_PIVOT.x + (x - WRAP_PIVOT.x) / fit,
      y: WRAP_PIVOT.y + (y - WRAP_PIVOT.y) / fit,
    };
  }
  function pointerDown(event: PointerEvent<HTMLCanvasElement>) {
    if (viewing || step > 1) return;
    const p = point(event);
    // The tilt grip belongs to the stem that is already selected and sits on
    // top of everything, so it gets first refusal on the pointer.
    const near = (h: { x: number; y: number; r: number }) => Math.hypot(p.x - h.x, p.y - h.y) <= h.r;
    if (active && step === 0) {
      if (near(stemHandle(active))) {
        // Remember how far the grip sits from the stem's own heading, so the
        // flower turns with the finger instead of snapping under it.
        drag.current = { kind: "tilt", id: active.id, startX: p.x, startY: p.y, x: active.x, y: active.y, grab: angleToward(active, p.x, p.y) - active.angle };
        event.currentTarget.setPointerCapture(event.pointerId); return;
      }
      if (near(stemScaleHandle(active))) {
        // Scale rides the ratio of distances from the stem's base, so wherever
        // the grip is grabbed it stays under the finger.
        drag.current = { kind: "size", id: active.id, startX: p.x, startY: p.y, x: active.x, y: active.y, from: active.scale, grab: Math.max(1, Math.hypot(p.x - active.x, p.y - active.y)) };
        event.currentTarget.setPointerCapture(event.pointerId); return;
      }
    }
    if (activePhoto && step === 1) {
      if (near(photoTiltHandle(activePhoto))) {
        drag.current = { kind: "photoTilt", id: activePhoto.id, startX: p.x, startY: p.y, x: activePhoto.x, y: activePhoto.y, grab: photoAngleToward(activePhoto, p.x, p.y) - activePhoto.angle };
        event.currentTarget.setPointerCapture(event.pointerId); return;
      }
      if (near(photoScaleHandle(activePhoto))) {
        drag.current = { kind: "photoSize", id: activePhoto.id, startX: p.x, startY: p.y, x: activePhoto.x, y: activePhoto.y, from: activePhoto.scale, grab: Math.max(1, Math.hypot(p.x - activePhoto.x, p.y - activePhoto.y)) };
        event.currentTarget.setPointerCapture(event.pointerId); return;
      }
    }
    // Topmost first, so what you grab is what you can see. The stack is shared
    // now, so this walks it from the front rather than assuming photos sit in
    // fixed bands around the flowers.
    let stem: Stem | undefined, photo: Photo | undefined;
    for (const item of [...layeredItems(bouquet)].reverse()) {
      if (item.kind === "photo") { const found = hitPhoto([item.photo], p.x, p.y); if (found) { photo = found; break; } }
      else { const found = hitStem([item.stem], p.x, p.y); if (found) { stem = found; break; } }
    }
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
    if (moving.kind === "tilt") {
      setBouquet(current => ({ ...current, stems: current.stems.map(stem => {
        if (stem.id !== moving.id) return stem;
        const angle = angleToward(stem, p.x, p.y) - (moving.grab ?? 0);
        return { ...stem, angle: Math.round(clamp(angle, -45, 45)) };
      }) }));
    } else if (moving.kind === "size") {
      const reach = Math.hypot(p.x - moving.x, p.y - moving.y) / (moving.grab ?? 1);
      setBouquet(current => ({ ...current, stems: current.stems.map(stem =>
        stem.id === moving.id ? { ...stem, scale: +clamp((moving.from ?? 1) * reach, .7, 1.15).toFixed(2) } : stem) }));
    } else if (moving.kind === "photoTilt") {
      setBouquet(current => ({ ...current, photos: (current.photos ?? []).map(photo => {
        if (photo.id !== moving.id) return photo;
        const angle = photoAngleToward(photo, p.x, p.y) - (moving.grab ?? 0);
        return { ...photo, angle: Math.round(clamp(angle, -45, 45)) };
      }) }));
    } else if (moving.kind === "photoSize") {
      const reach = Math.hypot(p.x - moving.x, p.y - moving.y) / (moving.grab ?? 1);
      setBouquet(current => ({ ...current, photos: (current.photos ?? []).map(photo =>
        photo.id === moving.id ? { ...photo, scale: +clamp((moving.from ?? 1) * reach, .55, 1.5).toFixed(2) } : photo) }));
    } else if (moving.kind === "stem") {
      setBouquet(current => ({ ...current, stems: current.stems.map(s => s.id === moving.id ? { ...s, x: Math.round(clamp(x, 220, 500)), y: Math.round(clamp(y, 490, 690)) } : s) }));
    } else {
      setBouquet(current => ({ ...current, photos: (current.photos ?? []).map(item => item.id === moving.id ? { ...item, x: Math.round(clamp(x, 110, 610)), y: Math.round(clamp(y, 190, 570)) } : item) }));
    }
    setShareUrl("");
  }
  /**
   * The shareable link: a short /g/<id> backed by a stored row.
   *
   * It has to be stored. A `#gift=` fragment is never sent to the server, so
   * the crawler behind a chat or mail preview can only ever see the generic
   * page — every gift got an identical card. Storing it is also what lets a
   * bouquet with photos be shared at all, since a data URL was never going to
   * fit in a URL.
   */
  async function makeLink() {
    if (shareUrl) return shareUrl;
    setBusy(true);
    try {
      const res = await fetch("/api/gift", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bouquet }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok || !data?.id) {
        setShareUrl("");
        setNotice(data?.error ?? "This bouquet could not be turned into a link.");
        return null;
      }
      const url = `${window.location.origin}/g/${data.id}`;
      setShareUrl(url);
      return url;
    } catch {
      setShareUrl("");
      setNotice("Couldn’t reach the flower shop. Check your connection and try again.");
      return null;
    } finally { setBusy(false); }
  }
  /** The old link: nothing stored, no preview card, and no photos. */
  function makePrivateLink() {
    try {
      const url = `${window.location.origin}/bouquet#gift=${encodeBouquet(bouquet)}`;
      setShareUrl(url);
      setNotice("Private link ready. Nothing about it is stored.");
      return url;
    } catch (error) {
      setShareUrl("");
      setNotice(error instanceof Error ? error.message : "This bouquet could not be turned into a link.");
      return null;
    }
  }
  async function sendByEmail(event: FormEvent) {
    event.preventDefault();
    if (emailState === "sending") return;
    setEmailState("sending"); setNotice("");
    // The link has to exist before it can be mailed, and makeLink reuses the
    // one already made rather than storing the same bouquet twice.
    const url = await makeLink();
    if (!url) { setEmailState("idle"); return; }
    try {
      const res = await fetch("/api/gift/email", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: url.split("/g/")[1], email }),
      });
      const data = await res.json().catch(() => null);
      if (res.ok) { setEmailState("sent"); setNotice(""); }
      else { setEmailState("idle"); setNotice(data?.error ?? "That didn’t go through. Try again."); }
    } catch {
      setEmailState("idle");
      setNotice("Couldn’t reach the flower shop. Check your connection and try again.");
    }
  }

  /**
   * Hands the gift to the Dayflower app. The website has no session and no
   * idea who anyone's partner is, so it cannot post to a chat itself — it
   * opens the app and leaves the link on the clipboard to paste in.
   */
  async function openInApp() {
    const url = await makeLink();
    if (!url) return;
    try { await navigator.clipboard.writeText(url); } catch { /* The link is on screen either way. */ }
    // Honest about the two halves: the copy always happens, the app opening
    // only does if it is installed.
    setNotice("Link copied. If you have Dayflower, it’s opening now — paste this into your chat.");
    window.location.href = `dayflower://gift/${url.split("/g/")[1]}`;
  }

  async function copyPrivateLink() {
    const url = makePrivateLink();
    if (!url) return;
    try { await navigator.clipboard.writeText(url); setNotice("Private link copied. Nothing about it is stored."); }
    catch { linkRef.current?.focus(); linkRef.current?.select(); }
  }
  async function copyLink() {
    const url = await makeLink();
    if (!url) return;
    try { await navigator.clipboard.writeText(url); setNotice("Link copied. Send a little happiness."); }
    catch { setNotice("Select and copy the gift link below."); linkRef.current?.focus(); linkRef.current?.select(); }
  }
  async function shareGift() {
    const url = await makeLink();
    if (!url) return;
    if (!navigator.share) { await copyLink(); return; }
    // Nothing here names what is inside, for the same reason as the card.
    try { await navigator.share({ title: "A little something, just for you", text: "I made you something. Open it when you have a minute.", url }); setNotice("Your bouquet is ready to send."); }
    catch (error) { if (!(error instanceof Error && error.name === "AbortError")) setNotice("Sharing is unavailable here. Copy the link below instead."); }
  }
  async function download() {
    if (!art || !hasContents(bouquet)) return;
    setBusy(true); setNotice("");
    try {
      const canvas = document.createElement("canvas");
      renderBouquet(canvas, bouquet, art, undefined, assets);
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

  const artwork = <div className={`bouquet-artwork ${viewing ? "is-gift" : ""}`} style={{ background: bouquetColors(bouquet).color }}>
    <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }} onLostPointerCapture={() => { drag.current = null; }} className={!viewing && step <= 1 ? "is-editable" : ""} role="img" aria-label={`Bouquet of ${bouquet.stems.map(s => flowers[s.flower].name).join(", ") || "no flowers yet"}${photoCount(bouquet) ? `, with ${photoCount(bouquet)} photo${photoCount(bouquet) > 1 ? "s" : ""}` : ""}${bouquet.to ? ` for ${bouquet.to}` : ""}. ${bouquet.message}${bouquet.from ? ` From ${bouquet.from}.` : ""}`} />
    {!art && <div className="bouquet-art-loading" role="status">{artError ? <><p>The flowers couldn’t load.</p><button className="bouquet-button" onClick={() => { setArtError(false); setAttempt(n => n + 1); }}>Try again</button></> : "Gathering your flowers…"}</div>}
    {art && !hasContents(bouquet) && <div className="bouquet-empty"><p>A little space for something lovely.</p><span>Choose a flower to begin.</span></div>}
  </div>;

  if (!ready) return <div className="bouquet-loading" role="status">Opening the flower shop…</div>;
  if (badLink) return <section className="bouquet-invalid"><p className="bouquet-eyebrow">DAYFLOWER BOUQUETS</p><h1>This bouquet link is incomplete.</h1><p>Ask the sender to copy and send the whole gift link, including everything after the #.</p><button className="bouquet-button primary" onClick={startFresh}>Make your own bouquet</button></section>;
  if (viewing) return <section className="bouquet-gift">
    {preview && <p className="bouquet-preview-label">A peek at what they’ll see <button onClick={() => { setPreview(false); setOpened(false); }}>Back to editing</button></p>}
    {!opened ? <div className={`bouquet-envelope vessel-${bouquet.vessel ?? 0}`} style={{ background: bouquetColors(bouquet).color, color: bouquetColors(bouquet).ink }}>
      <p className="bouquet-eyebrow">A DELIVERY FROM THE HEART</p>
      <VesselView bouquet={bouquet} art={art} assets={assets} />
      <h1>{bouquet.to.trim() ? `${bouquet.to.trim()}, these are for you.` : "Someone’s thinking of you."}</h1>
      <p>{bouquet.from.trim() ? `${bouquet.from.trim()} picked you a little happiness.` : "A little bouquet, with a lot of love inside."}</p>
      <button className="bouquet-button primary" onClick={() => setOpened(true)}>Open your bouquet <span aria-hidden="true">♡</span></button>
    </div> : <div className="bouquet-revealed"><h1 ref={revealRef} tabIndex={-1}>A little bouquet. A lot of love.</h1>{artwork}<div className="bouquet-gift-actions"><button className="bouquet-button primary" disabled={!art || busy} onClick={download}>{busy ? "Saving…" : "Keep these flowers ↓"}</button><button className="bouquet-button" onClick={preview ? () => { setPreview(false); setOpened(false); } : startFresh}>{preview ? "Back to editing" : "Make one for someone"}</button></div><p className="bouquet-status" role="status">{notice}</p></div>}
  </section>;

  return <>
    <header className="bouquet-heading"><div><p className="bouquet-eyebrow">THE DAYFLOWER FLOWER SHOP</p><h1>A little bouquet.<br className="bouquet-mobile-break" /> <span>A lot of love.</span></h1><p>Pick a few blooms, tuck in a note, and make someone’s day.</p></div><span className="bouquet-free">Free to make & send <span aria-hidden="true">♡</span></span></header>
    <div className="bouquet-studio">
      <section className="bouquet-preview" aria-label="Your bouquet preview">{artwork}<p className="bouquet-preview-hint">{step === 0 ? "Tap a bloom to pick it up. Drag the flower to move it, or its little dial to tilt it." : step === 1 ? "Drag a photo to tuck it in where you like." : "Made by you. Meant for them."}</p></section>
      <section className="bouquet-controls" aria-label="Bouquet creator">
        <div className="bouquet-steps" aria-label="Creation steps">{["Flowers", "Photos", "Your note", "Send love"].map((label, i) => <button key={label} aria-current={step === i ? "step" : undefined} disabled={i > 1 && !hasContents(bouquet)} onClick={() => { setStep(i); setSelected(undefined); setSelectedPhoto(undefined); setNotice(""); }}><span>{i + 1}</span>{label}</button>)}</div>
        {step === 0 && <div className="bouquet-panel">
          <div className="bouquet-section-heading"><h2>Pick their favorites</h2><span>{bouquet.stems.length}/{MAX_STEMS} stems</span></div>
          <p className="bouquet-help">Tap to add a flower. A little wild looks lovely.</p>
          <div className="bouquet-search">
            <label htmlFor="bouquet-flower-search" className="bouquet-visually-hidden">Search flowers</label>
            <input id="bouquet-flower-search" type="search" value={search} placeholder="Search 54 flowers — try “rose” or “calm”"
              onChange={e => setSearch(e.target.value)} autoComplete="off" />
            {search && <button className="bouquet-search-clear" aria-label="Clear search" onClick={() => setSearch("")}>×</button>}
          </div>
          {matches.length === 0
            ? <p className="bouquet-help">Nothing by that name. Try another word, or <button className="bouquet-text-button" onClick={() => setSearch("")}>show them all</button>.</p>
            : <div className="bouquet-flower-grid" role="group" aria-label={`${matches.length} flowers, scroll sideways for more`}>
                {matches.map(({ flower, i }) => <button key={flower.name} className="bouquet-flower" disabled={!art || bouquet.stems.length >= MAX_STEMS || lostSheets.includes(flowerSprite(i).url)} aria-label={`Add ${flower.name}`} onClick={() => addFlower(i)}><Sprite index={i} /><span className="bouquet-flower-name">{flower.name}<span aria-hidden="true">+</span></span><small>{flower.detail}</small></button>)}
              </div>}
          {/* Three rows fit about three columns on a phone, so anything past
              nine is off-screen and worth mentioning. Fewer than that needs no
              instruction, and saying "swipe" when there is nowhere to swipe
              just makes the control look broken. */}
          {matches.length > 0 && <p className="bouquet-grid-hint">{search ? `${matches.length} of ${flowers.length}` : `All ${flowers.length} flowers`}{matches.length > 9 ? " · swipe sideways for more" : ""}</p>}
          {bouquet.stems.length >= MAX_STEMS && <p className="bouquet-help">A full bunch! Remove a stem to add another.</p>}
          {lostSheets.length > 0 && <p className="bouquet-help">Some flowers couldn’t load just now. <button className="bouquet-text-button" onClick={() => setAttempt(n => n + 1)}>Try again</button></p>}
          <div className="bouquet-starter"><span>Start with a little inspiration</span><div>{["Soft & sweet", "Love letter", "Pocket sunshine"].map((name, i) => <button key={name} onClick={() => { const next = makeBouquet(i); update({ ...bouquet, stems: next.stems, paper: next.paper }); setSelected(undefined); }}>{name}</button>)}</div></div>
          <fieldset className="bouquet-paper bouquet-wraps"><legend>Wrap it with love</legend><div>{papers.map((paper, i) => {
            const cell = i >= 5 ? (i - 5) * 2 : i === 0 ? 0 : i === 1 ? 2 : i === 3 ? 4 : 6;
            return <button key={paper.name} aria-pressed={bouquet.paper === i} onClick={() => update({ ...bouquet, paper: i })}><span className="bouquet-wrap-thumb" style={{ backgroundColor: paper.background }}>{paper.sprite < 0 ? <span aria-hidden="true">—</span> : [0, 1].map(front => <span aria-hidden="true" key={front} style={{ backgroundImage: `url('${i >= 5 ? SPECIAL_WRAPPER_URL : WRAPPER_URL}')`, backgroundSize: "400% 200%", backgroundPosition: `${(cell + front) % 4 * 100 / 3}% ${Math.floor((cell + front) / 4) * 100}%`, clipPath: i >= 5 && front ? "inset(0 0 0 7%)" : undefined }} />)}</span><strong>{paper.name}</strong></button>;
          })}</div></fieldset>
          {papers[bouquet.paper].sprite >= 0 && <fieldset className="bouquet-paper bouquet-print"><legend>The wrapping</legend>
            <p className="bouquet-help">Size and lean of the paper itself. The flowers stay tucked inside it.</p>
            <label className="bouquet-print-opacity">Size<input aria-label="Wrapper size" type="range" min={.75} max={1.3} step={.01} value={bouquet.wrapScale ?? 1} onChange={e => update({ ...bouquet, wrapScale: +e.target.value })} /></label>
            <label className="bouquet-print-opacity">Lean<input aria-label="Wrapper lean" type="range" min={-20} max={20} value={bouquet.wrapAngle ?? 0} onChange={e => update({ ...bouquet, wrapAngle: +e.target.value })} /></label>
          </fieldset>}
          <fieldset className="bouquet-paper bouquet-background"><legend>Set the mood</legend><p className="bouquet-help">Choose the background separately from your wrapping.</p><div>{backgrounds.map((background, i) => <button key={background.name} aria-pressed={(bouquet.background ?? 0) === i} onClick={() => update({ ...bouquet, background: i })}><span style={{ background: background.color || papers[bouquet.paper].background, color: background.ink || papers[bouquet.paper].ink }}>{(bouquet.background ?? 0) === i ? "✓" : ""}</span>{background.name}</button>)}</div></fieldset>
          <fieldset className="bouquet-paper bouquet-print"><legend>Paper pattern</legend>
            <p className="bouquet-help">A print behind the flowers. Keep it faint and it reads like nice paper.</p>
            <div className="bouquet-print-list">{prints.map((sheet, i) => <button key={sheet.name} aria-pressed={(bouquet.print ?? 0) === i} onClick={() => update({ ...bouquet, print: i })}>{sheet.name}</button>)}</div>
            {(bouquet.print ?? 0) > 0 && <label className="bouquet-print-opacity">How strong<input aria-label="Stationery strength" type="range" min={5} max={100} value={bouquet.printOpacity ?? DEFAULT_PRINT_OPACITY} onChange={e => update({ ...bouquet, printOpacity: +e.target.value })} /></label>}
          </fieldset>
          <fieldset className="bouquet-paper bouquet-print"><legend>A finishing border</legend><div className="bouquet-print-list">{borders.map((border, i) => <button key={border} aria-pressed={(bouquet.border ?? 0) === i} onClick={() => update({ ...bouquet, border: i })}>{border}</button>)}</div></fieldset>
          <details className="bouquet-arrange" open={selected !== undefined ? true : undefined}><summary>Arrange your stems <span>{bouquet.stems.length}</span></summary><div className="bouquet-stem-list">{bouquet.stems.map((stem, i) => <button aria-pressed={selected === stem.id} key={stem.id} onClick={() => setSelected(stem.id)}>{i + 1}. {flowers[stem.flower].name}</button>)}</div>
            {active && <div className="bouquet-adjust"><p>Adjust your {flowers[active.flower].name.toLowerCase()}</p><label>Left / right<input aria-label="Stem horizontal position" type="range" min={220} max={500} value={active.x} onChange={e => updateStem({ x: +e.target.value })} /></label><label>Up / down<input aria-label="Stem vertical position" type="range" min={490} max={690} value={active.y} onChange={e => updateStem({ y: +e.target.value })} /></label><label>Rotation<input aria-label="Stem rotation" type="range" min={-45} max={45} value={active.angle} onChange={e => updateStem({ angle: +e.target.value })} /></label><label>Size<input aria-label="Stem size" type="range" min={.7} max={1.15} step={.01} value={active.scale} onChange={e => updateStem({ scale: +e.target.value })} /></label><div className="bouquet-depth"><span>Depth</span><div><button onClick={() => update(reorder(bouquet, "stem", active.id, -1))}>Send back</button><button onClick={() => update(reorder(bouquet, "stem", active.id, 1))}>Bring forward</button></div></div><button className="bouquet-text-button" onClick={() => { update({ ...bouquet, stems: bouquet.stems.filter(s => s.id !== selected) }); setSelected(undefined); }}>Remove this stem</button></div>}
            <div className="bouquet-arrange-actions"><button onClick={() => { update({ ...bouquet, stems: arrange(bouquet.stems.map(s => s.flower)) }); setSelected(undefined); }}>Arrange for me</button><button disabled={!bouquet.stems.length} onClick={() => { update({ ...bouquet, stems: [] }); setSelected(undefined); }}>Clear flowers</button></div>
          </details>
          <button className="bouquet-button primary bouquet-next" disabled={!art || !bouquet.stems.length} onClick={() => { setStep(1); setSelected(undefined); }}>Add a photo <span aria-hidden="true">→</span></button><button className="bouquet-text-button" disabled={!art || !bouquet.stems.length} onClick={() => { setStep(2); setSelected(undefined); }}>Skip to your note</button>
        </div>}
        {step === 1 && <div className="bouquet-panel">
          <div className="bouquet-section-heading"><h2>Tuck in a photo</h2><span>{photoCount(bouquet)}/{MAX_PHOTOS} photos</span></div>
          <p className="bouquet-help">Optional, and lovely. A photo sits among the stems, and it is saved into the image you download.</p>
          <p className="bouquet-photo-note">Photos travel with your gift link, and they&rsquo;re saved into the image you download. Only the private link can&rsquo;t carry them.</p>
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
            <div className="bouquet-depth"><span>Depth</span><div><button onClick={() => update(reorder(bouquet, "photo", activePhoto.id, -1))}>Send back</button><button onClick={() => update(reorder(bouquet, "photo", activePhoto.id, 1))}>Bring forward</button></div></div>
            <p className="bouquet-help">Moves one step through the flowers. Everything stays tucked inside the wrapper.</p>
            <div className="bouquet-photo-actions">
              <button className="bouquet-text-button" disabled={photoBusy} onClick={cutOut}>{photoBusy ? "Working…" : "Lift off the background"}</button>
              <button className="bouquet-text-button" onClick={() => { update({ ...bouquet, photos: photos.filter(item => item.id !== selectedPhoto) }); setSelectedPhoto(undefined); }}>Remove this photo</button>
            </div>
          </div>}
          <button className="bouquet-button primary bouquet-next" disabled={!art || !hasContents(bouquet)} onClick={() => { setStep(2); setSelectedPhoto(undefined); }}>Write a little note <span aria-hidden="true">→</span></button>
          <button className="bouquet-text-button" onClick={() => { setStep(0); setSelectedPhoto(undefined); }}>Back to flowers</button>
        </div>}
        {step === 2 && <div className="bouquet-panel bouquet-note-panel"><p className="bouquet-eyebrow">THE BEST PART IS WHAT YOU SAY</p><h2>A few words, just for them.</h2><p className="bouquet-help">It doesn’t have to be poetry. It just has to be you.</p><label>Their name <span>optional</span><input maxLength={40} value={bouquet.to} placeholder="Someone special" onChange={e => update({ ...bouquet, to: e.target.value })} autoComplete="off" /></label><label>Your note<textarea maxLength={280} rows={5} value={bouquet.message} onChange={e => update({ ...bouquet, message: e.target.value })} placeholder="I saw these and thought of you…" /><small>{bouquet.message.length}/280</small></label><div className="bouquet-note-ideas"><span>A little help finding the words</span>{["Just because you’re you.", "Different places. Still my favorite person.", "You make the ordinary days feel special."].map(text => <button key={text} onClick={() => update({ ...bouquet, message: text })}>{text}</button>)}</div><label>From <span>optional</span><input maxLength={40} value={bouquet.from} placeholder="Your name" onChange={e => update({ ...bouquet, from: e.target.value })} autoComplete="name" /></label><button className="bouquet-button primary bouquet-next" onClick={() => setStep(3)}>Ready to make their day <span aria-hidden="true">→</span></button><button className="bouquet-text-button" onClick={() => setStep(0)}>Back to flowers</button></div>}
        {step === 3 && <div className="bouquet-panel bouquet-send-panel"><span className="bouquet-send-heart" aria-hidden="true">♡</span><p className="bouquet-eyebrow">HAPPINESS, READY FOR DELIVERY</p><h2>Good things are<br />meant to be shared.</h2><p>Send a little surprise. They’ll open your bouquet and the note you tucked inside.</p>
          <div className="bouquet-vessel">
            <p className="bouquet-eyebrow">HOW IT ARRIVES</p>
            <VesselView bouquet={bouquet} art={art} assets={assets} onPickStem={flower => update({ ...bouquet, stemFlower: flower })} />
            <div className="bouquet-vessel-list bouquet-vessel-gallery">{vessels.map((vessel, i) => <button key={vessel.name} aria-pressed={(bouquet.vessel ?? 0) === i} onClick={() => update({ ...bouquet, vessel: i })}><VesselView bouquet={{ ...bouquet, vessel: i }} art={art} assets={assets} /><span>{vessel.name}</span></button>)}</div>
            <p className="bouquet-help">{vessels[bouquet.vessel ?? 0].blurb}</p>
          </div><button className="bouquet-button primary" disabled={busy} onClick={copyLink}>{busy ? "Wrapping…" : <>Copy gift link <span aria-hidden="true">↗</span></>}</button><button className="bouquet-button" disabled={busy} onClick={shareGift}>Share bouquet</button><form className="bouquet-email" onSubmit={sendByEmail}>
            {emailState === "sent"
              ? <p className="bouquet-email-sent" role="status"><span aria-hidden="true">✉</span> On its way to {email}. They&rsquo;ll see only that you made them something.</p>
              : <><label htmlFor="bouquet-email-field">Or send it straight to their inbox</label>
                <div className="bouquet-email-row">
                  <input id="bouquet-email-field" type="email" required value={email} placeholder="them@example.com" autoComplete="email"
                    disabled={emailState === "sending"} onChange={e => { setEmail(e.target.value); setNotice(""); }} />
                  <button type="submit" className="bouquet-button primary" disabled={emailState === "sending" || !email.trim()}>{emailState === "sending" ? "Sending…" : "Send"}</button>
                </div>
                <p className="bouquet-email-note">We send it once and don&rsquo;t keep the address.</p></>}
          </form>
          <button className="bouquet-button bouquet-in-app" onClick={openInApp}>Send in the Dayflower app</button>
          <div className="bouquet-send-extras"><button onClick={() => { setPreview(true); setOpened(false); setNotice(""); }}>Preview their surprise</button><button disabled={!art || busy} onClick={download}>{busy ? "Saving…" : "Download image ↓"}</button></div>{shareUrl && <label className="bouquet-link-label">Your gift link<textarea ref={linkRef} readOnly value={shareUrl} rows={2} onFocus={e => e.target.select()} /></label>}<p role="status" className="bouquet-status">{notice}</p><p className="bouquet-link-note">No account needed. Anyone with the link can open your bouquet and read your note. The preview they see says only that you made them something — it never gives away what is inside.</p>
          <details className="bouquet-private"><summary>Rather store nothing?</summary><p>This makes a much longer link that carries the whole bouquet inside it. Nothing is saved on our side, but chat apps show no preview for it, and photos can’t travel this way.</p><button className="bouquet-text-button" onClick={copyPrivateLink}>Copy a private link instead</button></details><button className="bouquet-text-button" onClick={() => setStep(2)}>Back to your note</button></div>}
      </section>
    </div>
  </>;
}
