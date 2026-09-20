"use client";

import { useEffect, useRef, type ReactNode } from "react";

/**
 * Depth, cheaply.
 *
 * Publishes two numbers as custom properties on the wrapper — `--px`/`--py`
 * for the pointer, `--sc` for how far the section has travelled up the
 * viewport — and lets CSS decide how much each layer of scenery cares.
 *
 * ⚠️ Written straight to `style` from a rAF, never through state. A
 * `setState` per pointer event re-renders a few hundred SVG nodes forty times
 * a second, which is exactly the kind of thing that makes a "subtle" effect
 * cost more than the scene it decorates.
 */
export default function Parallax({ children, className }: { children: ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    // A stated preference, so it is checked before anything is wired up.
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    let frame = 0;
    let px = 0;
    let py = 0;
    let tx = 0;
    let ty = 0;

    const tick = () => {
      frame = 0;
      px += (tx - px) * 0.08;
      py += (ty - py) * 0.08;
      el.style.setProperty("--px", px.toFixed(4));
      el.style.setProperty("--py", py.toFixed(4));
      if (Math.abs(tx - px) > 0.0008 || Math.abs(ty - py) > 0.0008) frame = requestAnimationFrame(tick);
    };
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(tick);
    };

    const fine = matchMedia("(pointer: fine)").matches;
    const onMove = (e: PointerEvent) => {
      const box = el.getBoundingClientRect();
      tx = (e.clientX - box.left) / box.width - 0.5;
      ty = (e.clientY - box.top) / box.height - 0.5;
      schedule();
    };

    let scrollFrame = 0;
    const onScroll = () => {
      if (scrollFrame) return;
      scrollFrame = requestAnimationFrame(() => {
        scrollFrame = 0;
        const box = el.getBoundingClientRect();
        // 🔴 Clamped at 0, not at -1. A section still below the fold has a
        // positive `top`, which as a negative progress slid every layer
        // *upward* and left a band of bare section background under the
        // meadow — visible on the night scene from the moment the page
        // loaded. Layers only ever drift down, and down is clipped.
        const progress = Math.min(1, Math.max(0, -box.top / (box.height || 1)));
        el.style.setProperty("--sc", progress.toFixed(4));
      });
    };

    if (fine) addEventListener("pointermove", onMove, { passive: true });
    addEventListener("scroll", onScroll, { passive: true });
    onScroll();

    return () => {
      removeEventListener("pointermove", onMove);
      removeEventListener("scroll", onScroll);
      if (frame) cancelAnimationFrame(frame);
      if (scrollFrame) cancelAnimationFrame(scrollFrame);
    };
  }, []);

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
