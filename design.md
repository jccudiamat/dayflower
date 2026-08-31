# Dayflower Design System v3

> Premium-playful: midnight-plum dark journey screens + lavender-tinted light utility screens, one signature pink→purple gradient, Quicksand type, pill buttons, flat surfaces. Extracted from the reference kit analysis ([reference-analysis.md](reference-analysis.md)) and recreated originally.

## Principles

1. **One gradient, one meaning.** The pink→purple gradient (`AppGradients.cta`) means "primary/active" — CTAs, active toggles, progress fills, celebration accents. It appears once per screen region. Everything else is neutral.
2. **Dual-mode identity.** The *journey* (onboarding wizard, celebrations) lives on the dark midnight-plum canvas (`darkCanvas`/`darkSurface`). The *daily app* (Nest, Tulip, settings) is light with dark plum hero cards. Components share identical shapes across modes.
3. **Two-tone headlines.** Step/page titles use `TwoToneHeading`: neutral lead line + gradient-tinted keyword ("Enter your verification **Code**").
4. **Pill everything interactive; soft-square everything informational.** Buttons/chips = pill (999). Inputs/options = 12. Cards = 18. Sheets/heroes = 24.
5. **Flat by design.** Separation via surface-color steps, not shadows. `AppElevation.glow` only on the primary CTA/floating hearts; `card` shadow is near-invisible.
6. **The serif is sacred.** Lora italic (`AppText.note`) only for partner notes, meanings, quotes — words between the two of them. This is Dayflower's own signature; nothing from the reference replaces it.
7. **Selected = outline.** Chips and option rows show selection with a tinted 1.5px border, never a fill change.
8. **One question per screen** in flows, with visible progress and a pinned CTA (`StepScaffold`).

## Tokens (`lib/core/theme/`)

| Token | Use |
|---|---|
| `AppColors` light set | `background #F8F6FB · surface #FFF · surfaceSubtle #EFEAF8 · ink #1C1024 · body · muted · border` |
| `AppColors` dark set | `darkCanvas #100A1E · darkSurface #1D1430 · darkRaised #2A2040 · darkBorder · onDark · onDarkMuted` |
| Brand | `gradientPink #F0709F → gradientPurple #906FE8`; solids `brand #EE6FA8`, `secondary #8B72E0` |
| `AppGradients` | `cta` (horizontal, primary actions) · `splash` (diagonal full-bleed) · `hero` (dark plum cards) |
| `AppText` | Quicksand: `display 30/700 · hero 25/600 · title 19 · subtitle 16 · body 14.5 · caption 12.5 · label 11 caps · stat 32 tabular`; **`note` = Lora italic 16** |
| `AppSpace` | 4pt grid; screen H-padding 20 |
| `AppRadius` | `sm 12 · md 14 · lg 18 · xl 24 · pill 999` |
| `AppMotion` | `micro 150 · standard 250 · emotional 500`, easeOut cubic |

## Components (`lib/core/widgets/`)

| Component | Spec |
|---|---|
| `GradientButton` | THE primary CTA: full-width pill h50, gradient fill, white 15/600; disabled = 45% opacity; loading = spinner |
| `OutlinePillButton` | Secondary: transparent, 1.5px purple-tinted border |
| Tertiary | plain `TextButton` centered under primary ("Cancel", "Not Now") |
| `TwoToneHeading` | lead line neutral + accent line gradient via ShaderMask |
| `StepScaffold` | dark wizard chrome: back, heading, caption, body, 4px gradient progress, pinned CTA, optional below-CTA action |
| `DarkField` | input on dark canvas: darkSurface fill, darkBorder hairline, purple focus |
| `OtpField(dark:)` | boxes: lavender `surfaceSubtle` (light) / `darkSurface` (dark), purple border when filled |
| `AppBottomNav` | floating rounded bar on `surfaceSubtle`, selected icon = solid `secondary` |
| Sheets | white, 24 top radius, title + circled ✕, gradient Apply |
| Dialogs | 18 radius, gradient confirm + text escape |

## Screen recipes

- **Wizard step:** `StepScaffold` + `TwoToneHeading(dark:true)` + one control. Progress map: email .15 → otp .30 → name .50 → nickname .70 → pairing .90.
- **Light screen:** `background` canvas, `hero`-gradient dark cards for emotional weight (today's flower, reunion), white hairline cards for utility (clocks, history).
- **Celebration:** full-bleed `splash` gradient or photo, oversized emoji/scripted moment, single action.

## Motion

- Taps acknowledge ≤150ms. Transitions 250ms fade+slide. Emotional reveals 500ms.
- Heartbeat is the only looping/repeatable animation.
- Progress bars animate width changes (250ms easeOut).
