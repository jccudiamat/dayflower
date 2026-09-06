"use client";

import Image from "next/image";
import { useRef, useState } from "react";

/**
 * A deck of polaroids, tilted and stacked, that you can throw off the top.
 *
 * The frame is the app's own Classic Polaroid, measured off
 * `lib/features/booth/presentation/screens/booth_screen.dart` rather than
 * eyeballed: paper #FFFEF8, a **4px** card radius and a **2px** slot radius
 * (a real polaroid is barely rounded — it reads as rounder here only because
 * the card is large), caption #3A2A20 at 0.3 letter-spacing, date at 25%
 * black. The app's duo template splits the slot in two; this uses one wide
 * slot, because a bloom is one picture.
 *
 * Interaction: drag the top card and let go past the threshold to send it to
 * the back, or tap/click it, or use the dots. Everything is also reachable
 * from the keyboard — the card is a real button.
 */

export type Polaroid = {
  bloom: string;
  caption: string;
  date: string;
  isNew?: boolean;
  /** Degrees. Taken from the app's own stack: -6, 4, -3, 2. */
  tilt: number;
};

const THROW_DISTANCE = 90;

export default function PolaroidStack({ cards }: { cards: Polaroid[] }) {
  const [order, setOrder] = useState(() => cards.map((_, i) => i));
  const [drag, setDrag] = useState(0);
  const start = useRef<number | null>(null);

  function advance() {
    setDrag(0);
    setOrder(([first, ...rest]) => [...rest, first]);
  }

  function onPointerDown(e: React.PointerEvent) {
    start.current = e.clientX;
    e.currentTarget.setPointerCapture(e.pointerId);
  }

  function onPointerMove(e: React.PointerEvent) {
    if (start.current === null) return;
    setDrag(e.clientX - start.current);
  }

  function onPointerUp() {
    if (start.current === null) return;
    const thrown = Math.abs(drag) > THROW_DISTANCE;
    start.current = null;
    // A drag that never really moved is a click, and a click also advances —
    // so a tap does the obvious thing instead of nothing.
    if (thrown || Math.abs(drag) < 4) advance();
    else setDrag(0);
  }

  return (
    <div className="polaroid-stack">
      <div className="polaroid-deck">
        {order.map((cardIndex, depth) => {
          const card = cards[cardIndex];
          const top = depth === 0;
          return (
            <button
              key={card.bloom}
              type="button"
              className={`polaroid ${top ? "is-top" : ""} ${drag !== 0 && top ? "is-dragging" : ""}`}
              style={{
                // Cards sink back and down as they go deeper in the pile.
                zIndex: cards.length - depth,
                transform: top
                  ? `translateX(${drag}px) rotate(${card.tilt + drag * 0.04}deg)`
                  : `translate(${depth * 5}px, ${depth * 7}px) rotate(${card.tilt}deg) scale(${1 - depth * 0.03})`,
                opacity: depth > 2 ? 0 : 1,
              }}
              onPointerDown={top ? onPointerDown : undefined}
              onPointerMove={top ? onPointerMove : undefined}
              onPointerUp={top ? onPointerUp : undefined}
              onPointerCancel={top ? onPointerUp : undefined}
              // The top card advances on pointerup, so a mouse click must not
              // advance it a second time — but Enter/Space on a focused
              // button fires `click` with no pointer events at all, and
              // `detail === 0` is what tells those two apart.
              onClick={
                top
                  ? (e: React.MouseEvent) => {
                      if (e.detail === 0) advance();
                    }
                  : advance
              }
              tabIndex={top ? 0 : -1}
              aria-label={
                top ? "Next photo" : undefined
              }
              aria-hidden={!top}
            >
              {card.isNew && <span className="polaroid-new">new</span>}
              <span className="polaroid-slot">
                <Image
                  src={`/flowers/${card.bloom}.webp`}
                  alt=""
                  width={512}
                  height={512}
                  sizes="300px"
                  draggable={false}
                  preload={cardIndex === 0}
                />
              </span>
              <span className="polaroid-caption">
                <span className="polaroid-label">{card.caption}</span>
                <span className="polaroid-date">{card.date}</span>
              </span>
            </button>
          );
        })}
      </div>

      <div className="polaroid-dots">
        {cards.map((card, i) => (
          <button
            key={card.bloom}
            type="button"
            className={`polaroid-dot ${order[0] === i ? "is-on" : ""}`}
            aria-label={`Photo ${i + 1} of ${cards.length}`}
            aria-current={order[0] === i}
            onClick={() =>
              setOrder(
                cards.map((_, n) => (n + i) % cards.length),
              )
            }
          />
        ))}
      </div>
    </div>
  );
}
