# Remaining section reorganization

Branch: `codex/remaining-section-reorganization`, based on published build 77 (`611fa68`). The user requested reorganizing every remaining section together before refining them individually. This implementation replaces the earlier Chat-only preview stage. The original checkout and the rejected older reorganization worktree are untouched.

## Current implementation

The bottom navigation is Home, Chat, the central Dayflower logo, Memories, Together. Existing colors, type, cards and feature screens are reused. Home content has no source changes; it only receives the shared updated navigation.

| Destination | Features and previous locations |
| --- | --- |
| Home | Approved greeting/My Day, heartbeat, mood, Events preview and widget previews. Bell and Us pill retained. |
| Chat | Conversation formerly reached through Flowers. Existing calls, messages, quick flower picker, chat camera, replies and reactions retained. Partner header opens existing Chat settings and shared media. Chat is full-screen with no bottom navigation, including while typing and using the flower picker. |
| Dayflower center | Existing Flowers collection, including sent blooms and shared bouquet links. Send a flower opens the working Chat catalog. Create a bouquet opens the existing Dayflower website creator. The former conversation preview is removed because Chat now has its own tab. |
| Memories | Booth & Strip and Chapters moved from Activities. Shared photos reuses the gallery from Chat settings. My Day photos is the same gallery filtered to photos shared to the widget, with a camera action explicitly targeting My Day. Finished strips remain in the booth history and shared-photo collection. |
| Together | Events (also still linked by Home and Us), reminders and finances from Activities, Gifts from its old tab, and the existing Travel map screen. Fitness, async games and music retain their explicit Coming soon status. |
| Us | Remains behind Home's pill, including couple details, relationship settings and the personal Settings link. |

## Scope boundaries

This is feature placement, not a visual redesign. The central collection reuses existing flower data. No garden watering, growth or daily-care system was invented. The bouquet creator is the existing web tool, not a new native editor. All new views use real providers in production; preview identities and messages exist only in tests.

The user approved publication on 2026-09-17. Published build 80; the original checkout remains untouched. Further visual refinements can be reviewed section by section.

## Routing and return behavior

- Existing camera, chat, notification, photo-booth, chapter, finance, event and reminder URLs are unchanged.
- Old `/app/activities` redirects to Together; old `/app/blooms` redirects to Dayflower. Query strings are retained.
- Tab selection maps legacy paths to their new owners. Booth and Chapters select Memories despite their old Activities paths. Events, gifts and finance select Together.
- Feature entry points push a screen, preserving their origin. Back pops when possible and otherwise returns to the new parent section. Camera Close returns to its opener, with Home as the direct-link fallback.
- App route registrations are shared with navigation tests so the checks exercise production builders and redirects.

## Validation and previews

Automated checks cover real screen navigation, tab ownership, old links, return paths, the flower catalog, the unchanged Home interactions, narrow phones and large text. Existing tests for Gifts are updated to its Together placement. Phone screenshots are actual Flutter renders with offline data under `build/review/sections-{chat,dayflower,memories,together}.png`; the separate text conversation preview is `build/review/chat-filled.png`.

Live calls, external bouquet sharing, map tile loading and device camera capture are not simulated as successfully completed by these tests. Their existing integrations remain in place.

Validation completed: 414 tests passed in the full suite. Changed source and tests pass Flutter analysis with no issues. The Chat keyboard check verifies the draft remains visible when the keyboard closes. Home source is unchanged from build 77.

## Navbar refinements before deployment

- The center uses the existing transparent website brand mark, copied unchanged to `assets/images/brand_mark.png`. There is no rounded-square logo background.
- Chat never displays the bottom navbar. Its back action and bottom safe-area spacing remain available.
- Tapping the current section scrolls its existing content to the top. Tapping its tab from a nested screen returns to the section root and scrolls to the top. Controllers are scoped per section and disposed with their provider. Reduced-motion settings skip the animation. This does not refresh network data or reset a form.
- Home content is unchanged; root route wrappers supply the scroll controllers.
- Latest validation: 15 focused navigation, layout and interaction tests passed, and analysis reported no issues. Previews were regenerated and visually checked. These refinements are included in the approved build 80 release.

## Build 80 publication

Preflight found live build 79, a rollback to the same Home build 77 source (611fa68), with only its version stamp changed. Build 80 adds the approved reorganization and navbar refinements on that source. Unrelated work in the original checkout is not part of this release.

The first release APK exceeded the 50 MiB upload ceiling by 127,201 bytes. Reused the already committed WebP version of the existing monthsary artwork (from 0dba55f) and updated its asset reference; no Home content or greeting behavior changed. Both greeting tests passed after the asset switch.

Published and verified 2026-09-17T06:09:48.681909Z: version 1.0.0+80, dayflower-80-arm64-v8a.apk, 51,006,270 bytes. Public download SHA-256 matches the local APK: 6037e8349b3597f5abb550792068516feb478484688c32593393a867977ed114. Android package is com.dayflower.app; signing certificate matches prior releases. Previous builds retained. Release source remains on the separate reorganization branch; original checkout untouched.
