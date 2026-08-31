# Flower artwork — shopping list

Drop files into **`assets/images/flowers/`** using the exact filenames below.
Nothing else to do: the app picks them up automatically, and any flower
whose file is missing quietly falls back to its emoji, so you can add them
one at a time.

## Format

| | |
|---|---|
| **Filename** | exactly `<id>.webp` from the table (lowercase, underscores) |
| **Format** | WebP, quality ~85. PNG works but is 3–5× larger |
| **Size** | 512×512 px, square |
| **Background** | **Transparent** strongly preferred — the app tints backgrounds per flower, and a hard white square will look pasted on the dark cards |
| **Framing** | Single bloom, centred, small margin. It renders as small as 44 px, so it must read at thumbnail size |
| **Budget** | Keep each under ~120 KB. Twelve files ≈ 1.5 MB total |

**No GIFs.** Android home-screen widgets render a static bitmap — an
animated file would freeze there anyway. Motion belongs in-app, and I can
add that separately without touching the assets.

## Where to get them

- **[Pexels](https://pexels.com)** and **[Unsplash](https://unsplash.com)** — free, no attribution required, commercial use allowed. Best for photography.
- **[PNGTree](https://pngtree.com)** / **[Freepik](https://freepik.com)** — good for transparent PNG cutouts, but the free tiers require attribution. Check the licence per file.

Pick one source and stay with it — a set that mixes flat illustration with
photography will look incoherent next to each other in the grid.

Convert to WebP with [squoosh.app](https://squoosh.app) (drag in, choose
WebP, quality 85, resize to 512, download).

## The list

### Classic

| Filename | Flower | Meaning shown in-app | What to look for |
|---|---|---|---|
| `classic_tulip.webp` | Classic Tulip | Declaration of love | Single pink/red tulip, upright, stem visible |
| `rose.webp` | Red Rose | I still choose you | One deep red rose head, opened |
| `cherry_blossom.webp` | Cherry Blossom | Gentle & tender | Small pale-pink sakura cluster |
| `daisy.webp` | Daisy | Joyful & true | White petals, yellow centre, face-on |
| `sunflower.webp` | Sunflower | Always watching | Single sunflower head, face-on |
| `lavender.webp` | Lavender | Rest — I've got you | Small sprig, purple, slim vertical |

### Special

| Filename | Flower | Meaning shown in-app | What to look for |
|---|---|---|---|
| `bouquet.webp` | Full Bouquet | You mean everything | Mixed arrangement, wrapped |
| `lotus.webp` | Lotus | Pure devotion | Pink lotus, open, face-on |
| `hibiscus.webp` | Hibiscus | Rare beauty | Single red/pink hibiscus with stamen |
| `peony.webp` | Peony | A happy life together | Full ruffled bloom, blush pink |
| `orchid.webp` | Orchid | Rare and worth the wait | Single stem, 2–3 blooms, purple/white |
| `forget_me_not.webp` | Forget-me-not | Distance changes nothing | Tiny blue cluster, yellow centres |

## Adding more later

1. Add a `Flower(...)` entry to `lib/features/tulip/domain/flower_catalog.dart`
2. Drop `<id>.webp` in this folder

Never rename an existing `id` — `flower_messages.flower_type` stores it, so
a rename orphans every flower already sent.

---

## Current state (2026-08-01)

All 36 images from the user's `Downloads/flowers` folder are in use.
Originals live in `design/flower-source/` (gitignored, not bundled);
processed 512×512 WebP crops are in `assets/images/flowers/` (~1.7 MB total).

They are **photographs, not cut-outs**, so the catalog is split by what each
image actually *is*:

- **Flowers** (12) — a bouquet or bloom is the subject
- **Scenes** (24) — a place is the subject

Naming a meadow after a species would be wrong, so scenes get scene names
("Morning Meadow", "Fox in the Tulips") and keep the same meaning layer.

`sunflower` and `hibiscus` are **retired**: no image in the set matches them,
but `flower_messages` rows still reference them. They resolve for history and
are hidden from the picker via `Flower.retired` / `FlowerCatalog.pickable`.

To regenerate crops after replacing a source image, the mapping id → filename
is in the processing script in the session log; crops are centre-weighted with
a 0.32 vertical bias (subjects sit above centre in these portrait shots).
