"use client";

import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import { daylightAt, phaseForHour, phaseFromScroll } from "./daylight";
import { detectTier, type Tier } from "./Scene";

/**
 * Three.js is ~23MB installed and a few hundred KB shipped. It must never be
 * part of the bundle that renders the words, so the scene arrives on its own,
 * after mount, and only where it is going to be used.
 */
const Scene = dynamic(() => import("./Scene"), { ssr: false });

type Capability = "pending" | "full" | "still";

/**
 * Can this visitor have the moving world, and do they want it?
 *
 * 🔴 Three separate reasons to say no, and all of them are real:
 *  - `prefers-reduced-motion`, which is a stated preference, not a guess
 *  - no WebGL, which includes older phones and locked-down browsers
 *  - `deviceMemory` under 4GB, where the scene runs but the page stutters
 *
 * Any of them falls back to the painted sky, which is not a degraded state:
 * it is the same palette, held still.
 */
function decide(): Capability {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return "still";
  const mem = (navigator as Navigator & { deviceMemory?: number }).deviceMemory;
  if (typeof mem === "number" && mem < 4) return "still";
  try {
    const canvas = document.createElement("canvas");
    const gl = canvas.getContext("webgl2") ?? canvas.getContext("webgl");
    if (!gl) return "still";
    // Release it immediately; browsers cap concurrent contexts and the real
    // one is about to ask for its own.
    (gl.getExtension("WEBGL_lose_context") as { loseContext(): void } | null)?.loseContext();
    return "full";
  } catch {
    return "still";
  }
}

export default function DayflowerWorld() {
  const [capability, setCapability] = useState<Capability>("pending");
  const [tier, setTier] = useState<Tier>("low");
  const [phase, setPhase] = useState(() => 0.3);
  const start = useRef(0.3);

  useEffect(() => {
    start.current = phaseForHour(new Date().getHours());
    setPhase(start.current);
    setCapability(decide());
    setTier(detectTier());
  }, []);

  /**
   * Scroll walks the day forward. Read in rAF rather than in the listener, so
   * a fast flick coalesces into one update per frame instead of forty.
   */
  useEffect(() => {
    let frame = 0;
    const onScroll = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const max = document.documentElement.scrollHeight - innerHeight;
        setPhase(phaseFromScroll(start.current, max > 0 ? scrollY / max : 0));
      });
    };
    addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => {
      removeEventListener("scroll", onScroll);
      if (frame) cancelAnimationFrame(frame);
    };
  }, []);

  const light = daylightAt(phase);

  return (
    <div className="world-stage" aria-hidden>
      {/* Painted first, always, and never removed. It is the fallback for
          everyone who does not get the canvas, and the backdrop the canvas
          fades in over for everyone who does, so there is no white flash. */}
      <div
        className="world-sky"
        style={{ background: `linear-gradient(175deg, ${light.skyTop} 0%, ${light.skyLow} 58%, ${light.ground} 100%)` }}
      />
      {capability === "full" && (
        <div className="world-canvas">
          <Scene phase={phase} tier={tier} />
        </div>
      )}
    </div>
  );
}
