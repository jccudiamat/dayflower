/** Illustrative screen previews based on Flutter UI, using fictional sample content. */
import Image from "next/image";
import type { ReactNode } from "react";

/* ── Frame ──────────────────────────────────────────────────────────────── */

function Phone({ children, dark = false }: { children: ReactNode; dark?: boolean }) {
  return (
    <div className="phone-body">
      <div className={`phone-screen ${dark ? "phone-screen-dark" : ""}`}>
        <span className="phone-island" aria-hidden />
        {children}
      </div>
    </div>
  );
}

/** The app's UserAvatar fallback: a gradient disc with a bloom in it. */
function Avatar({ size = 34, emoji = "🌷" }: { size?: number; emoji?: string }) {
  return (
    <span
      className="grid shrink-0 place-items-center rounded-full"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.46,
        background: "linear-gradient(135deg, #F0709F, #906FE8)",
      }}
      aria-hidden
    >
      {emoji}
    </span>
  );
}

function Label({ children, tone = "muted" }: { children: ReactNode; tone?: "muted" | "dark" }) {
  return (
    <p
      className={`text-[8.5px] font-bold uppercase tracking-[0.16em] ${
        tone === "dark" ? "text-on-dark-muted" : "text-muted"
      }`}
    >
      {children}
    </p>
  );
}

function Bloom({ id, alt, className = "" }: { id: string; alt: string; className?: string }) {
  return (
    <Image
      src={`/flowers/${id}.webp`}
      alt={alt}
      width={512}
      height={512}
      // Never wider than the phone frame, so don't let Next serve a 1080.
      sizes="300px"
      className={`h-full w-full object-cover ${className}`}
    />
  );
}

/* ── 1 · Flowers — the thread ───────────────────────────────────────────── */

export function ChatSnapshot() {
  return (
    <Phone>
      {/* Header — avatar, name, their mood, and the two call buttons. */}
      <header className="flex items-center gap-2 border-b border-border-soft bg-surface px-3.5 pb-2.5 pt-8">
        <span className="text-[13px] text-muted" aria-hidden>‹</span>
        <Avatar size={34} />
        <div className="min-w-0 flex-1 leading-tight">
          <p className="text-[13px] font-bold">Alex</p>
          <p className="text-[10px] text-muted">😌&nbsp; Feeling calm</p>
        </div>
        <span className="text-[13px] text-muted" aria-hidden>✆</span>
        <span className="text-[13px] text-muted" aria-hidden>▣</span>
      </header>

      {/* Thread — bottom-aligned, the way a conversation sits. */}
      <div className="flex flex-1 flex-col justify-end gap-2.5 overflow-hidden px-3.5 pb-3 pt-4">
        <p className="self-center rounded-full bg-surface-subtle px-2.5 py-1 text-[8.5px] font-bold uppercase tracking-[0.16em] text-body">
          Today
        </p>

        {/* Theirs: a flower, its meaning, and the line they wrote with it. */}
        <div className="max-w-[86%] self-start rounded-[18px] rounded-bl-[4px] border border-border-soft bg-surface p-2">
          <div className="aspect-square overflow-hidden rounded-[12px]">
            <Bloom id="fox_in_tulips" alt="Fox in the Tulips" />
          </div>
          <div className="px-1 pb-0.5 pt-2">
            <p className="text-[11.5px] font-bold leading-tight">Fox in the Tulips</p>
            <p className="note text-[10px] leading-tight text-muted">
              A flower for your morning
            </p>
            <p className="note mt-1.5 text-[11.5px] leading-snug">
              &ldquo;He sat there the whole time I was on the phone with you.&rdquo;
            </p>
            <p className="mt-1 text-[9px] text-muted">8:12 AM</p>
          </div>
        </div>

        {/* Yours: blush fill, pink hairline — the gradient is spent elsewhere. */}
        <div className="max-w-[80%] self-end rounded-[18px] rounded-br-[4px] border border-blush-mid bg-blush px-3 py-2">
          <p className="text-[11.5px] leading-snug">
            okay that is the cutest thing i have seen all week 🥹
          </p>
          <p className="mt-1 text-right text-[9px] text-secondary-brand">8:20 AM · ✓ Seen</p>
        </div>

        {/* A call is a row in the thread, so it is still here an hour later. */}
        <div className="flex max-w-[80%] items-center gap-2 self-start rounded-[18px] rounded-bl-[4px] border border-border-soft bg-surface px-3 py-2">
          <span className="grid h-6 w-6 place-items-center rounded-full bg-surface-subtle text-[10px]" aria-hidden>
            ✆
          </span>
          <div className="leading-tight">
            <p className="text-[11px] font-bold">Voice call</p>
            <p className="text-[9px] text-muted">24 min · ended 9:04 AM</p>
          </div>
        </div>
      </div>

      {/* Composer. */}
      <div className="flex items-center gap-2 border-t border-border-soft bg-surface px-3 py-2.5">
        <span className="grid h-7 w-7 place-items-center rounded-full text-[13px] text-white"
              style={{ background: "linear-gradient(90deg,#F0709F,#906FE8)" }} aria-hidden>
          🌷
        </span>
        <span className="flex-1 rounded-full bg-surface-subtle px-3 py-1.5 text-[11px] text-muted">
          Message
        </span>
        <span className="text-[12px] text-muted" aria-hidden>▢</span>
        <span className="text-[12px] text-muted" aria-hidden>◎</span>
      </div>
    </Phone>
  );
}

/* ── 2 · Home ───────────────────────────────────────────────────────────── */

const MOODS = [
  { emoji: "😊", label: "Happy" },
  { emoji: "🥰", label: "Loved" },
  { emoji: "😌", label: "Calm" },
  { emoji: "😔", label: "Low" },
  { emoji: "😤", label: "Stressed" },
  { emoji: "😴", label: "Tired" },
];

export function HomeSnapshot() {
  return (
    <Phone>
      {/* Top bar — the pair pill is the door to the Us page. */}
      <div className="flex items-center justify-between px-4 pb-1 pt-8">
        <span className="flex items-center gap-1.5 rounded-full border border-border-soft bg-surface py-1 pl-1 pr-2.5">
          <span className="flex -space-x-1.5">
            <Avatar size={18} emoji="🌷" />
            <Avatar size={18} emoji="🌻" />
          </span>
          <span className="text-[10px] font-bold">You &amp; Alex</span>
        </span>
        <span className="text-[12px] text-muted" aria-hidden>◔</span>
      </div>

      <div className="flex-1 overflow-hidden px-4 pt-2">
        {/* Greeting, their clock, the distance — and today's photo in the arch. */}
        <div className="flex items-end gap-2.5">
          <div className="min-w-0 flex-1 pb-1">
            <p className="text-[19px] font-bold leading-tight">Good evening,</p>
            <p className="text-[19px] font-bold leading-tight" style={{ color: "#D5568F" }}>
              Sam <span className="text-[15px]">🌷</span>
            </p>
            <p className="mt-1.5 text-[10.5px] text-body">Alex · Manila · 9:41 PM</p>
            <p className="text-[10.5px] text-body">6,780 km apart</p>
          </div>
          <div className="relative h-[128px] w-[88px] shrink-0">
            <div className="absolute inset-x-2 top-0 h-[116px] rounded-t-[38px] rounded-b-[16px] bg-surface-subtle" />
            <div className="absolute inset-x-0 bottom-0 h-[116px] overflow-hidden rounded-t-[42px] rounded-b-[18px] border border-border-soft">
              <Bloom id="misty_blossom" alt="Their photo of today" />
            </div>
          </div>
        </div>

        {/* Mood — one tap, and it shows up in their chat header. */}
        <div className="mt-3 rounded-[18px] border border-border-soft bg-surface p-3">
          <div className="flex items-baseline justify-between">
            <Label>How are you feeling?</Label>
            <p className="text-[10px] font-bold text-secondary-brand">Calm</p>
          </div>
          <div className="mt-2 flex gap-1">
            {MOODS.map((m) => (
              <span
                key={m.label}
                className={`grid flex-1 place-items-center rounded-[10px] border py-1.5 text-[13px] ${
                  m.label === "Calm"
                    ? "border-[1.5px] border-g-purple/60 bg-surface-subtle"
                    : "border-border-soft"
                }`}
                aria-hidden
              >
                {m.emoji}
              </span>
            ))}
          </div>
        </div>

        {/* Heartbeat — the only looping animation in the design system. */}
        <div className="mt-2 flex items-center gap-3 rounded-[18px] border border-border-soft bg-surface p-3">
          <div className="min-w-0 flex-1">
            <Label>Haptic heartbeat</Label>
            <p className="mt-1 text-[12.5px] font-bold">Tapped 5× today</p>
            <p className="text-[10px] text-muted">A little hello for Alex</p>
          </div>
          <span
            className="pulse-ring relative grid h-11 w-11 shrink-0 place-items-center rounded-full text-[17px]"
            style={{ background: "linear-gradient(135deg,#FCEDF4,#EFEAF8)" }}
            aria-hidden
          >
            💓
          </span>
        </div>

        {/* The shared feed — one timeline, both of you in it. */}
        <div className="mt-3">
          <Label>Today</Label>
          <div className="mt-1.5 space-y-1.5">
            {[
              ["🌷", "Alex sent Fox in the Tulips", "8:12 AM"],
              ["📸", "Alex shared their day", "7:40 AM"],
            ].map(([icon, text, time]) => (
              <div
                key={text}
                className="flex items-center gap-2.5 rounded-[14px] border border-border-soft bg-surface px-2.5 py-2"
              >
                <span className="grid h-6 w-6 place-items-center rounded-full bg-surface-subtle text-[11px]" aria-hidden>
                  {icon}
                </span>
                <p className="min-w-0 flex-1 truncate text-[10.5px] font-semibold">{text}</p>
                <p className="text-[9px] text-muted">{time}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Bottom nav — Home · Camera · Flowers · Events · Activities. */}
      <div className="mx-3 mb-3 flex items-center justify-around rounded-full bg-surface-subtle py-2.5">
        {["⌂", "◎", "❀", "▤", "✦"].map((icon, i) => (
          <span
            key={icon}
            className={`text-[13px] ${i === 0 ? "text-secondary-brand" : "text-muted"}`}
            aria-hidden
          >
            {icon}
          </span>
        ))}
      </div>
    </Phone>
  );
}

/* ── 3 · Calling ────────────────────────────────────────────────────────── */

export function CallSnapshot() {
  return (
    <Phone dark>
      <div className="flex flex-1 flex-col items-center px-6 pb-8 pt-16 text-center text-on-dark">
        <p className="text-[8.5px] font-bold uppercase tracking-[0.18em] text-on-dark-muted">
          Dayflower video
        </p>

        <div className="mt-auto">
          <div className="relative mx-auto grid h-[104px] w-[104px] place-items-center">
            <span className="pulse-ring absolute inset-0 rounded-full" aria-hidden />
            <Avatar size={92} emoji="🌻" />
          </div>
          <p className="mt-5 text-[21px] font-bold">Alex</p>
          <p className="mt-0.5 text-[12px] text-on-dark-muted">is calling you</p>
          <p className="mt-3 text-[10.5px] text-on-dark-muted">Manila · 9:41 PM</p>
        </div>

        <div className="mt-auto flex w-full items-end justify-center gap-12">
          <div>
            <span
              className="grid h-14 w-14 place-items-center rounded-full text-[19px]"
              style={{ background: "#E2447C" }}
              aria-hidden
            >
              ✕
            </span>
            <p className="mt-2 text-[10px] text-on-dark-muted">Not now</p>
          </div>
          <div>
            <span
              className="grid h-14 w-14 place-items-center rounded-full text-[19px]"
              style={{ background: "#3DBE7B" }}
              aria-hidden
            >
              ✆
            </span>
            <p className="mt-2 text-[10px] text-on-dark-muted">Answer</p>
          </div>
        </div>
      </div>
    </Phone>
  );
}

/* ── 4 · Us ─────────────────────────────────────────────────────────────── */

const US_STATS = [
  ["128", "Flowers"],
  ["42", "Streak"],
  ["1,204", "Hearts"],
  ["486", "Days"],
];

export function UsSnapshot() {
  return (
    <Phone>
      <div className="flex items-center justify-between px-4 pb-2 pt-8">
        <p className="text-[15px] font-bold">Us</p>
        <span className="text-[12px] text-muted" aria-hidden>⚙</span>
      </div>

      <div className="flex-1 overflow-hidden px-4">
        {/* The couple card carries the emotional weight, so it goes dark. */}
        <div
          className="rounded-[24px] p-4 text-on-dark"
          style={{ background: "linear-gradient(160deg,#171027,#221838 55%,#120C1F)" }}
        >
          <div className="flex items-center gap-3">
            <span className="flex -space-x-3">
              <Avatar size={40} emoji="🌷" />
              <Avatar size={40} emoji="🌻" />
            </span>
            <div className="leading-tight">
              <p className="text-[13.5px] font-bold">Sam &amp; Alex</p>
              <p className="text-[10px] text-on-dark-muted">1 year, 3 months together</p>
            </div>
          </div>
          <div className="mt-4 grid grid-cols-4 gap-1.5 text-center">
            {US_STATS.map(([value, label]) => (
              <div key={label} className="rounded-[12px] bg-white/[0.06] py-2">
                <p className="text-[14px] font-bold tabular-nums">{value}</p>
                <p className="text-[7.5px] font-bold uppercase tracking-[0.12em] text-on-dark-muted">
                  {label}
                </p>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-2.5 rounded-[18px] border border-border-soft bg-surface p-3">
          <Label>Together since</Label>
          <p className="mt-1 text-[14px] font-bold">6 May 2025</p>
          <p className="mt-0.5 text-[9.5px] text-muted">
            Your monthsary and anniversary come from this.
          </p>
        </div>

        <div className="mt-2.5 rounded-[18px] border border-border-soft bg-surface p-3">
          <Label>Coming up</Label>
          <div className="mt-2 space-y-2">
            {[
              ["🌙", "Monthsary", "Monday 6 October", "in 12 days"],
              ["💐", "Anniversary", "Wednesday 6 May", "in 224 days"],
            ].map(([icon, name, date, away]) => (
              <div key={name} className="flex items-center gap-2.5">
                <span className="grid h-7 w-7 place-items-center rounded-full bg-surface-subtle text-[11px]" aria-hidden>
                  {icon}
                </span>
                <div className="min-w-0 flex-1 leading-tight">
                  <p className="text-[11px] font-bold">{name}</p>
                  <p className="text-[9.5px] text-muted">{date}</p>
                </div>
                <span className="rounded-full border border-g-purple/40 px-2 py-0.5 text-[9px] font-bold text-secondary-brand">
                  {away}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-2.5 rounded-[18px] border border-border-soft bg-surface p-3">
          <Label>Where you are</Label>
          <div className="mt-2 space-y-2">
            {[
              ["Sam", "Dubai", "5:41 PM"],
              ["Alex", "Manila", "9:41 PM"],
            ].map(([who, city, time]) => (
              <div key={who} className="flex items-center justify-between">
                <p className="text-[11px] font-semibold">
                  {who} <span className="text-muted">· {city}</span>
                </p>
                <p className="text-[11px] font-bold tabular-nums">{time}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="mx-3 mb-3 mt-3 flex items-center justify-around rounded-full bg-surface-subtle py-2.5">
        {["⌂", "◎", "❀", "▤", "✦"].map((icon, i) => (
          <span
            key={icon}
            className={`text-[13px] ${i === 0 ? "text-secondary-brand" : "text-muted"}`}
            aria-hidden
          >
            {icon}
          </span>
        ))}
      </div>
    </Phone>
  );
}

/* ── 5 · Activities ─────────────────────────────────────────────────────── */

export function ActivitiesSnapshot() {
  return (
    <Phone>
      <div className="px-4 pb-3 pt-8">
        <p className="text-[19px] font-bold leading-tight">Activities</p>
        <p className="text-[10.5px] text-body">Things to do together, apart</p>
      </div>

      <div className="flex-1 space-y-2 overflow-hidden px-4">
        {[
          ["⏰", "Reminders", "Nudge them, or ask to be nudged", null],
          ["💰", "Finances", "What comes in, what goes out, what grows", null],
          ["📖", "Chapters", "Twelve months, twelve stories", "Review due"],
        ].map(([icon, title, sub, badge]) => (
          <div
            key={title as string}
            className="flex items-center gap-3 rounded-[18px] border border-border-soft bg-surface p-3"
          >
            <span className="grid h-9 w-9 place-items-center rounded-[12px] bg-surface-subtle text-[15px]" aria-hidden>
              {icon}
            </span>
            <div className="min-w-0 flex-1 leading-tight">
              <div className="flex items-center gap-2">
                <p className="flex-1 text-[12.5px] font-bold">{title}</p>
                {badge && (
                  <span className="shrink-0 rounded-full border border-g-pink/40 px-2 py-0.5 text-[8.5px] font-bold text-brand">
                    {badge}
                  </span>
                )}
              </div>
              <p className="mt-0.5 text-[9.5px] text-muted">{sub}</p>
            </div>
          </div>
        ))}

        {/* The booth gets the dark card — it is the one that is a bit of fun. */}
        <div
          className="overflow-hidden rounded-[18px] p-3.5 text-on-dark"
          style={{ background: "linear-gradient(160deg,#171027,#221838 55%,#120C1F)" }}
        >
          <p className="text-[12.5px] font-bold">Booth &amp; Strip</p>
          <p className="text-[9.5px] text-on-dark-muted">Photo strips, ten templates</p>
          <div className="mt-2.5 flex gap-1.5">
            {["classic_tulip", "sunset_shore", "garden_path"].map((id) => (
              <div key={id} className="h-12 flex-1 overflow-hidden rounded-[8px]">
                <Bloom id={id} alt="" />
              </div>
            ))}
          </div>
          <p className="note mt-2.5 text-[10.5px]">Pose apart, print together. 🌷</p>
        </div>

        <div className="pt-1">
          <Label>Coming soon</Label>
          <div className="mt-1.5 flex gap-1.5">
            {[
              ["🎮", "Games"],
              ["🗺️", "Travel map"],
              ["🎵", "Music"],
            ].map(([icon, name]) => (
              <span
                key={name}
                className="flex flex-1 items-center justify-center gap-1 rounded-full border border-border-soft py-1.5 text-[9.5px] font-semibold text-muted"
              >
                <span aria-hidden>{icon}</span>
                {name}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="mx-3 mb-3 flex items-center justify-around rounded-full bg-surface-subtle py-2.5">
        {["⌂", "◎", "❀", "▤", "✦"].map((icon, i) => (
          <span
            key={icon}
            className={`text-[13px] ${i === 4 ? "text-secondary-brand" : "text-muted"}`}
            aria-hidden
          >
            {icon}
          </span>
        ))}
      </div>
    </Phone>
  );
}

/* ── Lookup used by the rail in page.tsx ────────────────────────────────── */

export const SNAPSHOT_BY_ID = {
  chat: ChatSnapshot,
  home: HomeSnapshot,
  call: CallSnapshot,
  us: UsSnapshot,
  activities: ActivitiesSnapshot,
} as const;
