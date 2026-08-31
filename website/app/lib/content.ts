/**
 * All landing-page copy, sourced from ../../overview.md (doc version 3.0).
 * Kept in one place so the site can be re-synced when the overview changes.
 */

/* ── The five UX principles (overview § Design Philosophy) ──────────────── */

export const principles = [
  {
    emoji: "🎯",
    title: "Simplicity",
    text: "One primary action per day. Send your tulip — that's the whole job.",
  },
  {
    emoji: "🔁",
    title: "Ritual",
    text: "A consistent daily interaction at meaningful times, not an endless feed.",
  },
  {
    emoji: "✨",
    title: "Delight",
    text: "Smooth animations, haptic feedback, and small surprising moments.",
  },
  {
    emoji: "🔒",
    title: "Privacy",
    text: "An intimate space for just two people. No social feed, ever.",
  },
  {
    emoji: "👀",
    title: "Presence",
    text: "Widgets keep your partner visible throughout your whole day.",
  },
];

/* ── Core features (overview § Features → MVP) ──────────────────────────── */

export type Feature = {
  emoji: string;
  title: string;
  summary: string;
  points: string[];
  status?: string;
};

export const coreFeatures: Feature[] = [
  {
    emoji: "🌷",
    title: "Daily Tulip Exchange",
    summary:
      "The heart of Dayflower — one flower a day, chosen on purpose and carrying a meaning.",
    points: [
      "Send one flower per day to your partner",
      "Choose from varieties that each carry a symbolic meaning",
      "Add a personalized note, set in quote-style italics",
      "Delivery confirmation and ✓ Seen status",
      "A visual history of every flower sent and received",
    ],
  },
  {
    emoji: "💓",
    title: "Heartbeat System",
    summary:
      "For the moments between flowers, when you just want them to know you're there.",
    points: [
      "Tap to send an instant emotional pulse",
      "Real-time delivery with haptic feedback and a ripple ring",
      "Live tap count — “Tapped 5× today · Sunshine felt each one”",
      "Spontaneous connection without needing words",
    ],
  },
  {
    emoji: "✈️",
    title: "Reunion Countdown",
    summary: "The date you're both counting toward, always one glance away.",
    points: [
      "Set the reunion date, destination, and a note",
      "Live countdown ticking every second — days, hours, minutes, seconds",
      "Both partners see the same countdown in real time",
      "Edit the details any time via a bottom sheet",
      "Notification reminders as the date approaches (planned)",
    ],
  },
  {
    emoji: "📸",
    title: "Photo Booth",
    summary:
      "A shared polaroid album that behaves like a real photo booth — including the wait.",
    points: [
      "Polaroid-style shared album for the two of you",
      "10 built-in templates across Duo and Solo categories",
      "Full upload → develop → stack flow, animated end to end",
      "Detail view with a blurred backdrop and sepia aging effect",
    ],
  },
  {
    emoji: "🌙",
    title: "Dates & Cycle Awareness",
    summary:
      "Everything time-related about the two of you, in one place — clocks, cycle, milestones.",
    points: [
      "Live dual-timezone clocks, editable per partner",
      "Partner cycle tracking with phase awareness (opt-in, privacy toggle)",
      "Shared events and milestones with live countdown pills",
    ],
  },
  {
    emoji: "📱",
    title: "Home Screen Widgets",
    summary:
      "Your person on your home screen, so the ritual doesn't depend on opening an app.",
    status: "Planned",
    points: [
      "Today's Tulip widget — the latest flower received, plus its note",
      "Heartbeat widget — quick-send straight from the home screen",
      "Countdown widget — days until your next reunion",
      "Small, medium, and large sizes",
      "Live updating with soft animations",
    ],
  },
];

/* ── Post-MVP nice-to-haves (overview § Features → Nice-to-Have) ────────── */

export const niceToHaves = [
  {
    emoji: "🔥",
    title: "Streak milestones",
    text: "Celebrations at 7, 30, and 100 days, flame badges, and historical stats.",
    tag: null,
  },
  {
    emoji: "🩹",
    title: "Streak repair",
    text: "Recover a streak you broke while travelling or offline.",
    tag: "Premium",
  },
  {
    emoji: "🌹",
    title: "Rare & seasonal variants",
    text: "Flower varieties that only exist for subscribers, or only for a season.",
    tag: "Premium",
  },
  {
    emoji: "🌻",
    title: "Full garden view",
    text: "Every flower you have ever sent, collected into one growing garden.",
    tag: null,
  },
  {
    emoji: "📷",
    title: "Flower recognition",
    text: "An on-device TFLite model identifies real flowers through your camera.",
    tag: null,
  },
  {
    emoji: "♾️",
    title: "Unlimited photo strips",
    text: "The free tier caps your booth pairs — Premium removes the limit.",
    tag: "Premium",
  },
  {
    emoji: "🎨",
    title: "Custom tulip designs",
    text: "Upload or personalize your own flower artwork.",
    tag: null,
  },
];

/* ── The flower catalog, mirrored from lib/features/tulip/domain/flower_catalog.dart ── */

export const flowers = [
  { emoji: "🌷", name: "Classic Tulip", meaning: "Declaration of love", color: "#D64270" },
  { emoji: "💐", name: "Full Bouquet", meaning: "You mean everything", color: "#8B5CF6" },
  { emoji: "🌸", name: "Cherry Blossom", meaning: "Gentle & tender", color: "#F472B6" },
  { emoji: "🪷", name: "Lotus", meaning: "Pure devotion", color: "#C084FC" },
  { emoji: "🌺", name: "Hibiscus", meaning: "Rare beauty", color: "#EF4444" },
  { emoji: "🌼", name: "Daisy", meaning: "Joyful & true", color: "#F59E0B" },
  { emoji: "🌻", name: "Sunflower", meaning: "Always watching", color: "#E8922A" },
];

/* ── The app tour (overview § Screens) ──────────────────────────────────── */

export type Screen = {
  route: string;
  name: string;
  tagline: string;
  points: string[];
};

export const screens: Screen[] = [
  {
    route: "/app/nest",
    name: "Nest",
    tagline: "The daily glanceable dashboard, ticking every second.",
    points: [
      "Time-aware greeting plus your partner's live local time and streak day",
      "Today's Dayflower — the flower received today, with meaning, note, and timestamp",
      "Heartbeat card with ripple rings, elastic scale, and haptics",
      "Stats row: streak days · total heartbeats · days apart",
      "Cycle teaser and a dark reunion hero card with the live countdown",
    ],
  },
  {
    route: "/app/tulip",
    name: "Tulip",
    tagline: "The core ritual — one flower a day, each with a meaning.",
    points: [
      "Today's flower in a large arch card, emoji set in a frosted semicircle",
      "Quote and sender tag below, scattered sparkle decorations",
      "Send a Flower CTA in the signature gradient",
      "Scrollable history: colour-matched emoji badge, relative time, italic note, ✓ Seen",
    ],
  },
  {
    route: "/app/send",
    name: "Send Flower",
    tagline: "The full-screen composer for the one gesture that matters.",
    points: [
      "Live preview card that fades between varieties as you choose",
      "Horizontal rail of emoji-only chips with an animated selection border",
      "Flower grid grouped by category — All · Classic · Special · Seasonal",
      "Note field and Send button pinned to the bottom, always reachable",
    ],
  },
  {
    route: "/app/booth",
    name: "Photo Booth",
    tagline: "A shared album styled as a physical polaroid booth.",
    points: [
      "Polaroid stack — newest straight on top, up to 3 fanned behind it",
      "Scrollable thumbnail strip; tap any to bring it to the front",
      "New pair flow: template picker → upload → 1.6s developing animation",
      "All-pairs grid with alternating tilt, and a full-screen detail modal",
    ],
  },
  {
    route: "/app/dates",
    name: "Dates",
    tagline: "Three tabs for everything time-related about the two of you.",
    points: [
      "Reunion — live countdown hero, editable details, and Our Clocks with an hour-difference pill",
      "Cycle — phase banner, stats row, colour-coded calendar, partner support tips, share toggle",
      "Events — anniversaries, birthdays, monthsaries and custom dates with live countdown pills",
    ],
  },
  {
    route: "/app/us",
    name: "Us",
    tagline: "A little home page for the couple.",
    points: [
      "Couple card with overlapping avatar initials, relationship duration, and streak",
      "Stats grid: tulips sent · streak · hearts · days together",
      "Endearments — editable real names and pet names, previewed live",
      "Dayflower Premium card with the feature list and unlock button",
    ],
  },
  {
    route: "/app/settings",
    name: "Settings",
    tagline: "Grouped cards for account, notifications, appearance, and privacy.",
    points: [
      "Account — profile, paired partner info, disconnect",
      "Notifications — flower alerts, haptic heartbeats, home screen widget",
      "Appearance — dark mode toggle",
      "Privacy & data — cycle privacy, export data, delete account",
      "About — version, terms, privacy policy, feedback",
    ],
  },
];

/* ── Photo booth templates (overview § Screens → Photo Booth) ───────────── */

export const boothTemplates = [
  { n: 1, name: "Classic Polaroid", style: "White frame, side-by-side photos, Georgia caption", type: "Duo", swatch: "#FFFFFF", ink: "#1F1B24" },
  { n: 2, name: "Film Strip", style: "Dark frame, perforations, 4 cells, amber KODAK text", type: "Duo", swatch: "#1A1A1A", ink: "#F5C451" },
  { n: 3, name: "Scrapbook", style: "Cream background, 2×2 rotated grid, coloured tape corners", type: "Duo", swatch: "#F5E9D7", ink: "#7A5C3E" },
  { n: 4, name: "Neon Booth", style: "Deep purple with glowing neon circle frames", type: "Duo", swatch: "#2A0F4A", ink: "#E879F9" },
  { n: 5, name: "Split Frame", style: "Diagonal clip-path split into two-tone halves", type: "Duo", swatch: "#3B2F58", ink: "#F0709F" },
  { n: 6, name: "Locket", style: "Warm pink, oval photo frames, a heart between them", type: "Duo", swatch: "#FFD9E4", ink: "#B53157" },
  { n: 7, name: "Vintage", style: "Parchment background, sepia filter, corner ✦ ornaments", type: "Duo", swatch: "#E8DCC0", ink: "#6B5537" },
  { n: 8, name: "Solo Portrait", style: "Single wide photo slot on a gradient background", type: "Solo", swatch: "#F0709F", ink: "#FFFFFF" },
  { n: 9, name: "Solo Film", style: "3-cell solo film strip with varying emoji sizes", type: "Solo", swatch: "#22182F", ink: "#A99BC4" },
  { n: 10, name: "Aesthetic", style: "Soft purple, floral accent, minimal border", type: "Solo", swatch: "#E5DBFA", ink: "#6C4A8B" },
];

/* ── Flows (overview § User Flows) ──────────────────────────────────────── */

export const onboardingSteps = [
  "Download the app",
  "Create your account",
  "Generate your unique connection code",
  "Your partner enters the code to connect",
  "Set your real names and pet names",
  "Optionally set your first reunion date",
  "Optionally enable notifications",
];

export const dayInTheLife = [
  {
    time: "Morning",
    emoji: "🌅",
    points: [
      "Open the app, or just tap the widget",
      "See today's flower from your partner",
      "Compose yours — pick a variety, write the note",
      "Send, and watch it go",
    ],
  },
  {
    time: "Through the day",
    emoji: "☀️",
    points: [
      "Tap heartbeats whenever they cross your mind",
      "Check the live reunion countdown",
      "Glance at their local time from the widget",
    ],
  },
  {
    time: "Evening",
    emoji: "🌙",
    points: [
      "Look back through the flower history",
      "Check their cycle phase so you know how to show up",
      "Think about tomorrow's note",
    ],
  },
];

/* ── Pricing (overview § Monetization) ──────────────────────────────────── */

export const freeTier = [
  "Core features — tulip exchange, heartbeats, countdown",
  "Basic flower varieties",
  "Standard home screen widgets",
  "30-day flower history",
  "Up to 10 photo booth pairs",
];

export const premiumTier = [
  "Rare & seasonal flower variants",
  "Full garden view — your all-time collection",
  "Unlimited photo booth strips",
  "Flower recognition via on-device TFLite",
  "Streak repair",
  "Unlimited history",
  "Advanced widgets",
  "Priority support",
];

/* ── Competitive landscape (overview § Competitive Landscape) ───────────── */

export const competitors = [
  { app: "Between", core: "Couple messaging + calendar", diff: "Dayflower is ritual-first, not messaging-first" },
  { app: "Lasting", core: "Relationship exercises", diff: "Dayflower is ambient presence, not scheduled sessions" },
  { app: "LokLok", core: "Shared lock screen doodles", diff: "Dayflower is symbolic and emotional, not purely visual" },
  { app: "Paired", core: "Daily questions", diff: "Dayflower doesn't need both partners online at once" },
  { app: "Raft", core: "Shared journaling", diff: "Dayflower is lighter — one gesture, not essays" },
];

/* ── Future builds (overview § Future Builds & Updates) ─────────────────── */

export type RoadmapGroup = {
  emoji: string;
  group: string;
  items: { name: string; text: string; tag?: string }[];
};

export const roadmap: RoadmapGroup[] = [
  {
    emoji: "💬",
    group: "Connection & Communication",
    items: [
      {
        name: "Dayflower Chat",
        text: "A sacred channel kept separate from your everyday messaging — reserved for celebrations, voice messages, milestones, and love letters.",
      },
      {
        name: "Affirmations after a fight",
        text: "Mark that you had a rough moment and the app surfaces healing affirmations and gentle prompts to reconnect.",
      },
      {
        name: "SOS",
        text: "One tap sends an “I need you right now” signal — a priority notification, no words required.",
      },
      {
        name: "Anniversary special send",
        text: "On special dates, unlock an interactive mini-page: a memory collage, a short reel, or an animated love letter.",
      },
    ],
  },
  {
    emoji: "🕯️",
    group: "Daily Rituals & Reminders",
    items: [
      {
        name: "1:43 & 11:11 reminders",
        text: "Push notifications at times that mean something to you, landing for both partners at once across time zones.",
      },
      {
        name: "The 11:11 moment",
        text: "Open the app at 11:11 and something happens — a synchronized animation, a shared wish, a small piece of magic.",
      },
      {
        name: "Set mood",
        text: "A daily check-in that sets the emotional tone, influencing flower suggestions and partner support tips.",
      },
      {
        name: "Set dinner date",
        text: "Plan a virtual or physical dinner inside the app, with a countdown and notes (“wear something nice”).",
      },
      {
        name: "What to eat, where to eat",
        text: "A spin wheel and cuisine picker for when neither of you can decide. Works virtual or in person.",
      },
    ],
  },
  {
    emoji: "🧠",
    group: "Flower & Content Intelligence",
    items: [
      {
        name: "AI flower suggestion",
        text: "Once your partner sets their mood, the app suggests the variety and meaning that fits it best.",
      },
      {
        name: "Caption suggestion",
        text: "Starting points for booth captions and flower notes — yours to edit, never a replacement for your voice.",
      },
      {
        name: "30-day flower pack",
        text: "A curated monthly drop of rare, seasonal, and themed flowers.",
        tag: "Premium",
      },
      {
        name: "Dedicated flower picker",
        text: "A full-screen flower keyboard organized by meaning, season, and emotion.",
      },
      {
        name: "Flower recognition",
        text: "Point your camera at a real flower; an on-device model identifies it and offers to send that variety.",
      },
    ],
  },
  {
    emoji: "🖼️",
    group: "Photo & Media",
    items: [
      {
        name: "Digital photo album",
        text: "A full shared library beyond the booth — any photo, organized chronologically, visible only to you two.",
      },
      {
        name: "Stories",
        text: "Share a moment that disappears after 24 hours, so it stays fresh and present.",
      },
      {
        name: "Future baby looks",
        text: "A lighthearted face-morph of what your future children might look like.",
      },
      {
        name: "Camera softening filter",
        text: "A gentle beauty filter for booth uploads and video calls.",
      },
      {
        name: "Share to social",
        text: "Export any booth frame or milestone card, formatted and branded, straight to Instagram or TikTok.",
      },
    ],
  },
  {
    emoji: "🎮",
    group: "Shared Activities & Games",
    items: [
      {
        name: "Rock paper scissors",
        text: "Settle the small stuff — who picks dinner, who does the dishes. Real-time or async.",
      },
      {
        name: "Gym together",
        text: "Both log a workout at the same time and see “Sunshine is also at the gym 💪” on your home screen.",
      },
      {
        name: "Save together",
        text: "Shared savings targets, travel funds, and yearly goals you both track and celebrate.",
      },
      {
        name: "Couple to-do list",
        text: "A shared checklist with text, links, and images — gift ideas, bucket lists, next-visit plans.",
      },
    ],
  },
  {
    emoji: "🗺️",
    group: "Map & Places",
    items: [
      {
        name: "Travel map",
        text: "An interactive map of where you have been, where you want to go, and where each of you is right now. Pins hold photos and memories, and the map grows as you do.",
      },
    ],
  },
  {
    emoji: "🎊",
    group: "Celebrations & Special Days",
    items: [
      {
        name: "Heart Day",
        text: "A February 14 mode — animated home screen, exclusive flower variants, a themed booth frame.",
      },
      {
        name: "Women's Month",
        text: "A March mode with daily appreciation prompts, a special flower selection, and recognition cards.",
      },
      {
        name: "Boyfriend & Girlfriend Day",
        text: "Couple appreciation days with a gratitude prompt and a shareable card.",
      },
    ],
  },
  {
    emoji: "🧭",
    group: "Navigation & UX",
    items: [
      {
        name: "Swipe navigation",
        text: "Swipe between the five main screens like flipping through a journal.",
      },
      {
        name: "Expressive app icons",
        text: "Alternate flower icons (🌷🌻🌸🌹) you can set from Settings, so the app feels like yours.",
      },
    ],
  },
  {
    emoji: "🧸",
    group: "Commerce & Brand",
    items: [
      {
        name: "Dayflower Store",
        text: "Plushies, crochet pieces, and branded keepsakes drawn from the app's aesthetic.",
      },
      {
        name: "Bumbumbee",
        text: "A brand mascot for celebrations, loading states, and milestone moments.",
      },
    ],
  },
];
