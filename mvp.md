# Dayflower — MVP Build Plan

> Trimmed from [overview.md](overview.md). Goal: ship the smallest version of Dayflower that delivers the daily ritual, built feature by feature, each one working end-to-end (UI → provider → Supabase) before moving to the next.

---

## Scope

**In:** Auth + Pairing, Daily Tulip Exchange, Heartbeat, Reunion Countdown, Dual Clocks, Today's Tulip home-screen widget.
**Out (post-MVP):** Photo Booth, Cycle tracking, Events/milestones, Us profile stats, streaks/gamification, Premium/monetization, rare flower variants.

## Structure

```
lib/
├── app.dart
├── app_router.dart
├── core/
│   ├── constants/
│   ├── providers/          # authStateProvider, pairProvider
│   ├── theme/              # existing AppColors/AppSpace/AppRadius/AppText — reuse as-is
│   └── widgets/            # AppBottomNav (2 tabs), shared atoms
└── features/
    ├── auth/               # phone/OTP + pairing code
    ├── nest/               # home dashboard: clock, heartbeat, countdown, today's tulip
    ├── tulip/              # TulipScreen (history) + SendFlowerScreen
    └── settings/           # profile, notifications, disconnect
```

## Screen flow

```
Splash
  → (no session)        Login (phone/OTP)
  → (session, unpaired)  Pairing (enter/share code)
  → (paired)             Nest
                           ├─ tab: Nest    (dashboard)
                           ├─ tab: Tulip   (history + send)
                           └─ Settings     (sub-route off Nest, no nav slot)
```

## Backend (Supabase tables)

| Table | Purpose |
|---|---|
| `users` | Auth + profile (name, pet name, timezone) |
| `pairs` | Links two user IDs as a couple |
| `flower_messages` | Sent flowers (type, note, sent_at, seen_at) |
| `heartbeats` | Heartbeat events between partners |
| `reunions` | One row per pair (title, destination, date, note) |

Dropped for MVP: `booth_pairs`, `cycle_data`, `events`.

---

## Features (build order)

### 1. Auth + Pairing
- [x] Email + OTP login (Supabase Auth) — already built in `features/auth`
- [x] `users` + `pairs` schema — [supabase/migrations/0001_users_and_pairs.sql](../supabase/migrations/0001_users_and_pairs.sql) (**run this in the Supabase SQL editor**)
- [x] Onboarding: set real name + pet name (endearments) — `features/onboarding`
- [x] Generate unique pairing code for new user — `features/pairing`
- [x] Enter partner's code to link `pairs` row
- [x] Auth redirect logic in `app_router.dart` (splash → login → onboarding → pairing → nest)
- [x] Remove `kBypassAuthForHomePreview`
- [x] Verified end-to-end 2026-07-07: OTP login (Resend SMTP), onboarding, invite code `BMXQNW` accepted by API test account, router landed on Nest. Realtime pair-join event still to be re-verified (publication added in 0003).

### 2. Daily Tulip Exchange
- [x] `flower_messages` table + repository — `0004_flower_messages.sql` (one-per-UTC-day enforced by unique index; RLS: recipient-only seen updates)
- [x] SendFlowerScreen: preview card, category chips (All/Classic/Special), grid, pinned note+send footer
- [x] TulipScreen: today's flower hero card + live history list (realtime stream)
- [x] Delivery + ✓ Seen status (auto mark-seen on view, receipt shown to sender)
- [x] Verified end-to-end 2026-07-07: app send → DB, partner send via API → appeared live without refresh, seen receipts both directions
- [ ] Today's Tulip card on Nest — deferred to the Nest rebuild (Features 3–5)

### 3. Heartbeat
- [x] `heartbeats` table + repository — `0005_heartbeats.sql` (append-only, pair-scoped RLS)
- [x] Tap-to-send button on rebuilt Nest with ripple ring + elastic scale animation
- [x] Haptic feedback on send (HapticFeedback; no-op on web)
- [x] Live tap count today, both directions ("Tapped N× today" / "Sunshine sent N pulses")
- [x] Realtime delivery — incoming partner pulse triggers lavender ripple + soft haptic
- [x] Verified end-to-end 2026-07-09: taps → DB, partner pulses via API appeared live
- [x] Bonus: Nest rebuilt in new design (greeting header, Today's Dayflower card closing the Feature 2 deferred item)

### 4. Reunion Countdown
- [x] `reunions` table + repository — `0006_reunions.sql` (one row per pair, unique constraint, shared RLS)
- [x] Countdown hero card on Nest, ticking days/hrs/min/sec (targets noon local on chosen day)
- [x] Edit reunion details via bottom sheet (title, destination, date picker, note)
- [x] Verified end-to-end 2026-07-09: saved from app, partner edit via API appeared live

### 5. Dual Clocks
- [ ] Editable timezone per user (stored on `users`)
- [ ] Live self + partner clock, ticking every second, on Nest
- [ ] Hour-difference pill

### 6. Today's Tulip Widget
- [x] `home_widget` wiring — `lib/features/widget/widget_sync.dart` (guarded so web/desktop no-op)
- [x] Widget shows today's flower + note, with `sent` / `empty` states
- [x] Deep link `dayflower://tulip` → opens app on Tulip tab (handled in `app.dart`)
- [x] Update trigger: root-level `ref.listen` on today's flower + sent-today, so it updates even when the user is on another screen
- [x] **Android**: provider Kotlin, layout, config XML, manifest receiver + deep-link intent filter
- [ ] **iOS**: not implemented — needs a Widget Extension target created in Xcode on macOS. Steps documented in [docs/ios-widget-setup.md](../docs/ios-widget-setup.md)
- [ ] **Unverified**: no JDK on this machine, so the Android build never compiled. Run `flutter build apk --debug` on a machine with a JDK before trusting the native code.

---

*Build order matches the list above — Auth/Pairing first since everything else depends on a `pair_id`, then Tulip as the core loop, then Heartbeat, Countdown, Clocks, and the widget last since it depends on Tulip data already existing.*
