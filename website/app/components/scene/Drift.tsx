import { seeded } from "./palette";

/**
 * The air.
 *
 * ⚠️ Deliberately almost nothing: five petals on a long cycle in the morning,
 * nine fireflies at night. A breeze carries three or four things past every
 * half minute or so and then leaves, which is the difference between a page
 * you can leave open and a screensaver.
 *
 * No JavaScript: a fixed list of elements, each with a delay, handed to CSS.
 */
export function Petals() {
  const rand = seeded(5150);
  return (
    <div className="drift" aria-hidden>
      {Array.from({ length: 5 }, (_, i) => (
        <span
          key={i}
          className="petal"
          style={{
            top: `${8 + rand() * 46}%`,
            animationDuration: `${26 + rand() * 12}s`,
            animationDelay: `-${(rand() * 38).toFixed(1)}s`,
            ["--spin" as string]: `${(rand() > 0.5 ? 1 : -1) * (300 + rand() * 420)}deg`,
            ["--fall" as string]: `${14 + rand() * 26}vh`,
            ["--size" as string]: `${9 + rand() * 7}px`,
            opacity: 0.55 + rand() * 0.35,
          }}
        />
      ))}
    </div>
  );
}

export function Fireflies() {
  const rand = seeded(6060);
  return (
    <div className="drift" aria-hidden>
      {Array.from({ length: 11 }, (_, i) => (
        <span
          key={i}
          className="firefly"
          style={{
            left: `${4 + rand() * 92}%`,
            top: `${44 + rand() * 46}%`,
            animationDuration: `${7 + rand() * 7}s`,
            animationDelay: `-${(rand() * 14).toFixed(1)}s`,
            ["--rise" as string]: `${-20 - rand() * 46}px`,
            ["--slide" as string]: `${(rand() - 0.5) * 90}px`,
          }}
        />
      ))}
    </div>
  );
}
