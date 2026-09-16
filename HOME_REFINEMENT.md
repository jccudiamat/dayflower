# Home refinement for review

Branch: codex/home-layout-refinement, based on the published build 76. The original working checkout is untouched. This revision is not published; preview approval is required before another release.

The latest final user decision supersedes the preceding responsive layout: restore the original greeting at the left, and show the reference's overlapping My Day arches at the right at every screen width. No outer card. No stacking below the greeting or single-arch empty variant. Phone column gaps are 4–6px; larger layouts use 16px. The original display typography is restored (30px, 26px on the narrowest phones). Both arches, the share action, actual photo switching, changing emoji, partner location/time and distance remain. Empty-stack copy and controls use compact, readable sizes on phones rather than shrinking the entire section.

Heartbeat keeps the partner mood, centered heart and padding. Its heading and counts use their space without forced single-word lines. Own mood picker is restored from the pre-reorganization app. Illustrated events slide automatically every five seconds while visible on the active Home page. Manual swiping remains. Tapping any event goes directly to Events, including the empty state, with no detail or editor popup. No arrows or numeric pagination. Auto-rotation pauses for another route, backgrounded app or reduced-motion/accessibility settings.

The three widgets remain in one compact preview panel with the existing individual setup actions. Bell and Us pill remain. The monthsary greeting envelope is removed from Home. Other features and bottom navigation are unchanged.

Review renders: build/review/home-390-1-empty-top.png, home-390-1-filled-top.png, home-900-1-empty-top.png, home-900-1-filled-top.png, home-filled-home-heartbeat.png and home-filled-home-widget-gallery.png. These use offline sample data only.

Validation: the final side-by-side layout and actions pass the Home/event tests across all supported review sizes; analysis for changed Home code and tests reports no issues. Render checks cover 320px, 390px, 740px and 900px, large text, empty/populated data and dark mode.
