# Reference Analysis — "Prime Dating" Flutter UI Kit

> Source: `C:\Users\jccud\Downloads\visual style onboarding flow feature set` (7 preview sheets, font/credits sheet, APK).
> Purpose: extract the design language and UX patterns to re-apply to Dayflower. No branding, names, or proprietary assets are copied — patterns and tokens are recreated originally.
> Companion: [design.md](design.md) will be rewritten from this once approved.

---

## 1. Design System

### Color palette

| Role | Value (sampled) | Where seen |
|---|---|---|
| Gradient start (pink) | `#F0709F` ± | Every primary CTA, toggles, progress fills, own chat bubbles, splash |
| Gradient end (purple) | `#906FE8` ± | Same — always paired, horizontal L→R (splash: diagonal) |
| Accent purple (solid) | `#8B72E0` | Selected nav icons, links, sliders, highlight words |
| Accent pink (solid) | `#EE6FA8` | Selected chip borders, "Resend" links, highlight words |
| Dark canvas ("midnight plum") | `#100A1E` ± | Onboarding wizard, chat, profile, match screens |
| Dark surface | `#1D1430` ± | Cards, inputs, list options on dark |
| Dark surface raised | `#2A2040` | Chips/keys, secondary surfaces on dark |
| Light canvas | `#FFFFFF` / `#F8F6FB` | Auth, settings, discovery |
| Light surface subtle | `#EFEAF8` (lavender tint) | OTP boxes, nav bar fill, inactive tracks |
| Ink (light mode text) | `#1C1024` | Headings/body on light |
| Text secondary | `#8E8698` | Captions, helper text (both modes) |
| On-dark text | `#F5F2F8` / 60% white | Headings / secondary on dark |
| Border light | `#EAE5F0` | Hairlines, chips, inputs |
| Border dark | `#332A4A` | Hairlines on dark |
| Success | `#3DBE7B` (green heart/like) | Like button, checkmarks |
| Danger | `#E2447C` (pink-red X) | Dislike button, destructive |
| Warning | amber `#E8A13D` | sparse |

**Key insight:** the palette is 90% neutral (very dark plum or white/lavender) with ONE signature element — the pink→purple gradient — spent consistently on every interactive/primary element. Solid colors are tints of the gradient's two endpoints.

### Typography — Quicksand (confirmed from APK FontManifest)

| Role | Size | Weight | Notes |
|---|---|---|---|
| H1 / step title | 24–26 | SemiBold (600) | Two lines; second line keyword tinted pink/purple |
| H2 / dialog & sheet titles | 18–20 | SemiBold | |
| Card title / list item | 15–16 | Medium–SemiBold | |
| Body | 14–15 | Regular (400) | line-height ≈ 1.4 |
| Caption / helper | 12–13 | Regular | `#8E8698` |
| Overline / section header | 11–12 | Medium, +0.5 tracking, UPPERCASE | "ACCOUNT SETTINGS" |
| Button label | 14–15 | Medium–SemiBold | white on gradient |
| Script accent | (image asset "Sunberry") | — | Brand logo, "It's a Match!" — celebration moments only |

Quicksand is a rounded geometric sans — friendly, soft, but neutral enough to read premium. No serif anywhere.

### Spacing & layout
- Screen H-padding: **20px**; content top starts ≈ 16 below the back arrow.
- Card internal padding: 14–16. Gaps between cards/options: 10–12.
- Section gaps: 24–32. One-question-per-screen layouts leave generous whitespace (≥40% empty).
- Full-width CTAs pinned near bottom with ~24 bottom inset.

### Shape
- **Buttons: full pill (999).** The single most recognizable shape cue.
- Inputs / list options: 12–14 radius.
- Cards: 16–20. Sheets: 24 top radius. Dialogs: 20. Chips: pill.
- Photo tiles / upload slots: 12, dashed 1px border on empty.

### Elevation & effects
- Essentially **flat**: separation via surface-color steps, not shadows. Tiny shadow only on floating action circles (like/dislike).
- Scrim: dark 50–60% behind sheets/dialogs; match screen uses photo + bottom gradient scrim.
- No blur effects visible. Opacity used for hierarchy on dark (60% white secondary text, 30% dividers).

### Components inventory

| Component | Spec |
|---|---|
| **Primary button** | Full-width pill, h≈48–52, pink→purple gradient, white Medium 14–15. Disabled: same gradient at ~40% opacity. Loading: white spinner. |
| **Secondary button** | Pill, white/transparent fill, 1.5px gradient-tinted border, ink/white label |
| **Tertiary action** | Plain centered text link below primary ("Cancel", "Not Now") |
| **Text input** | 12–14 radius, hairline border; on dark: dark surface + faint border; focus: pink/purple border. Placeholder = text-secondary |
| **OTP boxes** | 4–6 squares ~56px, radius 12, lavender fill (light) / dark surface (dark), no visible border until filled |
| **Option row (single-select list)** | Full-width, surface fill, radius 12, 14px Medium; selected = 1.5px pink/purple outline (fill unchanged) |
| **Chip (multi-select)** | Pill, hairline border, 12–13px; selected = pink border + pink-tinted label; fill stays surface |
| **Toggle** | iOS-style; active track = the gradient |
| **Slider** | 2px track, active portion pink; thumb = hollow ring (white fill, pink ring) |
| **Progress bar (onboarding)** | 3–4px rounded track (dark surface), gradient fill; sits just above the CTA |
| **Segmented progress (cards)** | 4 rounded segments at top of photo card, active = pink |
| **Settings row** | Label + chevron; grouped card with internal dividers; uppercase section header above |
| **Notification row** | Title (15 Medium) + caption (12 gray) + toggle right |
| **Bottom nav** | Rounded-rect bar on light lavender fill; 4 icons; selected = solid purple icon (+ soft glow), unselected gray outline |
| **Bottom sheet** | White (even over dark screens), 24 top radius, title left + circled ✕ right, content, gradient Apply |
| **Dialog** | Centered, 20 radius, same title+✕ pattern, gradient confirm + text cancel |
| **Chat bubble (own)** | Gradient fill, white text, radius 16 w/ reduced tail corner, timestamp inside |
| **Chat bubble (partner)** | Solid lavender-purple or dark surface, same geometry |
| **Avatar** | Circle; profile avatar ringed with gradient arc + "% completed" pill badge |
| **Badge/pill label** | Small gradient or purple pill w/ white 11px text ("40% Completed") |
| **Empty upload slot** | Dashed border, centered ⊕ in tinted circle |

## 2. Visual Language

- **Personality:** premium-playful. Soft rounded type + candy gradient = warm; near-black plum + flat surfaces + disciplined spacing = premium. Never childish: color discipline (one gradient) and dark neutrals do the heavy lifting.
- **Dual-mode identity:** the *journey* (onboarding wizard, chat, profile) lives on the dark midnight-plum canvas — intimate, evening mood. The *utility* screens (auth, settings, discovery) are light. Both share identical component shapes and the gradient.
- **Signature moves:**
  1. Two-tone headline — sentence starts in neutral, key word rendered in pink/purple ("Enter your Mobile **number**").
  2. The gradient appears exactly once per screen-region, always meaning "primary/active".
  3. Pill everything interactive; soft-square (12–16) everything informational.
- Information density: low. One decision per screen in flows; generous whitespace.
- Motion (inferred from kit conventions): quick fades/slide-ups, ~200–300ms; card swipe with rotation; celebration screens full-bleed with scripted overlay. Micro: buttons dim/scale slightly on press.

## 3. Onboarding Flow (reference)

Splash (full gradient + script logo) → Welcome (light; headline, terms fine-print, gradient **Create Account**, outlined **Sign In**) → Phone entry → OTP (auth on light) → then the **dark wizard**: one question per screen — photos → looking-for → distance → first name … Each wizard screen: back arrow ↖, two-tone H1, helper caption, single control, thin gradient progress bar above pinned gradient **Next**. Progress advances visibly each step. Skip is absent — steps are short instead. Permissions asked in context.

## 4. UX patterns worth adopting

- One-question-per-screen wizard with persistent progress + pinned CTA.
- Selected state = outline (not fill change) — calm, readable on both modes.
- Sheets for every edit-in-context (filters, pickers) with title+✕+Apply structure.
- Destructive flows: full dialog with gradient confirm and plain-text escape ("Not Now") — friction ordered correctly.
- Reason-collection list before account deletion.
- Feedback: toggles/sliders echo the gradient instantly; celebration moments go full-bleed.

---

# Application plan for Dayflower (pending approval)

**What stays:** all functionality, Riverpod/data/routing architecture, Supabase logic, feature scope, Lora italic as the sacred partner-note voice (Dayflower's own signature — the kit has no equivalent; it replaces "Sunberry script" as our emotional accent).

**What changes (visual/UX only):**

1. **Tokens** (`app_colors.dart`, `design_tokens.dart`): new palette above (midnight-plum dark set + lavender-tinted light set), `AppGradients.cta` (pink→purple), Quicksand replaces Inter, pill buttons, flat elevation.
2. **Theme** (`app_theme.dart`): pill `ElevatedButton` with gradient (custom `GradientButton` widget since ThemeData can't gradient-fill), outlined secondary, sheet/dialog/toggle/slider/chip specs per table.
3. **New shared components** (`core/widgets/`): `GradientButton`, `TwoToneHeading`, `StepScaffold` (back arrow + heading + progress + pinned CTA), `OptionRow`, `SelectChip`, `AppSheet` (title+✕+Apply).
4. **Onboarding → dark wizard:** Welcome (light) → Email → OTP → Name → Nickname → Pairing → optional Reunion date, one question per screen with progress. Same providers/logic, re-composed UI.
5. **Main screens restyle:** Nest/Tulip stay light-canvas with dark plum hero cards (unchanged concept, retinted), gradient CTAs, pill buttons, new nav bar treatment, sheets restyled.
6. **Celebrations:** flower-sent + future pairing-success go full-bleed gradient moments.

**Deliverables:** updated design.md, new tokens/theme, component library, rebuilt onboarding flow, all existing screens restyled, summary of changes.
