# Handwriting fonts, for notes

A note on Home is written the way the user's reference card was: a bold
heading over a thin handwritten body.

- **Caveat Brush** (heading): thick, casual marker handwriting.
  `CaveatBrush-Regular.ttf`, licence `OFL-CaveatBrush.txt`.
- **Patrick Hand** (body): neat, upright handwritten print.
  `PatrickHand-Regular.ttf`, licence `OFL-PatrickHand.txt`.

The user chose these from a sheet of six headings and five bodies rendered on
their Home (2026-09-26). Kaushan Script and Caveat were the first pair and
"didn't look good at all". Both are from https://github.com/google/fonts
(ofl/caveatbrush, ofl/patrickhand), under the SIL Open Font License 1.1,
which allows bundling them in the app. Each licence file is the OFL text with
the copyright line from the font's own name table. Their first suggestions
(Playlist Script, Brusher, Selima) are paid or personal-use only.

⚠️ **Subset.** Trimmed with fontTools to Latin-1 (English, Filipino with ñ,
Western European), curly quotes, dashes, bullet and ellipsis, keeping only the
kern/liga/calt/mark/mkmk features: 111 KB and 28 KB instead of 296 KB and
215 KB, because the APK has a hard 50 MiB ceiling. Anything outside that falls
back to the phone's own font for that character. The untrimmed originals are
in `twolip/design/notes/`.
