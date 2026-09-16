# Remaining section reorganization

Branch: `codex/remaining-section-reorganization`, starting from verified release 77 (`611fa68`). The original checkout and the rejected older reorganization worktree are untouched. Home is complete and must remain unchanged.

Continue one section at a time, with visual review before implementation or publication. Current work is a Chat proposal rendered from the existing production conversation widgets with offline sample messages and a review-only navigation bar. No production source has changed in this stage.

## Navigation target

Home, Chat, central Dayflower logo action, Memories, Together. Us and notifications remain in the approved Home header. Preserve the existing styling. The center's bouquet creation and persistent garden with daily care need their own review; the older draft's flower-picker shortcut is not an approved substitute for the garden.

## Chat proposal

| Feature | Current location | Proposed placement and reason |
| --- | --- | --- |
| Conversation | Flowers page, then conversation card | Open directly from Chat, removing the intermediate page for everyday communication. |
| Voice and video calls | Conversation header | Keep beside the partner name, where the person being called is clear. |
| Presence and partner identity | Conversation header | Keep here so availability is visible while messaging. |
| Text, replies, reactions, receipts | Conversation | Keep existing behavior and appearance. |
| Photo capture/upload | Composer camera | Keep chat media beside the message input; preserve the explicit chat destination. My Day remains a separate photo destination. |
| Quick flower send | Composer flower picker | Keep the working shortcut; the shared garden is a separate section review. |
| Shared media, calling usage, reaction preferences | Tap partner header, Chat settings | Retain secondary settings here without crowding the main thread. Memories can later provide another entry to the same shared media data. |

Proposed navigation remains visible while reading; hide it when the keyboard or flower picker is open so composing retains available space. Keep the current back action until navigation/back-stack behavior is implemented and reviewed. Preserve existing deep links and notification-opened conversations.

Review artifacts: `build/review/chat-filled.png` and `build/review/chat-empty.png`. Render harness: `test/chat_section_review_test.dart`; proposed nav is isolated under `test/review/` and is not shipped. These checks verify rendering, not live message delivery or calling.

## Subsequent section reviews

1. Chat review and implementation.
2. Dayflower center: agree on bouquet creation, existing flower history, and the actual garden/care behavior before adding features or changing data.
3. Memories: review photo booth, shared photos/strips and Chapters placement. Flower/bouquet history should have one clear primary home in the agreed garden.
4. Together: review existing Events, reminders, finances, gifts and activity entries. Distinguish working features from placeholders; do not invent a working fitness or game implementation.
5. Integrate the full navigation, check all old links and selected-tab states, then review before release.

No changes from this stage are published. Do not merge the old rejected draft wholesale.
