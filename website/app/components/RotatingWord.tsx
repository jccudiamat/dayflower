"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";

/**
 * The one word in the headline that changes: "One **flower** a day" becomes
 * heartbeat, photo, note…
 *
 * Three things this has to get right or it looks broken:
 *
 * 1. **The words cross-fade in place**, so they are all stacked in a single
 *    grid cell rather than laid out in sequence.
 * 2. **The slot is only as wide as the word in it, and grows to the next
 *    one.** Sizing the cell to the longest word instead — the obvious
 *    CSS-only fix — left a visible hole after "note" and shoved "a day"
 *    across the line. So the width is measured and animated, which means
 *    measuring in a layout effect and again once the webfont has actually
 *    loaded: Quicksand arrives after first paint and every word gets wider.
 * 3. **Screen readers must hear a sentence, not a word salad.** The rotator
 *    is `aria-hidden` and `page.tsx` puts the plain sentence in an `sr-only`
 *    heading beside it.
 */
export default function RotatingWord({
  words,
  intervalMs = 2400,
}: {
  words: string[];
  intervalMs?: number;
}) {
  const [index, setIndex] = useState(0);
  const [width, setWidth] = useState<number>();
  const slots = useRef<(HTMLSpanElement | null)[]>([]);

  // Before hydration the cell is auto-width (as wide as the longest word);
  // this is what narrows it to the one actually showing.
  useLayoutEffect(() => {
    const el = slots.current[index];
    if (el) setWidth(Math.ceil(el.getBoundingClientRect().width) + 2);
  }, [index]);

  useEffect(() => {
    function measure() {
      const el = slots.current[index];
      if (el) setWidth(Math.ceil(el.getBoundingClientRect().width) + 2);
    }
    // The fallback font is a different width, so the first measurement is
    // wrong until Quicksand lands.
    document.fonts?.ready.then(measure);
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [index]);

  useEffect(() => {
    // Someone who asked for less motion gets the first word and nothing else —
    // a word swapping every two seconds is exactly what that setting is for.
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const id = setInterval(
      () => setIndex((i) => (i + 1) % words.length),
      intervalMs,
    );
    return () => clearInterval(id);
  }, [words.length, intervalMs]);

  return (
    <span className="rotator" style={{ width }} aria-hidden>
      {words.map((word, i) => (
        <span
          key={word}
          ref={(el) => {
            slots.current[i] = el;
          }}
          className={`rotator-word gradient-text ${i === index ? "is-current" : ""}`}
        >
          {word}
        </span>
      ))}
    </span>
  );
}
