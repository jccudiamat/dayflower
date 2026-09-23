# Together illustrations

What ships here is generated. The originals are in `design/together/` in the
main checkout (`C:/Users/jccud/dev/twolip`), and this folder is made from them
by:

    python tool/shrink_together.py

which trims each picture, sizes it to 3x what the app draws, and writes WebP.
Nine originals are 8 MB; what ships is under 300 KB. The APK is under 1 MB
from the 50 MB limit the in-app updater can publish, so never copy an original
straight in.

| Shipped file | Drawn as |
| --- | --- |
| `couple_sunset.webp` | Hero, right side, fading into the card |
| `airplane.webp` | Hero reunion row |
| `island.webp` | Hero next-trip row; Our Savings |
| `piggy_bank.webp` | Our Savings, before there is a goal |
| `calendar_hearts.webp` | Events card |
| `gift_for_you.webp` | Gifts card |
| `game_controller.webp` | Play Together: Games |
| `headphones.webp` | Play Together: Music |
| `popcorn_tv.webp` | Play Together: Watch Together |

Still to come — drop a PNG in with exactly this name and nothing else changes;
until then the app draws a soft placeholder:

| File | Drawn as |
| --- | --- |
| `heart.png` | Hero monthsary row |
| `map_background.png` | Our Map card backdrop |

The paths live in code at `lib/features/activities/data/together_assets.dart`.
