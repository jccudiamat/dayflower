# Dayflower relationship experience

The Flutter app keeps its Riverpod providers, GoRouter authentication gate,
Supabase repositories, bundled TikTok Sans, and original `AppIcon` artwork.
This is an incremental change to the existing application.

## Destination ownership

| Destination | Responsibility |
| --- | --- |
| Home | Partner presence, shared city clocks, mood, collective heartbeats, upcoming event, memory callback |
| Chat | Conversation, camera, and a compact relationship action sheet |
| Dayflower | Flower sending, bouquet shop, cards, Photo Booth, journal, Garden |
| Memories | Chronological saved content with filters and individual detail views |
| Together | Plan, Life, Play, and Our Map |
| Us | Couple identity, collective statistics, relationship milestones, preferences |

Published booth and journal routes redirect to their new destinations, including
year/month links. Query parameters survive the redirects.

## Content lifecycle

`RelationshipMemory` is a read-only presentation projection, not a new database
table. It combines existing flower messages, photos, closed monthly chapters,
journal moments, visited map pins, and past custom events. Draft reviews and
unvisited places remain in their creation/planning destinations. Each source
record appears once in the projection, with deterministic chronological order.

Cards render a PNG and use the existing photo delivery and storage policies.
New card and booth image filenames carry an origin prefix, so ordinary photos
cannot become cards merely by copying a caption. Existing booth exports are
recognized by their historical template captions. Flowers and bouquets also
appear in the Garden; the Garden groups them by month.

The 24-hour Daily Moment lifetime applies to the widget, not to stored media.
Older content remains visible in Chat and Memories, with no misleading expired
label. Deletion continues to use the existing records and permissions.

Our Map separates Now, Our Places, and Next. Now uses voluntarily configured
cities and time zones; it does not request GPS permission or claim live tracking.
Marking a planned place as visited updates its existing record and surfaces it
in Memories. A pin's date remains the date it was saved; there is no visit-date
field in the existing schema.

## Existing product boundaries

- Bouquet creation opens the existing Dayflower web shop. Sharing its gift link
  into Chat makes it part of the couple's saved history, as before.
- Fitness, Async Games, Music, and Watch Together are explicitly marked Soon.
  The redesign does not pretend these services are implemented.
- Trips uses the existing planned-places feature in Our Map.
- New UI does not add background location tracking, a voice recording service,
  or a new backend content schema.

## Review

Shared page chrome and content components live in `story_components.dart`.
The central spacing, palette, type, radius, and motion tokens continue to own
styling. The inactive Dayflower mark is desaturated; selection also has a label
and semantics. Creation cards reflow at narrow widths or large text sizes.

`test/gifts_navigation_test.dart` exercises the actual screens using offline
provider overrides. `CAPTURE_REVIEW=true` writes review PNGs to `build/review`.
`test/relationship_memory_test.dart` checks preservation and lifecycle filtering.
No live couple content needs to be created to run these checks.
