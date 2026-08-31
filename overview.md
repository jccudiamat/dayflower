# Dayflower — Project Overview

> A private mobile app for long-distance couples. Built in Flutter, backed by Supabase.
> Current users: **Bunny** (Manila 🇵🇭) & **Sunshine** (London 🇬🇧).

---

## Core Concept

**Dayflower** is built around the metaphor of tulips — each day, partners exchange a digital flower with a personalized note, creating a daily ritual of connection. The name is a play on "tulip" and "two lips," emphasizing both the floral metaphor and intimate communication between two people.

The app creates intimate digital touchpoints that help partners feel closer despite physical distance. It is not a messaging app — it is a ritual app. One primary gesture per day, done with intention.

---

## Target Platform

| | |
|---|---|
| **Platforms** | iOS & Android (Flutter) |
| **Minimum iOS** | iOS 14+ |
| **Minimum Android** | Android 8.0 (API 26+) |
| **Flutter version** | 3.16+ stable / Dart 3.0+ |

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart 3.0) |
| State management | Riverpod 2.x |
| Navigation | GoRouter 13+ |
| Backend / Auth | Supabase (wiring in progress) |
| Local storage | Hive 2.x |
| Animations | Rive + custom Flutter animations |
| Widgets | home_widget package |
| Notifications | supabase_messaging + flutter_local_notifications |
| Design system | Custom — `AppColors`, `AppSpace`, `AppRadius`, `AppText` |
| Fonts | Georgia (display), system sans-serif (body) |

**Additional packages:** `vibration` · `timezone` · `intl` · `cached_network_image`

---

## App Structure

```
lib/
├── app.dart                        # MaterialApp root
├── app_router.dart                 # GoRouter + auth redirect + SplashScreen
├── core/
│   ├── constants/
│   ├── providers/                  # supabase_provider (authStateProvider)
│   ├── theme/                      # AppColors, AppTheme, design_tokens
│   └── widgets/                    # AppBottomNav, FeatureScreenHeader, shared atoms
└── features/
    ├── auth/                       # LoginScreen, AuthRepository, AuthNotifier
    ├── home/                       # Nest / HomeScreen (dashboard)
    ├── tulip/                      # TulipScreen + SendFlowerScreen
    ├── booth/                      # BoothScreen (photo booth)
    ├── dates/                      # DatesScreen (countdown · cycle · events)
    ├── us/                         # UsScreen (couple profile)
    └── settings/                   # SettingsScreen
```

---

## Features

### MVP (Built / In Progress)

#### 1. Daily Tulip Exchange
- Send one flower per day to your partner
- Choose from multiple flower varieties, each with a symbolic meaning
- Add a personalized italic note (quote-style)
- Delivery confirmation and ✓ Seen status
- Visual history of all sent and received flowers

#### 2. Heartbeat System
- Tap to send an instant emotional pulse to your partner
- Real-time delivery with haptic feedback and ripple ring animation
- Tap count shown live ("Tapped 5× today · Sunshine felt each one")
- Spontaneous connection without needing words

#### 3. Reunion Countdown
- Set upcoming reunion date, destination, and note
- Live countdown ticking every second (days / hrs / min / sec)
- Both partners see the same countdown in real-time
- Edit reunion details via bottom sheet
- Notification reminders as date approaches *(planned)*

#### 4. Photo Booth
- Polaroid-style shared photo album for the couple
- 10 built-in templates across Duo and Solo categories
- Full upload → develop → stack flow with animations
- Detail modal with blurred backdrop + sepia aging effect
*(See full breakdown in Screens section)*

#### 5. Dates & Cycle Awareness
- Live dual-timezone clocks (editable)
- Partner cycle tracking with phase awareness (opt-in, privacy toggle)
- Shared events / milestones with countdown pills

#### 6. Home Screen Widgets *(planned)*
- **Today's Tulip Widget** — shows latest received flower + note
- **Heartbeat Widget** — quick-send button from the home screen
- **Countdown Widget** — days until next reunion
- Multiple sizes (small, medium, large)
- Live updating with soft animations

### Nice-to-Have (Post-MVP)

- **Streak milestones** — celebrations at 7, 30, 100 days; flame badges; historical stats
- **Streak repair** — Premium feature to recover a broken streak
- **Rare & seasonal flower variants** — Premium-only varieties
- **Full garden view** — visual collection of all flowers ever sent
- **Flower recognition** — TFLite on-device model to identify real flowers via camera
- **Unlimited photo strips** — free tier will have a limit; Premium removes it
- **Custom tulip designs** — upload or personalize flower artwork

---

## Screens

### 1. Splash & Auth
- **SplashScreen** — dark gradient, Dayflower logo + wordmark, spinner. Resolves auth state via Riverpod then redirects.
- **LoginScreen** — phone number + OTP entry.
- **OnboardingScreen** / **PairingScreen** — placeholders, not yet built.
- Auth bypass flag (`kBypassAuthForHomePreview = true`) lets dev mode skip login and land straight on the Nest.

---

### 2. Nest (Home Dashboard) — `/app/nest`

The daily glanceable dashboard. Ticks every second for live countdowns and partner time.

| Card | What it does |
|---|---|
| **Greeting** | Time-aware ("Morning / Afternoon / Evening, Bunny 🌷") + Sunshine's live London time + streak day |
| **Today's Dayflower** | Shows flower received today (type, meaning, italic note, timestamp). Floating tulip animates up-down. Links to Send Flower. |
| **Heartbeat** | Tap the heart to send a pulse. Ripple rings + elastic scale + haptic feedback. Tap count live. |
| **Stats row** | Streak days · Total heartbeats · Days apart — three dark mini-cards |
| **Cycle card** | Current phase teaser ("Sunshine · PMS · Extra patience today"). Links to Dates > Cycle. |
| **Reunion card** | Dark hero card. Live countdown (days / hrs / min) to next reunion. City + date. Links to Dates > Reunion. |

---

### 3. Tulip (Flower Messaging) — `/app/tulip`

The core daily ritual — one flower per day, each with a meaning and optional note.

- **Today's flower card** — Large arch widget with flower emoji in a frosted semicircle. Gradient purple card. Scattered sparkle decorations. Quote + sender tag below.
- **Send a Flower button** — Rose gradient CTA → navigates to Send Flower.
- **Flower history** — Scrollable card list. Each card: gradient emoji badge (52×52, color-matched to flower type) + flower name + relative time + italic note + ✓ Seen indicator.

---

### 4. Send Flower — `/app/send`

Full-screen flower composer.

- **Live preview card** — Appears at top on selection. Shows emoji (large), flower name (bold), meaning (italic). Swaps with `AnimatedSwitcher` fade.
- **Type rail** — Horizontal scroll of 56×56 emoji-only chips (no labels). Animated selection border.
- **Flower grid** — Scrollable grid grouped by category tabs (All · Classic · Special · Seasonal). Lives in `Expanded` — never pushes the footer.
- **Note field + Send button** — Always pinned at bottom regardless of grid height.

---

### 5. Photo Booth — `/app/booth`

A couple's shared photo album styled as a physical polaroid booth.

- **Polaroid stack** — Most recent pair sits straight on top. Up to 3 past polaroids fan out behind it at varying angles and opacities. Newest gets a red "NEW" badge.
- **Thumbnail row** — Scrollable horizontal strip of mini polaroids. Tap any to swap it to the front with a smooth transition.
- **New pair flow** — Tap **＋ New pair** → **Template picker** (Duo / Solo tabs, 10 templates) → **Upload screen** (1 or 2 photo slots by template, caption field, accent-colored Generate button) → 1.6s developing animation → new pair lands at top of stack.
- **All pairs grid** — 2-column grid of every polaroid, each card slightly tilted alternating left/right. Tap any to open the detail modal.
- **Detail modal** — Full-screen scale-up pop, dark blurred backdrop, Save + Close buttons. Caption in handwriting font. Older photos carry a subtle sepia tint.

**10 built-in templates:**

| # | Name | Style | Type |
|---|---|---|---|
| 1 | Classic Polaroid | White frame, side-by-side photos, Georgia caption | Duo |
| 2 | Film Strip | Dark #1A1A1A, perforations, 4 cells, amber KODAK text | Duo |
| 3 | Scrapbook | Cream bg, 2×2 rotated grid, colored tape corners | Duo |
| 4 | Neon Booth | Deep purple, glowing neon circle frames | Duo |
| 5 | Split Frame | Diagonal clip-path split, two-tone halves | Duo |
| 6 | Locket | Warm pink, oval photo frames, heart between | Duo |
| 7 | Vintage | Parchment bg, sepia color filter, corner ✦ ornaments | Duo |
| 8 | Solo Portrait | Single wide photo slot, gradient background | Solo |
| 9 | Solo Film | 3-cell solo film strip, varying emoji sizes | Solo |
| 10 | Aesthetic | Soft purple bg, floral accent, minimal border | Solo |

---

### 6. Dates — `/app/dates`

Three-tab screen for all time-related couple data.

**Reunion tab**
- Live countdown hero (dark gradient): days / hrs / min / sec ticking every second.
- Editable reunion details via bottom sheet (title, destination, date, note, event type).
- "Our Clocks" card — two live clocks side-by-side, timezone-aware. Shows hour difference pill.

**Cycle tab**
- Toggle between "Her" and "Him" perspective.
- Phase banner for today (Period / Fertile / Ovulation / PMS) with color-coded context tip.
- Cycle stats row: next period, current cycle day, average length.
- Interactive monthly calendar — days color-coded by phase. Tap to inspect.
- Support tips card for the partner (phase-specific suggestions).
- Share toggle — partner can see/hide cycle data.

**Events tab**
- Sorted list of upcoming milestones (anniversaries, birthdays, monthsaries, custom).
- Each card: emoji icon, name, date, live "X days" countdown pill.
- Add / edit / delete via bottom sheet with date picker.

---

### 7. Us (Couple Profile) — `/app/us`

- **Couple card** — Overlapping avatar initials + relationship duration + streak.
- **Stats grid** — 4 dark mini-tiles: Tulips sent · Streak · Hearts · Days together.
- **Endearments** — Editable fields for real names and pet names. Live preview in couple card header.
- **Dayflower Premium card** — Dark gradient upsell. Feature list + Unlock button (not yet wired).

---

### 8. Settings — `/app/settings`

Standard iOS-style grouped settings cards.

| Section | Items |
|---|---|
| Account | Profile (name, photo), paired partner info, disconnect |
| Notifications | Flower alerts, haptic heartbeats, home screen widget |
| Appearance | Dark mode toggle |
| Privacy & data | Cycle privacy, export data, delete account |
| About | Version, Terms, Privacy Policy, feedback |

Sign out button at the bottom.

---

## Navigation

GoRouter shell route wraps all logged-in screens. Bottom nav has 5 tabs: **Nest · Tulip · Booth · Dates · Us**. Settings is a sub-route of Us (no bottom nav).

```
/                   → SplashScreen
/login              → LoginScreen
/onboarding         → OnboardingScreen (placeholder)
/pair               → PairingScreen (placeholder)
/app/nest           → HomeScreen (Nest)
/app/tulip          → TulipScreen
/app/send           → SendFlowerScreen
/app/booth          → BoothScreen
/app/dates          → DatesScreen
/app/us             → UsScreen
/app/settings       → SettingsScreen
```

---

## User Flows

### Onboarding
1. Download app
2. Create account (phone number / OTP)
3. Generate unique connection code
4. Partner enters code to connect
5. Set real names and pet names (endearments)
6. Optional: set first reunion date
7. Optional: enable notifications

### Daily Usage

**Morning**
1. Open app or tap widget
2. See today's flower from partner (push notification)
3. Compose your flower — pick variety, write note
4. Send (shows sending animation)

**Throughout the day**
- Tap heartbeats spontaneously
- Check live reunion countdown
- Glance at partner's time via widget

**Evening**
- Review flower history
- Check cycle phase for partner awareness
- Plan tomorrow's note

---

## Design Philosophy

### Visual Identity
- **Primary**: Soft rose `#E94E77` — brand, CTAs, active states
- **Secondary**: Deep purple `#6C4A8B` — accent, cycle, premium
- **Background**: Warm cream `#F6F1F4` — app background
- **Dark surfaces**: `#160810` / `#2D0A20` — hero cards, reunion, modals
- **Typography**: Georgia for all display/emotional text; system sans for body

### UX Principles
1. **Simplicity** — One primary action per day (send tulip)
2. **Ritual** — Consistent daily interaction at meaningful times
3. **Delight** — Smooth animations, haptic feedback, surprising moments
4. **Privacy** — An intimate space for just two people, no social feed
5. **Presence** — Widgets keep your partner visible throughout the day

### Design System
**Palette** (`AppColors`): brand `#E94E77` · dark `#B53157` · light `#F27FA0` · blush `#FFF2F6` · ink `#1F1B24` · muted `#9D8CA8` · border `#ECE4EB`

**Spacing** (`AppSpace`): `xxs=4 · xs=8 · sm=12 · md=20 · lg=28`

**Radius** (`AppRadius`): `sm=10 · lg=16 · xl=24 · pill=999`

---

## Backend (Supabase — in progress)

| Table (planned) | Purpose |
|---|---|
| `users` | Auth + profile (name, pet name, timezone) |
| `pairs` | Links two user IDs as a couple |
| `flower_messages` | Sent flowers (type, note, sent_at, seen_at) |
| `heartbeats` | Heartbeat events between partners |
| `booth_pairs` | Photo booth polaroid pairs (photo URLs, caption, template, created_at) |
| `cycle_data` | Menstrual cycle log (shared between partners) |
| `events` | Couple milestones and countdowns |

All `TODO: Replace with Supabase` comments mark mock data insertion points in the UI.

---

## Monetization

### Free Tier
- Core features: tulip exchange, heartbeats, countdown
- Basic flower varieties
- Standard home screen widgets
- 30-day flower history
- Up to 10 photo booth pairs

### Premium — $4.99 / month per couple
- Rare & seasonal flower variants
- Full garden view (all-time flower collection)
- Unlimited photo booth strips
- Flower recognition via TFLite (camera → identify real flowers)
- Streak repair
- Unlimited history
- Advanced widgets
- Priority support

---

## Competitive Landscape

| App | Core Feature | How Dayflower Differs |
|---|---|---|
| **Between** | Couple messaging + calendar | Dayflower is ritual-first, not messaging-first |
| **Lasting** | Relationship exercises | Dayflower is ambient presence, not sessions |
| **LokLok** | Shared lock screen doodles | Dayflower is symbolic + emotional, not visual |
| **Paired** | Daily questions | Dayflower doesn't require both partners online simultaneously |
| **Raft** | Shared journaling | Dayflower is lighter — one gesture, not essays |

**Dayflower's differentiators:** Simpler · More ritual · Premium design · Widgets keep partner visible all day · Symbolic language (flowers) over functional communication

---

## Success Metrics

| Metric | Target |
|---|---|
| Daily Active Users (DAU) | Both partners opening app daily |
| Tulip exchange completion rate | % of days both send a flower |
| Avg heartbeats sent per day | Per couple |
| Streak retention | 7-day, 30-day cohort retention |
| Widget interaction rate | Taps from widget vs. direct open |
| Notification open rate | Push → app open |
| Time to send first tulip | Onboarding to first send |

---

## Development Phases

| Phase | Scope | Timeline |
|---|---|---|
| **Phase 1 — MVP** | Auth + pairing, tulip exchange, heartbeat, countdown, iOS + Android | 8–10 weeks |
| **Phase 2 — Widgets** | Home screen widgets (all 3 types), live updates, deep linking | 3–4 weeks |
| **Phase 3 — Polish** | Animations, haptics, onboarding flow, edge cases | 2–3 weeks |
| **Phase 4 — Nice-to-Haves** | Streak tracking, cycle tracking, extra flower varieties, settings | 4–6 weeks |

---

## Risk Assessment

### Technical
- **Real-time sync reliability** — Mitigate with Supabase Realtime; offline queue fallback
- **Widget update frequency** — iOS/Android background refresh limits; use push-triggered updates
- **Timezone handling** — Extensive testing across DST transitions needed
- **Push notification delivery** — Cannot guarantee 100%; supplement with in-app banners

### Product
- **User retention** — Daily habit formation is hard; ritual design + streak system mitigates
- **Partner dependency** — Both must use consistently; onboarding must pair both quickly
- **Notification fatigue** — Balance presence vs. annoyance; respect quiet hours
- **Feature creep** — Keep focused on the core floral ritual; everything else is secondary

### Business
- **Niche market** — LDR couples are a defined but limited audience
- **Seasonal usage** — May spike during separation periods; plan for churn during visits
- **Easy to copy** — Core concept is simple; differentiate on design quality and emotional depth
- **Privacy concerns** — Sensitive relationship and health data; strong encryption + clear privacy policy essential

---

## Next Steps

1. Wire Supabase auth (replace `kBypassAuthForHomePreview`)
2. Build OnboardingScreen and PairingScreen
3. Connect `flower_messages` table to TulipScreen + SendFlowerScreen
4. Connect `heartbeats` table to Heartbeat card
5. Connect `booth_pairs` table to BoothScreen
6. Implement push notifications (flower received, heartbeat, reunion reminder)
7. Build home screen widgets (Phase 2)
8. Set up CI/CD pipeline
9. Plan beta testing with real LDR couples

---

---

## Future Builds & Updates

> Ideas and features for future versions — not prioritized, not scheduled. Captured here so nothing gets lost.

---

### Connection & Communication

**2Lip Chat**
A dedicated sacred channel separate from WhatsApp/iMessage. Not a replacement for everyday messaging — reserved for important moments: celebrations, heartfelt voice messages, milestone announcements, and love letters. Treated with more ceremony than a normal chat.

**Affirmations after a fight**
When a partner manually marks "we had a rough moment," the app surfaces healing affirmations, conversation starters, and gentle prompts to reconnect. Helps couples move through conflict with intention rather than silence.

**SOS**
A single tap that sends an instant "I need you right now" signal to the partner — no words needed. Partner gets a priority notification and sees the SOS state on the home screen.

**Anniversary special send**
On special dates (anniversary, monthsary, etc.), unlock the ability to send an interactive mini-page — a curated collage of memories, a short video reel, or an animated love letter — something more than a flower or a note.

---

### Daily Rituals & Reminders

**1:43 & 11:11 reminders**
Push notifications at exactly 1:43 and 11:11 (AM and/or PM) — personally meaningful times for the couple. Both partners get the reminder simultaneously, creating a shared moment across time zones.

**11:11 feature**
A special in-app experience triggered when either partner opens the app at 11:11. Could be a synchronized animation, a shared wish, or a prompt — a small magical moment built into the daily ritual.

**Set mood**
A daily mood check-in (morning or whenever) that sets the emotional tone for the day. Mood influences flower suggestions and surfaces relevant affirmations or support tips for the partner.

**Set dinner date**
Plan and schedule a virtual or physical dinner date inside the app. Sends a reminder to both partners at the right time with a countdown and optional notes ("wear something nice").

**What to eat / where to eat**
A fun decision tool for when the couple can't decide — a spin wheel, cuisine picker, or restaurant suggester based on location and mood. Works for both virtual dinner dates and in-person meetups.

---

### Flower & Content Intelligence

**AI flower suggestion based on partner's mood**
After the partner sets their mood, the app suggests the most fitting flower variety and meaning to send. Reduces decision fatigue and makes the gesture feel more thoughtful.

**Caption suggestion**
AI-generated caption ideas for photo booth frames and flower notes. The partner picks or edits — it's a starting point, not a replacement for their voice.

**30-day flower pack (Premium)**
A curated monthly collection of rare, seasonal, or themed flowers — unlocked as a Premium subscription perk. A new set drops each month.

**Flower emoji dedicated picker**
A full-screen flower emoji keyboard beyond the standard system set — organized by meaning, season, and emotion. Makes choosing a flower feel like a real decision.

**Flower recognition via TFLite (Android)**
Point the camera at a real flower in the world — the app identifies it and suggests sending that variety to your partner. On-device, no internet required. Android first via TensorFlow Lite.

---

### Photo & Media

**Digital photo album**
A full shared photo library beyond the polaroid booth — any photo, any moment, organized chronologically. Think of it as a private shared gallery visible only to the two of them.

**Stories (24-hour ephemeral content)**
Share a photo or flower moment as a Story — visible for 24 hours then auto-deleted. Saves storage, keeps content fresh, and creates a sense of urgency and presence (like knowing your partner is thinking of you right now).

**Future baby looks**
A fun feature using face morphing to generate what the couple's future children might look like. Shareable and lighthearted.

**Camera filter (men's smooth/blurry cam)**
Beauty/softening filter for video calls or photo booth uploads — particularly marketed toward the male partner who may want to look a bit more polished on camera.

**Share to social media**
Export any booth frame, flower moment, or milestone card directly to Instagram, TikTok, or as a shareable image. Formatted and branded for social.

---

### Shared Activities & Games

**Rock paper scissors**
A quick couple mini-game for settling small decisions ("you pick dinner," "you do the dishes") — plays in real-time or asynchronously.

**Gym together**
A synchronized workout companion — both partners log that they're working out at the same time. Shows "Sunshine is also at the gym 💪" on the home screen. Could expand to shared workout logs.

**Save together / yearly goals**
A shared goals tracker — financial savings targets, travel plans, life milestones. Both partners can add, track progress, and celebrate when a goal is hit.

**Couple to-do list**
A shared checklist with support for text, links, and image attachments. Think: gift ideas, bucket list items, things to do on the next visit, errands to coordinate.

---

### Map & Places

**Travel map**
An interactive map showing places the couple has visited together, places they want to go, and each other's current city. Pins can hold photos and memories. The map grows as the relationship grows.

---

### Celebrations & Special Days

**Heart Day (Valentine's)**
A special in-app mode on February 14 — animated home screen, exclusive flower variants, a themed booth frame, and a curated love prompt.

**Women's Month**
A March celebration mode with appreciation prompts for the male partner — daily affirmations to send, a special flower selection, and recognition cards.

**Boyfriend / Girlfriend Day**
Country-specific or universal couple appreciation days — special in-app moment with a prompt to express gratitude and a shareable card.

*(Foundation: the Events tab already supports custom milestones — these would be pre-populated seasonal overlays on top of that.)*

---

### Navigation & UX

**Swipe-based navigation**
Swipe left/right to move between the five main screens (Nest → Tulip → Booth → Dates → Us) — a faster, more fluid alternative to tapping the bottom nav. Feels like flipping through a journal.

**Expressive app icons**
Large, emotion-rich app icon variants — flower emojis as alternate icons (🌷🌻🌸🌹) that users can set from Settings. Makes the app feel alive and personal on the home screen.

---

### Commerce & Brand

**Dayflower Store**
Physical merchandise — plushies, crochet items, and branded keepsakes inspired by the app's aesthetic. Could launch as a limited drop tied to Valentine's or milestones.

**Bumbumbee**
A brand mascot concept — a character (bee? bunny?) that appears in celebrations, loading states, and milestone moments. Adds warmth and identity to the app's personality.

---

### Research & Strategy

**Competitor feedback audit**
Ongoing review of competitor app store reviews (Between, Paired, Lasting, LokLok) — specifically 1-3 star reviews. Mining for unmet needs that Dayflower can address in future updates.

---

*Document version: 3.0 — Last updated: 2026-07-26*
