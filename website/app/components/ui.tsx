import type { ReactNode } from "react";

/** Small caps label that opens a section (design.md: `label 11 caps`). */
export function SectionLabel({
  children,
  dark = false,
}: {
  children: ReactNode;
  dark?: boolean;
}) {
  return (
    <p
      className={`text-[11px] font-bold uppercase tracking-[0.18em] ${
        dark ? "text-on-dark-muted" : "text-secondary-brand"
      }`}
    >
      {children}
    </p>
  );
}

/**
 * Two-tone headline: neutral lead line + gradient-tinted keyword.
 * design.md principle 3.
 */
export function TwoToneHeading({
  lead,
  accent,
  className = "",
}: {
  lead: string;
  accent: string;
  className?: string;
}) {
  return (
    <h2
      className={`mt-3 text-3xl font-bold leading-tight sm:text-4xl ${className}`}
    >
      {lead} <span className="gradient-text">{accent}</span>
    </h2>
  );
}

/** Informational surface — soft-square 18, hairline border, flat. */
export function Card({
  children,
  className = "",
  dark = false,
}: {
  children: ReactNode;
  className?: string;
  dark?: boolean;
}) {
  return (
    <div
      className={`rounded-[18px] border p-6 ${
        dark
          ? "border-dark-border bg-dark-surface"
          : "border-border-soft bg-surface"
      } ${className}`}
    >
      {children}
    </div>
  );
}

/** Outline pill tag. "Premium" reads purple, everything else pink. */
export function Tag({ children }: { children: string }) {
  const premium = children === "Premium";
  return (
    <span
      className={`shrink-0 rounded-full border px-3 py-1 text-[11px] font-bold ${
        premium
          ? "border-g-purple/40 text-secondary-brand"
          : "border-g-pink/40 text-brand"
      }`}
    >
      {children}
    </span>
  );
}

/** Bulleted list with the gradient tick used across feature cards. */
export function TickList({
  items,
  dark = false,
}: {
  items: string[];
  dark?: boolean;
}) {
  return (
    <ul className={`space-y-2.5 text-sm ${dark ? "" : "text-body"}`}>
      {items.map((item) => (
        <li key={item} className="flex gap-2.5">
          <span
            className={`mt-px shrink-0 font-bold ${
              dark ? "gradient-text" : "text-brand"
            }`}
            aria-hidden
          >
            ✓
          </span>
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}
