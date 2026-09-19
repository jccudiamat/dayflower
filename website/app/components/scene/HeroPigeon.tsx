"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";

/**
 * The pigeon.
 *
 * It crosses the hero every so often — roughly fifteen seconds of flight in
 * a three-quarter-minute cycle — and the rest of the time the sky is empty.
 * A bird permanently circling the headline is a distraction; a bird that
 * turns up now and again is a place.
 *
 * ⚠️ **Nothing on this page depends on finding it.** The letter is an extra,
 * and every link inside it exists twice over in ordinary HTML above the
 * scene. It pauses while open or focused so the target stops moving, which
 * is the only reason it can be a real button at all.
 */
export default function HeroPigeon() {
  const [open, setOpen] = useState(false);

  return (
    <div className={`pigeon-flight${open ? " is-open" : ""}`}>
      <div className="pigeon-bob">
        <button
          type="button"
          className="pigeon-button"
          aria-expanded={open}
          aria-controls="pigeon-letter"
          onClick={() => setOpen((v) => !v)}
        >
          {/* ⚠️ `alt=""`, and the name comes from the span below instead. The
              alt text and the span would otherwise concatenate into one
              accessible name that reads as two sentences. */}
          <Image
            src="/bouquet/reveal-pigeon.webp"
            alt=""
            width={220}
            height={220}
            sizes="220px"
            className="pigeon-art"
          />
          <span className="sr-only">{open ? "Close the letter" : "Open the letter the pigeon is carrying"}</span>
        </button>

        {open && (
          <div className="pigeon-letter" id="pigeon-letter">
            <p className="pigeon-letter-title">A letter for you 💌</p>
            <p className="pigeon-letter-note note">&ldquo;I saw this and thought of you.&rdquo;</p>
            <Link href="/bouquet" className="pigeon-letter-link">
              Send something back <span aria-hidden="true">→</span>
            </Link>
            <button type="button" className="pigeon-letter-close" onClick={() => setOpen(false)}>
              Close<span className="sr-only"> the letter</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
