import Image from "next/image";

/**
 * Two screens from the Dayflower app, rebuilt in HTML.
 *
 * ⚠️ **Two phones, not five.** The app has five tabs and there is a
 * temptation to show all of them; the story the homepage needs is only the
 * first and the last of it — *live the moment* in front, *keep the moment*
 * behind — and a row of five identical rectangles says neither.
 *
 * Rebuilt rather than screenshotted so the type stays crisp at any density,
 * the phones weigh a few kilobytes instead of a few hundred, and the only
 * bitmaps are the photographs the app would actually be showing.
 *
 * ⚠️ Sample content, and the faces are synthetic stand-ins — never a real
 * couple, never a real photograph of anybody. The section caption says so.
 */

const SCREEN = { width: 268, height: 602 };

function Phone({ children, className }: { children: React.ReactNode; className: string }) {
  return (
    <div className={`ph ${className}`} aria-hidden>
      <div className="ph-body">
        <div className="ph-screen" style={{ width: SCREEN.width, height: SCREEN.height }}>
          <StatusBar />
          {children}
        </div>
      </div>
    </div>
  );
}

function StatusBar() {
  return (
    <div className="ph-status">
      <span className="ph-time">9:41</span>
      <span className="ph-status-icons">
        <svg viewBox="0 0 18 12" className="ph-sig"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
        <svg viewBox="0 0 16 12" className="ph-sig"><path d="M8 10.6 5.6 8.2a3.4 3.4 0 0 1 4.8 0Zm0-5.2a6.8 6.8 0 0 0-4.8 2L1.6 5.8a9 9 0 0 1 12.8 0l-1.6 1.6a6.8 6.8 0 0 0-4.8-2Z" /></svg>
        <svg viewBox="0 0 24 12" className="ph-sig"><rect x="0" y="1" width="21" height="10" rx="3" /><rect x="22" y="4" width="2" height="4" rx="1" opacity="0.5" /></svg>
      </span>
    </div>
  );
}

/* ── Home · what matters today ──────────────────────────────────────────── */

export function HomePhone() {
  return (
    <Phone className="ph-home">
      <header className="ph-appbar">
        <p className="ph-wordmark">Dayflower</p>
        <span className="ph-bell">
          <svg viewBox="0 0 24 24"><path d="M12 3a6 6 0 0 0-6 6v4l-1.6 2.4A1 1 0 0 0 5.2 17h13.6a1 1 0 0 0 .8-1.6L18 13V9a6 6 0 0 0-6-6Zm0 18a2.6 2.6 0 0 0 2.5-2h-5A2.6 2.6 0 0 0 12 21Z" /></svg>
        </span>
        <span className="ph-pair">
          <span className="ph-face ph-face-a"><Image src="/models/cove.webp" alt="" width={720} height={960} sizes="30px" /></span>
          <span className="ph-face ph-face-b"><Image src="/models/sunset.webp" alt="" width={720} height={960} sizes="30px" /></span>
          <span className="ph-send" aria-hidden>➤</span>
        </span>
      </header>

      <div className="ph-scroll">
        <div className="ph-greet">
          <div className="ph-greet-copy">
            <p className="ph-greet-line">Good afternoon,</p>
            <p className="ph-greet-name">Hubby <span className="ph-emoji">🌷</span></p>
            <p className="ph-greet-meta">Wifey · Manila · 7:00 PM</p>
            <p className="ph-greet-meta">4,293 miles apart <span className="ph-emoji">✈️</span></p>
            <span className="ph-live"><i /> Live</span>
          </div>
          <div className="ph-daily">
            <Image src="/models/sunset.webp" alt="" width={720} height={960} sizes="120px" />
            <span className="ph-daily-note note">Thinking of you ♡</span>
          </div>
        </div>

        {/* Two clocks and the distance between them. */}
        <div className="ph-card ph-map">
          <MapBack />
          <div className="ph-map-row">
            <div><p className="ph-city">Dubai</p><p className="ph-clock">3:00 PM</p></div>
            <div className="ph-map-right"><p className="ph-city">Manila</p><p className="ph-clock">7:00 PM</p></div>
          </div>
          <svg className="ph-arc" viewBox="0 0 220 40"><path d="M14 30 C70 2 150 2 206 26" fill="none" stroke="#8b72e0" strokeWidth="1.6" strokeDasharray="3 4" strokeLinecap="round" /><path d="M104 8l9 5-9 5 2-5Z" fill="#6f58c9" /><circle cx="200" cy="25" r="6" fill="#f0709f" opacity="0.25" /><circle cx="200" cy="25" r="3" fill="#ee6fa8" /></svg>
          <div className="ph-map-foot">
            <p>4,293 miles apart</p>
            <p className="ph-link">See on map ›</p>
          </div>
        </div>

        {/* Their mood, and a heart to send back. */}
        <div className="ph-card ph-mood">
          <div className="ph-mood-top">
            <div>
              <p className="ph-mood-title">Wifey is feeling loved <span className="ph-emoji">🥰</span></p>
              <p className="ph-mood-sub">Thinking about you.</p>
            </div>
            <span className="ph-heart"><svg viewBox="0 0 24 24"><path d="M12 20s-7.4-4.6-7.4-9.6A4.4 4.4 0 0 1 12 7.4a4.4 4.4 0 0 1 7.4 3c0 5-7.4 9.6-7.4 9.6Z" /></svg></span>
          </div>
          <div className="ph-mood-row">
            {["😊", "🥰", "😌", "🥲", "🥳"].map((e) => (
              <span key={e} className="ph-mood-chip">{e}</span>
            ))}
          </div>
        </div>

        <p className="ph-section">Coming up</p>
        <div className="ph-card ph-soon">
          <div>
            <p className="ph-soon-when">In 3 days</p>
            <p className="ph-soon-title">Our monthsary</p>
            <p className="ph-soon-date">Saturday, 19 September</p>
          </div>
          <Image className="ph-soon-art" src="/bouquet/reveal-envelope.webp" alt="" width={512} height={512} sizes="90px" />
        </div>

        <p className="ph-section">A year ago today</p>
        <div className="ph-card ph-ago">
          <span className="ph-ago-photo"><Image src="/models/cove.webp" alt="" width={720} height={960} sizes="80px" /></span>
          <div>
            <p className="ph-ago-title">This moment</p>
            <p className="ph-ago-sub">Still one of my favorites. ♡</p>
            <p className="ph-ago-date">19 Sep 2024</p>
          </div>
        </div>
      </div>

      <TabBar active="home" />
    </Phone>
  );
}

/** A world, at the size of a postage stamp: land as soft blobs, nothing more. */
function MapBack() {
  return (
    <svg className="ph-map-back" viewBox="0 0 240 96" preserveAspectRatio="none">
      <g fill="#c9d6ef" opacity="0.55">
        <path d="M18 30c12-10 34-12 48-4s24 6 30 14-6 18-20 20-34 2-46-6-16-18-12-24Z" />
        <path d="M74 60c8-4 18-2 22 6s-2 18-12 20-20-4-20-12 2-12 10-14Z" />
        <path d="M112 22c16-8 40-8 56 0s20 20 12 28-30 8-44 4-30-8-32-16 2-12 8-16Z" />
        <path d="M150 58c10-4 22 0 24 8s-8 16-18 16-16-6-16-12 4-10 10-12Z" />
        <path d="M196 34c10-6 26-4 32 4s0 18-10 22-22 0-26-8 0-14 4-18Z" />
      </g>
    </svg>
  );
}

/* ── Memories · relive your story ───────────────────────────────────────── */

const MEMORIES = [
  { day: "Today", date: "19 Sep", title: "Classic Tulips", sub: "From you", quote: "“Thinking of you”", kind: "flower" as const },
  { day: null, date: "18 Sep", title: "Our Photo Strip", sub: "4 photos", quote: null, kind: "strip" as const },
  { day: null, date: "16 Sep", title: "Daily Moment", sub: "Wifey at the beach", quote: "3:00 PM", kind: "photo" as const },
  { day: null, date: "12 Sep", title: "Just Because", sub: "A little note", quote: "“You make my days brighter.”", kind: "note" as const },
];

export function MemoriesPhone() {
  return (
    <Phone className="ph-mem">
      <header className="ph-memhead">
        <div>
          <p className="ph-memtitle">Memories</p>
          <p className="ph-memsub">Little moments. Yours to keep.</p>
        </div>
        <span className="ph-memicon">
          <svg viewBox="0 0 24 24"><path d="M12 3v18M4 8l16 8M20 8 4 16" stroke="currentColor" strokeWidth="1.7" fill="none" strokeLinecap="round" /></svg>
        </span>
        <span className="ph-face ph-face-c"><Image src="/models/sunset.webp" alt="" width={720} height={960} sizes="34px" /></span>
      </header>

      <div className="ph-chips">
        {["All", "Photos", "Flowers", "Journal", "Places"].map((c, i) => (
          <span key={c} className={`ph-chip${i === 0 ? " is-on" : ""}`}>{c}</span>
        ))}
      </div>

      <div className="ph-scroll ph-scroll-mem">
        <p className="ph-month">September 2026</p>
        <div className="ph-timeline">
          <span className="ph-rail" />
          {MEMORIES.map((m) => (
            <div key={m.date} className="ph-entry">
              <div className="ph-when">
                {m.day && <p className="ph-when-day">{m.day}</p>}
                <p className="ph-when-date">{m.date}</p>
              </div>
              <span className="ph-dot" />
              <div className="ph-card ph-memcard">
                <Thumb kind={m.kind} />
                <div className="ph-memcopy">
                  <p className="ph-memname">{m.title}</p>
                  <p className="ph-memmeta">{m.sub}</p>
                  {m.quote && <p className="ph-memquote">{m.quote}</p>}
                </div>
                <span className="ph-fav"><svg viewBox="0 0 24 24"><path d="M12 20s-7.4-4.6-7.4-9.6A4.4 4.4 0 0 1 12 7.4a4.4 4.4 0 0 1 7.4 3c0 5-7.4 9.6-7.4 9.6Z" /></svg></span>
              </div>
            </div>
          ))}
        </div>

        <p className="ph-month">August 2026</p>
        <div className="ph-timeline">
          <span className="ph-rail ph-rail-faint" />
          <div className="ph-entry">
            <div className="ph-when"><p className="ph-when-date">31 Aug</p></div>
            <span className="ph-dot ph-dot-faint" />
            <div className="ph-card ph-memcard">
              <span className="ph-book" />
              <div className="ph-memcopy">
                <p className="ph-memname">August Review</p>
                <p className="ph-memmeta">Goals, highlights and more</p>
                <p className="ph-memmeta">8 entries</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <TabBar active="memories" />
    </Phone>
  );
}

function Thumb({ kind }: { kind: "flower" | "strip" | "photo" | "note" }) {
  if (kind === "strip") {
    return (
      <span className="ph-thumb ph-thumb-strip">
        <Image src="/models/cove.webp" alt="" width={720} height={960} sizes="60px" />
        <Image src="/models/sunset.webp" alt="" width={720} height={960} sizes="60px" />
        <Image src="/models/cove.webp" alt="" width={720} height={960} sizes="60px" />
      </span>
    );
  }
  if (kind === "note") {
    return (
      <span className="ph-thumb ph-thumb-note">
        <i />
        <em className="note">just because</em>
      </span>
    );
  }
  return (
    <span className="ph-thumb">
      <Image
        src={kind === "flower" ? "/flowers/classic_tulip.webp" : "/models/sunset.webp"}
        alt=""
        width={720}
        height={960}
        sizes="70px"
      />
    </span>
  );
}

/* ── The tab bar, on both ───────────────────────────────────────────────── */

function TabBar({ active }: { active: "home" | "memories" }) {
  return (
    <div className="ph-tabs">
      <span className={`ph-tab${active === "home" ? " is-on" : ""}`}>
        <svg viewBox="0 0 24 24"><path d="M4 11 12 4l8 7v8a1 1 0 0 1-1 1h-4v-6H9v6H5a1 1 0 0 1-1-1Z" /></svg>
        Home
      </span>
      <span className="ph-tab">
        <svg viewBox="0 0 24 24"><path d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9l-5 4Z" /></svg>
        Chat
      </span>
      <span className="ph-tab ph-tab-mark">
        <Image src="/mark.png" alt="" width={28} height={28} sizes="28px" />
      </span>
      <span className={`ph-tab${active === "memories" ? " is-on" : ""}`}>
        <svg viewBox="0 0 24 24"><path d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Zm2 11 4-5 3 3.5 2.5-2.5L18 17Z" /></svg>
        Memories
      </span>
      <span className="ph-tab">
        <svg viewBox="0 0 24 24"><rect x="4" y="4" width="7" height="7" rx="2" /><rect x="13" y="4" width="7" height="7" rx="2" /><rect x="4" y="13" width="7" height="7" rx="2" /><rect x="13" y="13" width="7" height="7" rx="2" /></svg>
        Together
      </span>
    </div>
  );
}

/** The pair, arranged the way the reference arranges them. */
export default function AppPhones() {
  return (
    <div className="app-phones">
      <div className="app-stage">
        <MemoriesPhone />
        <HomePhone />
      </div>
    </div>
  );
}
