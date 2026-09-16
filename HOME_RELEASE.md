# Home release, build 76

Based on committed app revision 60537d3, carrying forward the travel map, sticky notes and smaller gift photos and the build 75 map markers/distance line. Approved Home implementation was ported from codex/app-reorganization. The main working checkout and its unfinished reorganization are untouched.

Home combines greeting and My Day side by side at all widths, with changing emoji, partner local time and distance. The rear photo tilts six degrees; swapping photos brings the selected photo upright. Heartbeat includes partner feeling and centered send action. Upcoming events use actual saved and derived dates with themed artwork. My Day, Heartbeat and Reunion each have a preview and setup instructions. The notification bell and Us pill open real destinations.

This release preserves the existing released bottom navigation and other sections. It does not ship the broader, unapproved navigation/screen reorganization. Widget setup links to the existing Settings screen. Add a date opens the existing event editor.

Validation: 400 tests passed. All changed files pass analysis; full-repository analysis has three pre-existing informational lints in otp_field.dart and alarm_screen.dart. After converting the monthsary illustration to lossless WebP, all 12 Home/render/event tests passed again. Pixel equality was verified during conversion. Artwork and demo portrait provenance is recorded in the reorganization branch's REORGANIZATION.md; demo photos are test-only and not bundled.

Release environment contains only public runtime configuration; developer login credentials are excluded. APK version, signature, assets and upload size are checked before publication.
