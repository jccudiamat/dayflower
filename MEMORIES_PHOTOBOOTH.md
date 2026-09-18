# Memories and photo booth review

Branch: `codex/memories-photobooth`, based on published build 80. The user approved publication after reviewing the preview. Published as build 81. The original checkout and Home screen source are untouched.

## Experience

Memories now previews its contents: a physical booth entrance, a photo collage backed by shared photos, My Day photo arches, and a chapter excerpt. Empty states use placeholders rather than invented memories. The booth entrance opens the session directly. The section heading opens the foyer with saved strips and pending invitations.

Session order: Solo or Couple, booth look, frame layout, live shoot, review, printing animation, save/share. Couple offers one phone together or separate phones. Four looks are Rose room, Classic, Vintage, and After hours. These change the booth surround and print paper, not the subject's photographic background. Four layouts are a four-photo strip, 2×2, two-photo strip, and single Polaroid.

The native camera takes a new photo after each 3–2–1 countdown. Gallery upload is an alternative and fills one slot per selection. Pause or backgrounding cancels the countdown and preserves earlier shots; returning does not silently resume taking photos. Camera work is serialized and stale initialization/capture results are discarded. No audio is requested. Review precedes sharing. The print animation reveals the actual generated JPEG. Save uses the existing device-gallery integration and reports success only when it succeeds; Share opens the system share sheet. Keeping a strip in Memories also shares it in Chat, without replacing the My Day widget.

Separate-phone sessions are **asynchronous**, using the existing private `photo_strips` infrastructure. Each partner takes a set of photos on their own phone. The initiating partner saves a private invitation; the second partner gets the same booth and frame, contributes their set, and completes the joint print. This is not a synchronized live call or shared countdown. Both partners need the new client for multi-photo templates. Existing single-photo invitations and history remain usable in Saved & waiting strips.

## Storage and compatibility

New template IDs encode the booth look and layout with the `studio_` prefix. The two private storage slots hold a versioned contact sheet per partner. The compositor places both partners side by side in each finished frame. Each remote viewfinder occupies the same portrait half as its final print, with the joining partner on the right. No database migration or public photo bucket is needed. Legacy My Day camera providers exclude studio invitations so a single camera shot cannot accidentally consume a multi-photo invitation. Old templates retain their existing compositor behavior.

Local solo/one-phone output is not uploaded unless the user chooses Keep in Memories. Separate-phone sessions explicitly upload when Send my photos or Finish our strip is pressed. Network failures retain the local review; already-uploaded unfinished strips remain recoverable through the archive.

## Validation

425 tests passed in the full suite; scoped analysis reported no issues. The 35 focused checks cover camera sequence timing, background cancellation, permission denial/upload cancellation, phone layouts and 2× text, real export pixels for each frame, both halves of a couple composite, invitation creation/joining, truthful failed/successful gallery-save states, legacy booth behavior, Home behavior and section routing. Screenshot tests use offline fixture photos and a camera adapter, not a live camera or real user messages.

Physical device camera rendering, camera switching, native gallery persistence, native share sheet and two real signed-in devices have not been exercised in this desktop session. These device checks remain unverified; the user approved publication after this limitation was disclosed. No real partner messages were sent by the test harness.

## Review artifacts

Actual Flutter renders under `C:/Users/jccud/dev/dayflower-home-release/build/review/`:

- `memories-new-full.png`, `memories-new-390.png`, `memories-new-320.png`
- `booth-entrance.png`, `booth-mode.png`, `booth-looks.png`, `booth-frames.png`
- `booth-camera.png`, `booth-couple.png`, `booth-countdown.png`, `booth-review.png`, `booth-finished.png`
- `booth-printing-preview.gif`, assembled from captured Flutter animation frames

## Artwork provenance

Built-in image-generation tool used for an original booth illustration. Project asset: `C:/Users/jccud/dev/dayflower-home-release/assets/images/booth_entrance.jpg` (134,129 bytes, resized/re-encoded for the app). Original output remains at `C:/Users/jccud/.codex/generated_images/01a0779c-f7d1-7621-8168-aeeba1724a4d/exec-c08eb915-9729-421f-9fcf-d817c7e81af9.png`. The other previews and frame geometry are native Flutter widgets. No competitor artwork was copied.

Final generation prompt:

> Use case: product-mockup. Asset type: original photobooth entrance artwork for a couples mobile app, not a UI screenshot. A charming realistic vintage photo booth with rounded walnut wood cabinet, softly folded dusty pink velvet curtain partly open showing a small cream seat, brass details, small camera lens and print slot on the right pillar. A blank cream illuminated sign at top with NO text. Warm cozy studio light, sophisticated tactile materials, understated romantic feeling. Entire booth visible, front view with tiny perspective, centered on a solid pale blush-lavender background #F8F4FC with a soft grounding shadow. Portrait 2:3 composition, booth fills 90 percent height, no people, no text, no watermarks, no interface buttons. High quality product render with realistic wood grain, fabric and metal. Original design inspired by classic analog photo booths.

## Publication

Verified 2026-09-17T11:37:30.171581Z: version 1.0.0+81, dayflower-81-arm64-v8a.apk, 51404162 bytes. Public download SHA-256 matches the local APK: 61f016a1dd5e775095ed3e06311c21007da5f77a3d9fb45f6366b11ddd38943a. Android package com.dayflower.app, arm64-v8a, signing certificate unchanged from build 80. Existing releases retained. Physical device checks remain unverified as disclosed above. Original checkout remains untouched.


## Pending review: Journal and booth collections

Not published. Build 81 remains the live release.

- Renamed displayed Chapters labels to Journal; preserved existing routes and stored records. Memories now previews Journal as a green vintage book with gold detailing and a ribbon.
- Replaced the Shared photos and My Day previews in Memories. Order is booth entrance, Pending strips, Booth collection, Journal.
- Pending prioritizes recoverable completed halves and partner invitations ahead of sessions waiting on the partner. Studio invitations open the exact session; legacy and recovery actions remain available in the pending archive.
- Collection uses the existing archive classification for legacy template names and studio booth captions, newest first. Ordinary chat/My Day photos are excluded. Signed private images preserve the full print and open the existing save-capable viewer.
- Added distinct pending and collection routes under the existing booth path. The default combined archive remains compatible.
- Verified 32 Home/booth/trust/collection tests, then reran the 3 Memories tests after preview polish. Scoped analysis is clean. Phone renders cover 390px and 320px with 2x text. No production data was used in preview screenshots.
- Review images: build/review/memories-booth-full.png, memories-pending-390.png, memories-collection-390.png, journal-preview-390.png.

- September 18 follow-up: verified populated/empty archive separation and opening the exact stored print in MediaViewer. Captured memories-booth-empty.png, pending-detail-empty.png, pending-detail-filled.png, collection-detail-empty.png and collection-detail-filled.png. Still unpublished.
