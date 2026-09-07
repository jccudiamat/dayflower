"use client";

import { useEffect, useRef, useState } from "react";
import "./booth.css";

import { themes, templates, renderTemplate, type Shot, type Template } from "./templates";

function TemplatePreview({ template, samples }: { template: Template; samples: (Shot | null)[] }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => { if (ref.current) renderTemplate(ref.current, template, samples, 1, template.caption, false, true); }, [template, samples]);
  return <canvas ref={ref} aria-label={`${template.name} example`} />;
}

export default function Booth() {
  const [templateIndex, setTemplateIndex] = useState(0);
  const [category, setCategory] = useState("All templates");
  const [samples, setSamples] = useState<(Shot | null)[]>([]);
  const template = templates[templateIndex];
  const mode = template.id;
  const [theme, setTheme] = useState(0);
  const [caption, setCaption] = useState<string>(templates[0].caption);
  const [mono, setMono] = useState(false);
  const [shots, setShots] = useState<(Shot | null)[]>(Array(9).fill(null));
  const [selected, setSelected] = useState(0);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [camera, setCamera] = useState(false);
  const [opening, setOpening] = useState(false);
  const [exportUrl, setExportUrl] = useState("");
  const [exportFile, setExportFile] = useState<File | null>(null);
  const [exportVersion, setExportVersion] = useState<{ shots: (Shot | null)[]; mode: string; theme: number; caption: string; mono: boolean } | null>(null);
  const [countdown, setCountdown] = useState(0);
  const canvas = useRef<HTMLCanvasElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const stream = useRef<MediaStream | null>(null);
  const active = useRef(true);
  const cameraRequest = useRef(0);
  const count = template.count;
  const filled = shots.slice(0, count).filter(Boolean).length;
  const current = shots[selected];
  const exportValid = exportVersion?.shots === shots && exportVersion.mode === mode && exportVersion.theme === theme && exportVersion.caption === caption && exportVersion.mono === mono;

  function stopCamera() {
    cameraRequest.current++;
    stream.current?.getTracks().forEach(t => t.stop());
    stream.current = null;
    setCamera(false);
    setOpening(false);
    setCountdown(0);
  }
  useEffect(() => {
    active.current = true;
    const hide = () => { if (document.hidden) stopCamera(); };
    document.addEventListener("visibilitychange", hide);
    return () => { active.current = false; stream.current?.getTracks().forEach(t => t.stop()); document.removeEventListener("visibilitychange", hide); };
  }, []);
  useEffect(() => { if (camera && video.current) video.current.srcObject = stream.current; }, [camera]);
  useEffect(() => () => { if (exportUrl) URL.revokeObjectURL(exportUrl); }, [exportUrl]);

  useEffect(() => {
    let cancelled = false;
    const names = ["sunset_shore", "garden_path", "seaside_posy", "mountain_spring", "quiet_woodland", "terrace_tulips", "morning_meadow", "driftwood_posy", "alpine_meadow"];
    void Promise.all(names.map(async name => {
      const image = new Image(); image.src = `/flowers/${name}.webp`;
      try { await image.decode(); return { image, zoom: 1, x: 50, y: 50 }; } catch { return null; }
    })).then(loaded => { if (!cancelled) setSamples(loaded); });
    return () => { cancelled = true; };
  }, []);
  useEffect(() => {
    if (canvas.current) renderTemplate(canvas.current, template, shots, theme, caption, mono);
  }, [template, theme, caption, mono, shots]);

  function chooseTemplate(index: number) {
    setTemplateIndex(index); setSelected(0); setCaption(templates[index].caption);
    setMessage("Template changed. Your photos are kept; adjust the crops to suit the new layout.");
  }

  async function loadFile(file: File): Promise<Shot> {
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) throw new Error("Choose a JPG, PNG, or WebP photo. Convert HEIC photos to JPG first.");
    if (file.size > 20 * 1024 * 1024) throw new Error("Please choose photos smaller than 20 MB each.");
    const url = URL.createObjectURL(file);
    try {
      const im = new Image(); im.src = url; await im.decode();
      // Bound retained decoded image memory and strip original metadata.
      const c = document.createElement("canvas");
      const scale = Math.min(1, 1800 / Math.max(im.width, im.height));
      c.width = Math.round(im.width * scale); c.height = Math.round(im.height * scale);
      c.getContext("2d")!.drawImage(im, 0, 0, c.width, c.height);
      const image = new Image(); image.src = c.toDataURL("image/jpeg", .92); await image.decode();
      return { image, zoom: 1, x: 50, y: 50 };
    } finally { URL.revokeObjectURL(url); }
  }
  async function upload(files: FileList | null) {
    if (!files?.length) return;
    setBusy(true); setMessage("");
    try {
      const loaded: Shot[] = [];
      for (const f of Array.from(files).slice(0, count - selected)) loaded.push(await loadFile(f));
      if (!active.current) return;
      setShots(old => { const next = [...old]; loaded.forEach((s, i) => next[selected + i] = s); return next; });
      setMessage(`Added ${loaded.length} photo${loaded.length === 1 ? "" : "s"}. Adjust the crop below.`);
    } catch (e) { setMessage(e instanceof Error ? e.message : "Could not open that photo."); }
    finally { setBusy(false); }
  }
  async function startCamera() {
    setOpening(true); setMessage("");
    const request = ++cameraRequest.current;
    try {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error("Camera is unavailable in this browser. You can still upload photos.");
      const media = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user", width: { ideal: 1280 } }, audio: false });
      if (!active.current || request !== cameraRequest.current) { media.getTracks().forEach(t => t.stop()); return; }
      stream.current = media; setCamera(true);
    } catch { if (active.current) setMessage("Camera could not start. Allow camera access in your browser, or upload photos instead."); }
    finally { if (active.current) setOpening(false); }
  }
  async function capture() {
    const request = cameraRequest.current;
    for (let n = 3; n > 0; n--) {
      if (!active.current || request !== cameraRequest.current) return;
      setCountdown(n); await new Promise(r => setTimeout(r, 1000));
    }
    setCountdown(0);
    const v = video.current;
    if (request !== cameraRequest.current || !v?.videoWidth) return;
    const c = document.createElement("canvas"); c.width = v.videoWidth; c.height = v.videoHeight;
    const ctx = c.getContext("2d")!; ctx.translate(c.width, 0); ctx.scale(-1, 1); ctx.drawImage(v, 0, 0);
    const image = new Image(); image.src = c.toDataURL("image/jpeg", .92); await image.decode();
    if (!active.current || request !== cameraRequest.current) return;
    setShots(old => { const next = [...old]; next[selected] = { image, zoom: 1, x: 50, y: 50 }; return next; });
    setSelected(Math.min(selected + 1, count - 1)); setMessage("Photo captured. Choose another slot or take the next photo.");
  }
  function crop(key: "zoom" | "x" | "y", value: number) {
    setShots(old => old.map((s, i) => s && i === selected ? { ...s, [key]: value } : s));
  }
  async function prepare() {
    if (filled !== count || !canvas.current) return;
    setBusy(true); setMessage("");
    try {
      const blob = await new Promise<Blob>((resolve, reject) => canvas.current!.toBlob(b => b ? resolve(b) : reject(new Error("Export failed")), "image/png"));
      setExportFile(new File([blob], "dayflower-collage.png", { type: "image/png" }));
      setExportVersion({ shots, mode, theme, caption, mono });
      setExportUrl(URL.createObjectURL(blob)); setMessage("Your image is ready. Download it or choose Share image.");
    } catch { setMessage("Could not create your image. Please try again."); } finally { setBusy(false); }
  }
  async function share() {
    if (!exportFile) return;
    if (!navigator.canShare?.({ files: [exportFile] })) { setMessage("Image sharing isn’t supported here. Download the PNG and share it from your photos or files app."); return; }
    try { await navigator.share({ files: [exportFile], title: "My Dayflower moments" }); }
    catch (e) { if (!(e instanceof Error && e.name === "AbortError")) setMessage("Sharing failed. You can still download your image."); }
  }

  return <>
    <section className="template-library" aria-label="Choose a photo template">
      <div className="template-heading"><div><h2>Find your kind of memory.</h2><p>Choose a design. Bring your own moments.</p></div><span>8 free templates</span></div>
      <div className="template-filters" aria-label="Template categories">{["All templates", "Scrapbook", "Photo dumps", "Booth strips"].map(c => <button key={c} aria-pressed={category === c} onClick={() => setCategory(c)}>{c}</button>)}</div>
      <div className="template-grid">{templates.map((t, i) => (category === "All templates" || category === t.category) && <button className="template-card" key={t.id} aria-pressed={templateIndex === i} disabled={busy || !!countdown} onClick={() => chooseTemplate(i)}>
        <div className="template-art"><TemplatePreview template={t} samples={samples} /><span className="template-badge">{templateIndex === i ? "✓ Selected" : `${t.count} photos`}</span></div>
        <span className="template-name">{t.name}</span><span className="template-meta">{t.tag} · {t.count} photos</span>
      </button>)}</div>
      <p className="template-demo-note">Illustrative previews · your photos replace the sample artwork.</p>
    </section>
    <div className="booth-workspace" id="booth-editor">
    <section className="booth-controls" aria-label="Photo booth controls">
      <div className="editor-heading"><span>YOUR SELECTED TEMPLATE</span><h2>{template.name}</h2><p>{template.note}</p></div>
      <fieldset disabled={busy || !!countdown}><legend>1. Add your photos</legend>
        <div className="booth-slots">{Array.from({ length: count }, (_, i) => <button key={i} aria-pressed={selected === i} onClick={() => setSelected(i)}>{mode === "couple" ? `${i % 2 ? "B" : "A"}${Math.floor(i / 2) + 1}` : `Photo ${i + 1}`} {shots[i] ? "✓" : "+"}</button>)}</div>
        <label className="booth-upload">Upload photos<input aria-label="Upload photos" type="file" accept="image/jpeg,image/png,image/webp" multiple disabled={busy} onChange={e => { void upload(e.target.files); e.target.value = ""; }} /></label>
        <p className="booth-hint">{mode === "couple" && "Add one person in A and the other in B. "}JPG, PNG, WebP · up to 20 MB each. Multiple photos fill from the selected slot.</p>
        {!camera && <button className="booth-secondary" onClick={startCamera} disabled={opening}>{opening ? "Opening camera…" : "Use camera"}</button>}
      </fieldset>
      {camera && <div className="booth-camera"><video ref={video} autoPlay playsInline muted aria-label="Camera preview" />{countdown > 0 && <strong className="booth-countdown" aria-live="assertive">{countdown}</strong>}<div className="booth-options"><button onClick={capture} disabled={!!countdown || busy}>Take photo (3s)</button><button onClick={stopCamera}>Turn camera off</button></div></div>}
      {current && <fieldset disabled={busy || !!countdown}><legend>Adjust selected photo</legend>{([['zoom', 'Zoom', 1, 3, .05], ['x', 'Horizontal position', 0, 100, 1], ['y', 'Vertical position', 0, 100, 1]] as const).map(([key, label, min, max, step]) => <label className="booth-slider" key={key}>{label}<input type="range" min={min} max={max} step={step} value={current[key]} onChange={e => crop(key, Number(e.target.value))} /></label>)}<button className="booth-secondary" onClick={() => setShots(old => old.map((s, i) => i === selected ? null : s))}>Remove selected photo</button></fieldset>}
      <fieldset disabled={busy || !!countdown}><legend>2. Make it yours</legend><div className="booth-options">{themes.map((t, i) => <button key={t.name} aria-pressed={theme === i} onClick={() => setTheme(i)}><span style={{ background: t.paper }} className="booth-swatch" />{t.name}</button>)}</div><label className="booth-caption">Caption<input maxLength={48} value={caption} onChange={e => setCaption(e.target.value)} /></label><label className="booth-check"><input type="checkbox" checked={mono} onChange={e => setMono(e.target.checked)} />Black & white photos</label></fieldset>
      <p className="booth-status" role="status">{message || `${filled} of ${count} photos added. Your photos stay in this browser.`}</p>
      <button className="gradient-button" disabled={filled !== count || busy || !!countdown} onClick={prepare}>{busy ? "Working…" : "Create my image"}</button>
      {exportUrl && exportValid && <div className="booth-options booth-export"><a className="gradient-button" href={exportUrl} download="dayflower-collage.png">Download PNG</a><button onClick={share}>Share image</button></div>}
      <button className="booth-reset" disabled={busy} onClick={() => { stopCamera(); setShots(Array(9).fill(null)); setExportUrl(""); setExportFile(null); setExportVersion(null); setSelected(0); setMessage("Photos cleared from this session."); }}>Clear all photos</button>
    </section>
    <section className="booth-preview" aria-label="Collage preview"><p className="booth-preview-label">YOUR PREVIEW <span>1080 × {template.height} PNG</span></p><canvas ref={canvas} aria-label={`Preview of ${template.name}`} /><p className="booth-hint">Free to save. No account. No photo uploads to our servers.</p></section>
  </div></>;
}
