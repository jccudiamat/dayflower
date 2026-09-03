# Dayflower — Build Progress & Session Handoff

> **Purpose:** read this first when resuming work in a new session. It captures everything not obvious from the code: what's done, what's verified, dashboard-side config, test accounts, and how we work. Update it at every feature completion or significant decision.
> Companion docs: [mvp.md](mvp.md) (feature checklists) · [design.md](design.md) (design system rules) · [overview.md](overview.md) (original full vision).

**Last updated:** 2026-08-31 (Reminders ring like an alarm clock. 🔴 **0010 WAS already run** — this doc said otherwise and was wrong again — so the table exists WITHOUT the new `alarm` column and every insert fails with PGRST204. 0010 is now idempotent-but-preserving; re-run it. Also unrun: 0008, 0013 (day_photos), 0014 (app_builds), 0015 (avatars) — all confirmed missing against the live DB.)

---

## Feature status

| # | Feature | Status |
|---|---|---|
| 1 | Auth + Pairing | ✅ Done, verified end-to-end 2026-07-07 |
| 2 | Flower Exchange (was "Daily Tulip") | 🔶 **Rebuilt as a chat 2026-08-01.** Migration 0009 **is applied** (verified against the live DB — this row previously claimed otherwise). Text + flowers both insert successfully against real data. The thread rendered upside down until the `.order()` fix — see § The thread rendered upside down. Still unverified two-sided: read receipts, unread badge and partner-side delivery have not been exercised. |
| 3 | Heartbeat | ✅ Done, verified end-to-end 2026-07-09 (taps → DB, incoming pulses live w/ lavender ripple). 🔶 **Receiving side upgraded 2026-07-28** — bigger 3-ring ripple + lub-dub heart pump, and an opt-in vibrate/sound alert (`PulseAlerts`). Ripple is code-verified only; the buzz + sound need a real phone with the two test accounts. |
| 4 | Reunion Countdown | ✅ Done, verified end-to-end 2026-07-09 (countdown ticking, partner edits arrive live) |
| 5 | Dual Clocks | ✅ Done, verified 2026-07-09 (jessie=Dubai, Sheena=Manila, +4h pill; picker works). **Moved to the top of Home 2026-08-01**, and the mock copy on the Events page was deleted — there is now exactly one clock in the app, `ClocksCard`. |
| 6 | Home-screen widgets | 🔶 **Three Android widgets**, all compile clean (2026-07-28): `TodaysTulipWidget` (today's flower, tap → Flowers tab), `HeartbeatWidget` (tap sends a pulse from a **background isolate** — app never opens), `DayflowerWidget` (adaptive, follows Settings → Home screen widget). **Never placed on a real home screen**, so runtime behaviour — especially the background send — is unverified. iOS extension not built: [docs/ios-widget-setup.md](docs/ios-widget-setup.md). |
| — | Design overhaul v3 | ✅ Applied per [reference-analysis.md](reference-analysis.md): Quicksand, pink→purple gradient system, pill buttons, dark onboarding wizard, restyled main screens. design.md rewritten. |
| — | Auth: email+password | ✅ Built + verified 2026-07-26. Option-A card: icon fields, forgot-password via emailed code, create-account toggle, reserved Google/Facebook/Apple buttons (all three show a "coming soon" snackbar — no OAuth configured). The user's account was OTP-only and had no password; they set one via Forgot password and signed in successfully. |
| 7 | Reminders (Activities) | 🔶 **Rebuilt as alarm clocks 2026-08-31, never run.** Rings on the alarm stream, takes over the lock screen, Snooze/Done from the notification with the app dead. Also fixed the missing manifest receivers that would have made *every* scheduled notification silently fail. Needs migration **0010** (amended in place). Cannot be tested in the web preview at all — the scheduler no-ops off Android/iOS. |
| 8 | Finances (Activities) | 🔶 **v2 schema live 2026-08-31.** Was: Accounts (bank/cash/e-wallet/savings/investment) + a ledger of income/expense/transfer, in three scopes: Ours · Mine · theirs (read-only). Balances are always derived, never stored. Needs migration **0011**. |
| 9 | Chapters (Activities) | 🔶 **Built 2026-08-29, never run.** A year = 12 chapters. Goals at the start of a month, moments as they happen, a written review at the end. Needs migration **0012**. |
| — | Activity feed | 🔶 **Built 2026-09-03.** Shared timeline on Home (latest 3 + View all), fed by triggers in migration **0019 — applied and verified live**. Cards deep-link to the thing itself. Rendered against seeded rows in the web preview and the read watermark round-tripped through RLS; the seed was then deleted, so the feed starts empty. 🔴 Events are not in it — `events_screen.dart` is still local `setState` with no table to trigger on. |
| — | Notifications | 🔶 **Built 2026-09-03, phone-untestable here.** Messages, day photos and activity raise local notifications; heartbeats keep `PulseAlerts`. ⚠️ **Local, not push** — only fires while the process is alive. A swiped-away app hears nothing until it is next opened. See § Notifications — how far they actually reach. |
| — | In-app updater | ✅ **Live — builds 2–6 shipped OTA.** `dart run tool/publish_update.dart` from the desktop; the phone offers the build on its next launch or resume, downloads it, and hands it to Android's installer. Android only. Needs migration **0014** and one manual "Install unknown apps" grant on the phone. |
| — | Settings screen | 🔶 Rebuilt 2026-07-26 against real data (profile edits, timezone, invite code, disconnect, sign out). **Not yet exercised by the user** — and Disconnect needs migration 0008 first. |

## How to run

- Dev server: `preview_start` with name `flutter web` (config in `.claude/launch.json`) → `flutter run -d web-server --web-port 8770`. **Hot reload doesn't apply Dart changes** — restart the server after edits. ⚠️ Port was 8765, changed to **8770** on 2026-08-01: Windows had reserved 8765 in an excluded port range, so the bind failed outright.
- **Dev auto-login** (`lib/core/dev/dev_login.dart`) — **currently ON**; observed signing in as `twolip.test.partner@gmail.com` on 2026-08-01. (This doc previously claimed it was off.) When true, debug builds sign in with `DEV_EMAIL`/`DEV_PASSWORD` from `.env` (the Sheena test account) and open straight on the Nest, skipping login. Guarded by `kDebugMode` + `kDevAutoLogin` + presence of the env keys, so it can never run in a release build.
  - **Gotcha:** flipping the flag to false does *not* sign you out — Supabase persists the session in browser localStorage. To actually reach the login screen, also clear it: `Object.keys(localStorage).filter(k=>k.startsWith('sb-')).forEach(k=>localStorage.removeItem(k))` then reload.
- Give the app ~15–20s after load before judging the UI: cards render empty (partner "—", clocks −8h) until `currentPairProvider` resolves. That's load state, not a bug.
- The user interacts with the preview pane directly; automated clicking on the Flutter canvas is unreliable (glass-pane coordinate hack works sometimes; the user testing manually is faster).
- `flutter analyze lib` is the check before every server restart — keep it at zero errors/warnings.

## Renamed Twolip -> Dayflower (2026-08-30)

Product decision: **stays a couple app** — the inner-circle/family pivot was considered and declined. Only the name changed. Done before any launch, which is the cheapest this could ever be: nothing published, no users, no store listing.

Why Dayflower: it keeps the floral identity (the flower catalog and artwork are core), it names the *behaviour* — a daily touchpoint — rather than the relationship type, and as an arbitrary mark for social software it is more protectable than a descriptive name. Web/trademark searches turned up no app or live mark; the nearest, Kinfolk, is dead/abandoned. Rejected for direct collisions in this exact category: Hearth, Snug, Alcove, Kith, CloseKnit, Nearfolk, Ourglass, and "My Day" (Microsoft To Do, Snapchat/Instagram stories).

⚠️ Know the etymology: *Commelina communis* blooms open in the morning and wither the same day — in Japanese poetry (*tsuyukusa*) it is a stock symbol of transience. Chosen deliberately: the flower lasts a day, the record lasts forever, which is what Chapters accumulates.

**What changed**
- Dart package `twolip` -> `dayflower`; `TwoLipApp` -> `DayflowerApp`; `TwolipWidgets` -> `DayflowerWidgets`; `twolipWidgetBackground` -> `dayflowerWidgetBackground`.
- **applicationId / namespace / iOS+macOS bundle id: `com.example.twolip` -> `com.dayflower.app`.** Kotlin package directory physically moved to `com/dayflower/app/`; `TwolipWidget` -> `DayflowerWidget` (class, file, and `@xml/dayflower_widget_info`).
- Deep links `twolip://` -> `dayflower://`. Widget provider strings in `widget_sync.dart` match the manifest exactly — they are matched by string, so they must move together or widget taps die silently.
- Display names capitalised ("Dayflower") while binary/project names stay lowercase (`dayflower`), which is the Flutter convention.

**Deliberately NOT renamed** — changing any of these breaks something real:
- `twolip.test.partner@gmail.com` and the `<see DEV_PASSWORD in .env>` password — a real Gmail account.
- Notification channel ids (`heartbeat_pulse_v1`, `reminders_v1`) — Android freezes channel settings at creation; renaming silently resets users' sound/vibration prefs for no gain.
- home_widget data keys (`tulip_emoji`, `beat_mine`, ...) — matched by string against the Kotlin providers.
- The on-disk project directory, still `dev/twolip`. Renaming it breaks the working directory, launch configs and scratchpad paths. Optional follow-up.
- Supabase project ref and all table/column names.

**Verified:** `flutter analyze` clean, and `flutter build apk --debug` succeeds. `aapt2` on the built APK confirms package `com.dayflower.app`, label `Dayflower`, scheme `dayflower`, all three widget providers under the new package, and `HomeWidgetBackgroundReceiver` still declared (its absence is what killed widget taps once before).

🔴 **Still says Twolip: the artwork.** `assets/images/logo.png` is a squircle whose wordmark reads "2lip", and every launcher icon is generated from it. `AppColors.wordmark` / `wordNum` exist only to match that lettering. Until the logo is redrawn, the app icon on a phone home screen still says the old name. After replacing it: `dart run flutter_launcher_icons`.

⚠️ A **backup of the whole repo before the rename** is at `scratchpad/backup-pre-rename/` (370 files). This project has **no version control** — if the rename needs undoing, that copy is the only way back.

## Device preview (2026-08-01)

`device_preview` ^1.2.0 wraps the app so you can flip between iPhone SE, Pixel, iPad etc. in one running instance, with orientation, text-scale and light/dark toggles. Wiring is three pieces and all three are needed:

1. `main.dart` — `DevicePreview(enabled: kDebugMode, builder: ...)` around `ProviderScope`.
2. `app.dart` — `locale: DevicePreview.locale(context)` **and** `builder: DevicePreview.appBuilder` on `MaterialApp.router`. Without these the app ignores the frame and keeps rendering at the real window size, so the device picker appears to do nothing.
3. Run it on the **`flutter chrome`** launch config (port 8771), not `web-server` — you need a real browser window to use the toolbar.

- **`kDebugMode` is the release guard.** `DevicePreview(enabled: false)` is a pass-through, so a release build is structurally identical to before. Don't swap the flag for a hand-rolled bool.
- ⚠️ **It is a ruler, not an emulator.** Frames render on whatever engine you're actually on — Chrome's Skia here. An iPhone frame gives you iOS *dimensions*, never iOS rendering, fonts or scroll physics. iOS still cannot run on this Windows machine at all (no Xcode/simulator); an Android AVD is possible but none exists yet (`flutter emulators` → "No emulators available").

## Android builds

`flutter build apk --release` works as of 2026-07-28 → `build/app/outputs/flutter-apk/app-release.apk` (~55 MB). Signed with the **debug** key (Flutter's default fallback) — installable for testing, NOT publishable.

Getting there needed a JDK plus four Gradle fixes; don't undo them (6 is a recurring trap, not a fix to keep):

1. **JDK 17 installed** via `winget install Microsoft.OpenJDK.17`, then `flutter config --jdk-dir="C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"`. There was no Java on this machine at all.
2. **JVM target alignment** (`android/build.gradle.kts`): `home_widget` pins `jvmTarget 1.8` but depends on JVM 11 bytecode. The root `subprojects` block forces Java **and** Kotlin to 17 — both halves are needed, and it must be in the block *above* `evaluationDependsOn(":app")` (registering `afterEvaluate` after that throws "project is already evaluated"), and inside `afterEvaluate` (a `plugins.withId` callback runs before the plugin's own `compileOptions` overwrite it).
3. **Glance pinned to 1.1.1** (same file): `home_widget` declares `androidx.glance:glance-appwidget:1.+`, which now resolves to `1.3.0-alpha02` and demands AGP 9.1 + compileSdk 37. We render with classic RemoteViews, so the pin only satisfies the plugin's own compilation.
4. **Core library desugaring** (`android/app/build.gradle.kts`): required by `flutter_local_notifications`; `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
5. **INTERNET permission in `main/AndroidManifest.xml`** — Flutter's template declares it *only* in `src/debug/` and `src/profile/`, so the first release APK had no network access and every login died with the generic "Something went wrong". Verify after building with `aapt2 dump permissions <apk>`.
6. **After adding a plugin, force a real clean — `flutter clean` can silently leave `build/` behind on Windows.** Adding the updater's three packages (2026-08-30) made the release build fail with `cannot find symbol DeviceInfoPlusPlugin` / `PackageInfoPlugin` in `GeneratedPluginRegistrant.java`. The registrant is *generated* and was correct; both modules were included and on `:app:releaseCompileClasspath`. The actual fault was Kotlin **incremental-compilation state**: `compileReleaseKotlin` reported `UP-TO-DATE` and `BUILD SUCCESSFUL` while emitting no class for the plugin entry points — `build/device_info_plus/tmp/kotlin-classes/release/.../` held `MethodCallHandlerImpl.class` but no `DeviceInfoPlusPlugin.class`, and package_info_plus's output dir was empty. `flutter clean` had reported `Failed to remove ... windows/flutter/ephemeral` and left the redirected build dirs (this project sends them to `<repo>/build/<module>`, see the root `build.gradle.kts`) dated from July.

   Diagnosis, in the order that actually narrows it: check the module is in `./gradlew projects`, then on `./gradlew :app:dependencies --configuration releaseCompileClasspath`, then **unzip the module's `intermediates/compile_library_classes_jar/release/.../classes.jar` and look for the class**. A jar holding only `R.class` is the tell — a version conflict or a missing dependency errors out loudly, this does not.

   Fix: `cd android && ./gradlew --stop`, then `./gradlew :<module>:compileReleaseKotlin --rerun-tasks`, or delete `<repo>/build` by hand and confirm it is gone before rebuilding. ⚠️ Do **not** chase this by pinning dependency versions — that was tried first here and cost two full rebuilds; the versions were never the problem.

If a build dies with `FileSystemException: ... classes.dex ... used by another process`, a stale Gradle daemon holds the lock: `cd android && ./gradlew --stop`, then rebuild.

**Home-screen widgets** — three Android providers share one `home_widget` data store; keys live in `lib/features/widget/widget_sync.dart` and must match the Kotlin providers. Rendering for each look exists once: `TodaysTulipWidget.renderFlower()` and `HeartbeatWidget.renderHeartbeat()` are companion functions that `DayflowerWidget` calls, so the adaptive variant can never drift from the dedicated ones.

The heartbeat tap runs `dayflowerWidgetBackground` in a **background isolate** — nothing from the running app exists there, so it re-inits Flutter bindings, dotenv and Supabase. Supabase restores the persisted session itself, which is what makes it send as whoever is currently signed in (dev account or real).

⚠️ **`home_widget` ships an EMPTY AndroidManifest** (`<manifest package="es.antonborri.home_widget" />`) — it declares nothing. The app must declare `HomeWidgetBackgroundReceiver` itself or widget taps silently do nothing: the PendingIntent targets a component that doesn't exist, so the broadcast is dropped with no error anywhere. This cost one shipped-but-dead build (2026-07-28). After any manifest change, verify with:

```
aapt2 dump xmltree --file AndroidManifest.xml <apk> | grep -i antonborri
```

Other failure points for the background send, in order of likelihood: the receiver missing (above); `android:exported` — currently `false`, correct because the PendingIntent targets the component explicitly under our own app identity, but flip to `true` if taps stop working; then check `adb logcat` for `widget heartbeat background send failed`.

**Launcher icon** — generated from `assets/images/logo.png` by `flutter_launcher_icons` (config block at the bottom of `pubspec.yaml`). After changing the logo, rerun `dart run flutter_launcher_icons`; the generated mipmaps, `mipmap-anydpi-v26/ic_launcher.xml` and `values/colors.xml` are committed output, not hand-edited. The logo is a full-bleed squircle so it serves as the legacy icon directly; for adaptive icons it's inset 18% over `#F9EBE4` (= `AppColors.iconBg`, the artwork's own background) so the launcher mask can't crop the tulip.

⚠️ The APK bundles `.env` as a Flutter asset, so `DEV_EMAIL`/`DEV_PASSWORD` (the Sheena test credentials) ship inside it. Fine for a personal test build; strip them before distributing anything.

## In-app updater — sideload OTA (2026-08-30)

Built so a code change reaches the phone without a rebuild-and-re-sideload by hand: publish from the desktop, and the phone offers the update itself on its next launch or resume.

**Chosen over Shorebird code push deliberately.** Shorebird patches silently with no install dialog at all — but only for Dart and asset changes. Adding a plugin, touching Kotlin, or upgrading Flutter still forces a manual reinstall, and this project adds plugins often. Swapping the whole APK covers *every* change, at the cost of one tap in Android's installer.

**The loop**

```
dart run tool/publish_update.dart -n "What changed"
```

bumps `version:` in pubspec, builds the release APK, uploads it as `dayflower-<build>.apk`, then overwrites `latest.json`. The phone compares `buildNumber` against its own.

**Pieces**

| Where | What |
|---|---|
| `tool/publish_update.dart` | The publisher. Zero package deps — `dart:io` only. Flags: `--skip-build`, `--dry-run`, `--build n`, `--min n`, `-n/--note`. |
| `supabase/migrations/0014_app_builds.sql` | The `app-builds` bucket + read policy. **Applied** — bucket verified live. |
| `lib/features/updates/data/app_release.dart` | The manifest, parsed. |
| `lib/features/updates/data/update_repository.dart` | Check / download / install, plus the `UpdateController` state machine. |
| `lib/features/updates/presentation/widgets/update_sheet.dart` | The sheet. |
| `lib/app.dart` | Launch + resume checks, and the listener that raises the sheet. |
| Settings → About | The real installed version, and a manual "Check for updates". |

**Decisions worth not re-litigating**

- **Build number, never version name.** `versionName` sits at "1.0.0" across a hundred dev builds; the `+N` is the only thing that moves, so it is the only thing compared. The Settings version row now reads the installed build via `package_info_plus` instead of the hardcoded `AppConstants.appVersion` — once a number decides whether an update exists, showing one that can drift from the APK is showing a number that lies.
- **Public bucket — the only one in the project.** The check runs on a cold start *before login*, so it cannot use a session, an RLS policy or a signed URL. The trade: anyone who guesses the object name can download the APK. ⚠️ The APK bundles `.env`, so `DEV_EMAIL`/`DEV_PASSWORD` ship inside anything published here. Strip them before publishing anything that is not a personal test build.
- **No write policy on the bucket, on purpose.** Publishing uses the service-role key, which bypasses RLS entirely; with no write policy, no anon or authenticated session can replace an APK. Anyone who could overwrite `latest.json` would be handing our own users an installer prompt for their binary.
- **Service-role key lives in `.publish.env`, not `.env`.** `.env` is a Flutter asset — a service-role key in it would ship inside the APK, readable by anyone who unzips it. Both files are gitignored.
- **Plain `dart:io` HTTP, not `supabase_flutter`'s storage client.** `StorageClient`'s download buffers the whole object in memory with no progress callback, which is useless behind a progress bar for 60 MB.
- **The download renames on completion.** Bytes land in `.part`, and the rename is what makes a download "complete". Writing straight to the final name would let a connection dropped at 90% look like a finished APK on the next launch — and Android rejects that with a parse error the user can do nothing about.
- **Android only.** iOS has no legal route to self-installing an IPA; everywhere else the feature is a no-op rather than a button that fails.

**Gotchas**

- ⚠️ **The APK must stay signed with the same key** or Android refuses the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Release builds currently use the *debug* key (§ Android builds) — moving to a real keystore costs one final manual reinstall, and is best done before relying on this.
- ⚠️ `REQUEST_INSTALL_PACKAGES` is now in the manifest, and the phone must allow "Install unknown apps" for Dayflower once. That prompt comes from the OS the first time `OpenFilex` fires, which is why there is nothing to request up front.
- Downloads land in app-private external storage — one of the roots `open_filex`'s FileProvider is allowed to share out (`external-files-path` in its `filepaths.xml`). From a path it cannot share, the installer opens on nothing and says nothing.
- Supabase's CDN will happily serve a stale `latest.json`. The publisher sets `max-age=0` **and** the app appends a timestamp query param — both, because the header alone does not defeat it.
- "Not now" silences one specific build (SharedPreferences `update_skipped_build`); the next publish interrupts again. `--min <n>` makes an update unskippable for anyone on an older build.
- ⚠️ **`.publish.env` on Windows: two traps, both hit on the first attempt (2026-08-30).** PowerShell's `>` redirect writes **UTF-16LE with a BOM**, which `readAsLinesSync` refuses outright (`FileSystemException: Failed to decode data using encoding 'utf-8'`) — the script now honours the BOM. And the docs' `eyJ...` placeholder reads like a real key at a glance; pasted verbatim it produced a 62 MB upload that died on `Invalid Compact JWS`. The script now rejects a too-short or `...`-terminated key before building or uploading anything. Write the file with `cmd /c "echo SUPABASE_SERVICE_ROLE_KEY=<paste> > .publish.env"`.
- ⚠️ **Never publish with `--split-per-abi`.** Flutter's Gradle plugin rewrites versionCode for split outputs (`abiIndex * 1000 + versionCode`), so build 2 for arm64 ships as **2002**. The phone reports 2002, the manifest says 2, the comparison decides it is already newer, and the updater goes silent forever — no error, no sheet, nothing to notice. Caught on 2026-08-30 only by running `aapt2 dump badging` on the published APK. `tool/publish_update.dart` uses `--target-platform` instead, which leaves versionCode alone. **After any change to how the APK is built, re-check that `aapt2 dump badging <apk>` reports a versionCode equal to the manifest's `buildNumber`.**
- **Supabase's free plan caps a single object at 50 MB**, and refuses to let a bucket raise `file_size_limit` past the plan's — a `PUT` attempting it returns 413 itself. The universal APK is ~62 MB and simply cannot be published; the `--target-platform=android-arm64` build is ~24 MB. The publisher rejects anything over 50 MB before uploading.
- **The published APK assumes an arm64-v8a phone** (every Android device since roughly 2016). It is not a strictly single-ABI APK — plugin JNI libs for other architectures ride along — but only arm64 gets `libflutter.so` and `libapp.so`, so a 32-bit-only phone would install it and then crash. Publish with `--abi armeabi-v7a` for one of those.
- ⚠️ **`.publish.env` on Windows: two traps, both hit first time.** PowerShell's `>` redirect writes **UTF-16LE with a BOM**, which `readAsLinesSync` refuses outright; the loader now honours the BOM. And the docs' `eyJ...` placeholder reads like a real key at a glance — pasted verbatim it cost a 62 MB upload that died on `Invalid Compact JWS`. The publisher now rejects a too-short key before building or uploading. Write the file with `cmd /c "echo KEY=value > .publish.env"`, or Notepad.
- Resume checks are throttled to one manifest fetch per 3 hours. Settings → Check for updates ignores both the throttle and any "Not now".

## Home: mood card replaced the flower card (2026-08-01)

The "A FLOWER FOR YOU" card on Home is gone, replaced by a compact **Set your mood** card (`_MoodCard` in `home_screen.dart`, state in `features/home/data/mood_prefs.dart`). Six emoji chips, one tap, tapping the active one clears it.

- **Device-local only.** There is no `moods` table, so your mood does **not** reach your partner — it persists to `SharedPreferences` so the card survives a restart, and that is all. Syncing needs a migration + realtime stream shaped like `flower_messages`. Don't describe this as a working shared feature until that exists.
- Chips are `Expanded`, not fixed-width, so six fit a 320pt screen without overflowing.
- 🔴 **Two things silently lost their only caller when the flower card went:**
  - **`FlowerRepository.markSeen` now has no callers at all.** The Home card was the only place single-message receipts fired; `markThreadSeen` (opening the chat) is the sole receipt path now. Arguably more honest — you cannot have "seen" a message you never opened — but a partner who only glances at Home will no longer send a "Seen", which is a real behaviour change from what § Flowers tab documents.
  - **`latestReceivedFlowerProvider` is now dead code.** Nothing watches it. `widgetFlowerProvider` is unaffected and still feeds the OS widget. Delete it if no new Home surface wants it.

## Booth strips in the camera — async only (2026-08-30)

**Foundations landed; the picker UI and repository are not built yet.**

- `features/booth/domain/strip_templates.dart` — the 10 templates lifted out of `booth_screen.dart`, where they were private and only ever rendered mock emoji. 7 duo, 3 solo. `stacked` decides vertical strip vs side-by-side.
- `features/booth/domain/strip_compositor.dart` — renders the finished strip with the `image` package (**added as a direct dependency**; it was only transitive before). Runs via `compute` because compositing is hundreds of ms of CPU that would visibly hitch the camera preview.
- `supabase/migrations/0015_photo_strips.sql` — **applied** (verified live 2026-08-31).
- `test/strip_compositor_test.dart` — **the project's only tests.** (The old `widget_test.dart` was Flutter's counter-app stub referencing a `MyApp` that never existed here; deleted 2026-08-01.)

**Async only, and that is a product decision not a shortcut.** "Together" means both halves, not both at once. A live/sync session only works when both people are awake holding their phones — the exact situation this app exists because they are *not* in. A half-strip waiting overnight IS the feature.

**Why the composite becomes an ordinary photo message:** whoever completes the strip renders it client-side and posts the JPEG through the existing `sendDayPhoto` path. So chat rendering, the widget slot and 24h expiry all work unchanged instead of needing a second code path. There is no server-side image pipeline (that would need an edge function).

⚠️ **`img.decodeImage` throws on truncated/garbage bytes rather than returning null** — its format sniffers read past the end of a short buffer. The compositor's null-check was therefore dead code and a corrupt photo would have taken the isolate down mid-send. `_tryDecode` guards it. Found by the test, not by inspection.

**Now built:** `booth/data/strip_repository.dart` + the picker, banner and shoot-routing in `share_your_day.dart`.

- **Solo templates never create a row.** They composite and post immediately — there is nobody to wait for, so a strip record would be bookkeeping with no reader. `photo_strips` exists only for duo.
- **Joining beats starting.** If a half is already waiting on you, the shutter means "here's mine" — the armed template is ignored, because the template was theirs to choose.
- **Slot B is written before the composite**, so a render or upload that dies never loses the joiner's photo. The strip is left `isFullButUnposted` and `_recoverStranded` finishes it on the next stream tick. `_recoveryTried` guards the retry — `openStripsProvider` re-emits constantly and an unguarded retry would spin.
- The chooser is a sheet, not a grid over the viewfinder: a grid would cover the thing you are framing. Only the choice stays on screen, as one chip.
- Storage needed nothing new — halves live under the same `<pair_id>/` prefix, so 0013's policies already cover them.

⚠️ **Only `flutter clean` is not enough after a transitive plugin upgrades.** Adding `camera` + `image` let pub bump `device_info_plus` 11.5.0 → 13.2.0, and the next Android build failed with `GeneratedPluginRegistrant.java: cannot find symbol: class DeviceInfoPlusPlugin`. **The class exists** (Kotlin, right package) — the error is a *stale Gradle/Kotlin build cache* from the previous version, and it is thoroughly misleading. `dependency_overrides` is the wrong fix and cannot resolve anyway (`package_info_plus ^10.2.1` forces device_info_plus 13.x). The fix:

```
cd android && ./gradlew --stop
rm -rf build .gradle android/.gradle android/app/build
flutter build apk --debug
```

## Flower avatars (2026-08-31)

`users` had no avatar at all — every surface drew the first initial. An avatar is now a **flower id**, not an uploaded image: no Storage, no moderation, no upload failure path, and it fits an app whose whole vocabulary is flowers. 🔴 **Migration `0017_avatars.sql` not yet run.**

- `core/models/avatar_flower.dart` — eight flowers, **deliberately not `FlowerCatalog`**. That one carries artwork, meanings and *retired* entries; an avatar must never vanish because a sendable flower was retired.
- `core/widgets/flower_avatar.dart` — one widget for every surface. The chat header and conversation card each drew their own initial circle before; now they cannot drift, and adding real uploaded avatars later is a change in one place.
- **Defaults: daisy for men, tulip for women**, via `AvatarFlower.defaultFor`. Anything unrecognised — including every account created before 0015 — falls back to a tulip rather than guessing from a name.
- ⚠️ **`avatar` is left NULL at signup on purpose.** Null means "never chosen", which is what lets the gender default apply *and* keep applying if the gender is corrected later. Writing the default at creation would freeze it forever and make the column a lie.
- **Gender is only ever used to pick the default.** A chosen `avatar` always wins, it is never rendered, and it is nullable free-text so nobody is blocked from onboarding by it.
- ⚠️ **Onboarding does not collect gender yet.** Until it does, every new account gets the tulip fallback and the daisy default is unreachable except by editing the row directly. Adding the step, or a Settings row, is the remaining piece.
- The widget's avatar is **pushed from Dart as an emoji** (`day_photo_owner_flower`), not derived in Kotlin — the choice lives in Postgres and the widget has no database, same reason the name is pushed.

## Selfies stopped coming out mirrored (2026-09-02)

The front camera hands back the selfie view, so writing read backwards and a parting swapped sides in the saved photo.

- **Only the saved frame is corrected; the preview stays mirrored.** That is what people expect while framing, and un-mirroring it would make the camera feel wrong to use in exchange for fixing the wrong half of the problem.
- `unmirrorJpeg` is **top level and stateless** so `compute` can run it in an isolate — decoding and re-encoding a 1600px JPEG on the UI thread janks the shutter. Same reason the booth compositor does it.
- **Never throws.** Undecodable input comes straight back out: a photo the wrong way round is a far smaller problem than one that vanishes because a decode failed.
- `test/unmirror_test.dart` checks it actually reverses the pixels (an asymmetric 4×1 stripe — a symmetric image would pass either way), that it is its own inverse, and that junk input is returned untouched.
- The destination pill moved back to the **top right**; centring it looked worse next to the title.

⚠️ If a selfie ever looks correct in the preview but reversed in the result, this flip is the thing to remove — the two halves are deliberately different, so it is one `if` in `_shoot`.

## Home arch is tappable (2026-09-02)

- **A photo opens `DayPhotoViewer`; the empty arch opens the camera.** The arch used to send every tap to the conversation, which was the one thing it was not showing.
- **Handled per photo, not on the whole arch.** With two stacked, a single tap target would have to guess which day you meant — so each half carries its own tap and its own `who` label ("Wifey's day" / "Your day").
- `DayPhotoViewer` had been orphaned by the camera rework: the story chips that used to open it were removed with the rest of the old chrome, and nothing else called it. This gives it a caller again rather than leaving dead code behind.

## Camera chrome, TikTok-style (2026-09-02)

- **No header.** The "My Day" title and close button moved inside the frame, top-left, over the picture. The screen has no top `SafeArea` — the viewfinder runs under the status bar the way a camera should — and `MessagesScreen` is now nothing but `ShareYourDayBar`.
- **Vertical rail down the right** for flip/flash while live, and discard/save while a shot is held. Same corner either way, so the thumb never learns a second place to look.
- **Destination is a pill in the "Add sound" position**, centred with a `Stack` rather than a `Row` + `Spacer` — a Row would centre it in whatever space the title leaves, so it would drift as the title changed. Chosen *before* the shutter instead of confirmed after: the answer is nearly always the same, and a sheet on every send taxes the common case.
- ⚠️ **`to_chat` (migration 0018) exists because "Widget" was not expressible.** Every day photo is a message row and the thread renders every row it can see, so `to_widget` alone gave two states, not three — "Widget" and "Both" would have been the same thing with different labels. Now: widget = `to_widget true, to_chat false`; chat = `false/true`; both = `true/true`. Defaults to true so all 32 existing rows, plus every flower and text message, stay in the thread. The thread reads `chatMessagesProvider`, which filters in Dart because the raw stream still has to feed the widget and day-photo lookups the rows it hides.
- `chatMessagesProvider` keeps the `AsyncValue` rather than flattening to a list — `valueOrNull ?? []` would render a failed load as "no messages yet", which looks identical to the honest empty state and means the opposite.

## Five-tab nav + camera rework (2026-09-02)

**Nav is five tabs now** — Home, Flowers, Camera, Dates, Activities — and **only the selected tab shows its label**. Five labels across a phone means five truncated words; showing one makes the selection obvious without a pill or underline, and `AnimatedSize` collapses the gap so the icons do not shift as it comes and goes. Every tab keeps its `Semantics(label:)` so an unselected tab is not an unlabelled button to a screen reader.

⚠️ **Route naming is now misleading and worth knowing.** `Routes.flowers` (`/app/flowers`) renders the **camera**, and `Routes.chat` (`/app/flowers/chat`) renders the conversation. The Flowers tab goes to `chat`, the Camera tab to `flowers`. Selection uses `==`, never `startsWith` — chat is nested under the camera's path, so `startsWith` would light both tabs at once.

**Camera (`share_your_day.dart`):**

- **Nothing uploads on the shutter any more.** The frame is held in `_pending`, the viewfinder freezes on it, and it leaves the device only after the send button and a destination choice. Mis-tapping used to put a photo on someone's home screen for 24 hours. Gallery picks go through the same review — picking the wrong thumbnail is at least as easy as mis-tapping.
- **The shutter becomes the send button** rather than a second control appearing: same button, same place, next step. The gradient disc stays and only gains a paper-plane.
- **Cancel and save replace flash and flip** in the same corner while a shot is held, so the thumb does not learn a second place to look.
- ⚠️ **"Save" writes to the app's own external folder, not the system gallery.** MediaStore needs a plugin; the toast says where it went rather than implying it landed in Photos.
- **Destination is an explicit choice** — home screen (`to_widget: true`) or chat only (`to_widget: false`). Two different acts, so two buttons rather than a setting.
- **Templates are a scrollable row of circles** over the viewfinder, replacing the chip-plus-sheet. Circles read as controls; rectangles would read as content already shot.
- The flower button and the "your day / their day" chips are gone — the home arch shows both, and sending a flower is a different errand.

## Home header redesign (2026-09-01)

Greeting, partner's whereabouts, distance, and today's photos in one block.

- **"Good morning," / name in brand pink / 🌷**, matching the reference. The name is `petName ?? displayName` — the pet name is the one they call you, which is the whole point of the line.
- **`partner · city · their local time`** on one line, because it is one thought. City comes from `zoneCity()`, time from the partner's IANA zone.
- **Distance replaced "Day N together"** — `core/utils/zone_distance.dart`, haversine over a table of zone→city coordinates. Deliberately **not GPS**: asking a couples app for location permission to print one line would be a bad trade, and the timezone is already on the profile for the dual clocks. An unknown zone returns **null and the line is hidden** rather than guessed. Same zone reads "Together 💛", not "0 miles apart" — technically true, emotionally wrong. `test/zone_distance_test.dart` checks against real distances (London↔Dubai ≈ 3,410 mi, London↔Manila ≈ 6,690 mi, NY↔LA ≈ 2,450 mi).
- **The arch panel** shows their day photo on top and yours beneath, stacked. One photo fills the arch — half a panel with a gap under it reads as something failing to load. Neither: a **dashed arch** with "Share your day", hand-painted in `_DashedArchPainter` because Flutter's `BorderSide` has no dash support and a dotted rectangle behind an arch-shaped hole shows the mismatch at the corners.
- **`ClocksCard` moved to Dates.** The greeting now carries the partner's city and local time, so the clocks were saying it twice; Dates is where "when" already lives.
- **Collapsing top bar (2026-09-01).** `SliverAppBar` with `floating: true, snap: true` inside a `CustomScrollView` — it slides away as you read down and comes back whole on the first upward flick, rather than dragging in a pixel at a time. Left: 🌷 + app name. Right: the **couple pill** — both avatars overlapping, both pet names, chevron → Settings. Overlapped rather than spaced, because two touching circles read as a couple and two spaced ones read as a list; the second face carries a hairline of the bar's own colour so the overlap separates.
- **The greeting is bottom-aligned to the arch**, with `AppSpace.sm` of lift so it clears the baseline rather than sitting flush. Top-aligning left the heavier text block floating above a tall panel.
- ⚠️ **Settings moved into Activities.** The home avatar was the only route to Settings when the redesign landed (the couple pill has since restored one) — the bottom nav has four tabs and `Routes.us` is referenced nowhere — so removing it for the new design would have stranded sign-out, timezone, disconnect and check-for-updates.

## Widget story header (2026-08-30)

The photo widget now carries an Instagram-style header over the image: avatar, whose day it is, and how long it has left ("16h"). Layout `todays_tulip_widget.xml` (`widget_header`), rendered by `TodaysTulipWidget.renderStoryHeader`.

- **The countdown is computed in Kotlin, not pushed from Dart** — same reason as the expiry itself. The widget outlives the app process, so a "16h" written at sync time would still read 16h tomorrow. `timeLeftLabel` derives it from `day_photo_expires_at` on every redraw.
- **The avatar is the first initial on the brand gradient** (`drawable/avatar_circle.xml`), because **`users` has no avatar column** — only `display_name`, `pet_name`, `timezone`. That matches what the chat header and conversation card already draw. If real avatars are ever added, this is one of the places that has to learn about them.
- **The header hides entirely when there is no live photo.** A name and a countdown floating over the fallback flower glyph would be describing something that isn't there.
- Its own top scrim (`widget_header_scrim.xml`) mirrors the caption scrim, so the header stays legible over a bright photo without dimming the whole image.

The chat card was also **removed from the Flowers tab** — it moved to Home, and having it in both meant two places showing the same row.

## Share your day (2026-08-30)

A photo you send lands on your partner's **home-screen widget for 24 hours**, then leaves it — while staying in the conversation forever. This is the feature the app is named after: the bloom lasts a day, the record doesn't.

**The card is a full-bleed camera** (rebuilt 2026-08-30): the viewfinder fills the whole card and every control floats over it. Bottom row is **upload · shutter · flower**; **flash (torch)** and **flip camera** sit top-right. `MessagesScreen` gives it `Expanded`, so it takes every pixel the conversation row doesn't — a fixed height would letterbox tall phones and overflow short ones. Sharing costs one tap; the earlier version routed every share through a picker sheet, which made the common case the slow one. Live days (yours and theirs) appear as small chips *below* the row, and only once one exists — so the resting state is exactly the three controls.

- Needs the **`camera`** package (added 2026-08-30) plus `android.permission.CAMERA` and iOS `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`.
- The controller is **released on background and retaken on resume** (`didChangeAppLifecycleState`) — a live preview holds the sensor open.
- **Flip rebuilds the controller** (there is no lens-swap API): dispose, then re-init on the other `CameraLensDirection`. `_torchOn` resets on every re-init because the torch belonged to the disposed controller. The flip button only renders when more than one lens actually exists.
- **Torch failure is expected, not exceptional.** Front cameras and virtually all webcams have no flash, so `setFlashMode` throwing is caught and surfaced as "No flash on this camera."
- The preview uses `BoxFit.cover` inside a `FittedBox`: `CameraPreview` reports the sensor's aspect ratio, which never matches the card, and letterboxing would put black bars inside a full-bleed surface.
- **`_camUnavailable` is a real path, not an edge case:** no device, denied permission, or a browser that won't hand a camera over. The viewfinder becomes a tap-target that falls back to `image_picker`'s OS camera, so the feature degrades instead of vanishing. This is what you get in Chrome if you decline the permission prompt.
- The flower sheet offers `FlowerCatalog.pickable`, not `.all` — retired flowers stay renderable for old messages but must never be offered as new sends.

Files: `presentation/widgets/share_your_day.dart` (bar + viewer), `sendDayPhoto`/`signedPhotoUrl`/`downloadPhoto` in `flower_repository.dart`, photo branch in `chat_bubble.dart`, `syncFlower` in `widget_sync.dart`, `loadDayPhoto` in `TodaysTulipWidget.kt`.

✅ **0013 is applied and this works end-to-end** — verified against the live DB 2026-08-30: `image_path` exists, the private `day_photos` bucket exists, and three real photos are uploaded (73KB–547KB) from both accounts, all with `to_widget=true`. Camera → upload → Storage → message row is proven, not just compiling.

**Design decisions that are load-bearing:**
- **Expiry is COMPUTED from `sent_at`, never stored, and nothing is ever deleted.** `isFreshForWidget` gates the widget; the row is untouched. That is what lets the photo stay in the chat after it leaves the home screen. Do not "fix" this by adding an `expires_at` column or a cleanup job.
- **Expiry is enforced twice, on purpose.** Dart stops publishing the photo, *and* `TodaysTulipWidget.loadDayPhoto` checks `day_photo_expires_at` itself. The Kotlin check is the one that matters: if the app is never opened, no sync runs, and without it a "24 hour" photo would sit on the home screen indefinitely. Widgets refresh every 30 min (`updatePeriodMillis`), so it clears within half an hour of the mark.
- **Newest wins for the widget slot.** `widgetFlowerProvider` scans newest-first and takes the first eligible message — flower or photo — rather than preferring a kind. Flowers were kept fully intact.
- **The photo reaches the widget as a FILE path, not bytes.** RemoteViews cross an IPC boundary with a hard size limit; a full camera bitmap silently renders blank. Dart caches to `getApplicationSupportDirectory()` keyed by message id (so repeat syncs skip the download), and Kotlin decodes with `inSampleSize` down to ~512px.
- **The bucket is private**, so there is no permanent URL — every render mints a signed URL. Objects are keyed `<pair_id>/<uuid>.jpg` because the Storage RLS policy reads that first path segment to check pair membership. Changing the path shape breaks the policy.
- Upload happens **before** the row insert: a row pointing at a failed upload is a permanently broken bubble, whereas an orphaned object is invisible and cheap.

⚠️ **Inherits the existing widget limitation:** the widget only learns about a new photo while the app is running. A photo that arrives with the app fully closed does not appear until next launch. Expiry is unaffected — that side is self-enforcing.

⚠️ **Unverified end-to-end.** `flutter analyze` is clean and `flutter build apk --debug` succeeds, but nothing here has been run against real data (0013 is unrun) and the widget has still never been placed on a real home screen.

## Messages tab = inbox → thread (2026-08-01)

The tab used to open the conversation directly. It now opens an **inbox** (`messages_screen.dart`, `MessagesScreen`) and the thread sits behind it — the same hub/sub-route shape as Activities.

- **Routing:** `Routes.flowers` (`/app/flowers`) → inbox; **`Routes.chat` (`/app/flowers/chat`)** → `FlowersScreen`. Chat is nested under the inbox path so `AppBottomNav`'s `startsWith` keeps MESSAGES lit inside the thread.
- **The list is one row deep and that is fine.** A couple has exactly one conversation; the row exists so the tab reads as a place you opened rather than one you fell into, and so there is somewhere to land when backing out of the thread. `FlowersScreen` gained a back chevron for that.
- **Two entry points deliberately skip the inbox** and go straight to `Routes.chat`: the Home flower card (it *is* the message) and the home-screen widget tap in `app.dart` (`_openTulip`). Sending someone through a one-row list to reach the thing they tapped is pure friction.
- **The thread has no bottom nav at all.** `FlowersScreen` no longer builds `AppBottomNav` — the tab bar belongs to the inbox you came from, and the back chevron is the way out. This also retired the old `showNav` dance that hid it whenever the keyboard or catalog drawer came up. ⚠️ The Scaffold is `SafeArea(bottom: false)`, so with the nav gone **nothing else clears the gesture bar**: the manual `SizedBox(height: MediaQuery.paddingOf(context).bottom)` at the end of the column is now load-bearing whenever the keyboard is down, not just when the drawer is open.
- **The nav badge is suppressed only on `Routes.chat`**, not on the inbox — seeing the list is not the same as having read anything, and `markThreadSeen` only fires in the thread.
- The inbox preview names a flower rather than rendering it (`🌷 Red Tulips · caption`), prefixes `You:` for your own last message, and uses the standard time → "Yesterday" → weekday → date ladder.

## Icon set = Cupertino (2026-08-01)

Icons were a mix of Material `_rounded` and `_outlined` glyphs; they are now **`CupertinoIcons`** throughout for a rounder, iOS-like feel. The swap was scripted across 14 files, so keep new icons Cupertino unless there is a reason not to.

Four deliberate holdouts, all because Cupertino has no equivalent — do not "finish the job" on these:
- `Icons.local_florist_rounded` — there is no flower in the Cupertino set (composer button, welcome screen).
- `Icons.done_rounded` / `Icons.done_all_rounded` — Cupertino has no double-check, and the read-receipt pair must match each other.
- `Icons.apple` / `Icons.facebook` — brand marks.

⚠️ Adding `package:flutter/cupertino.dart` next to `material.dart` can make the Material import **unnecessary** (`clocks_card.dart` hit this — Cupertino re-exports `widgets.dart`, so a file using no Material-specific widget no longer needs it). Drop the Material import when the analyzer says so.

⚠️ The Activities tab icon changed meaning as well as style: `photo_camera` → `CupertinoIcons.square_grid_2x2_fill`, because that tab is a hub of five things now and a camera only ever described the booth. Revert to `CupertinoIcons.camera` if the grid reads too generic.

## Flowers tab = the conversation (2026-08-01)

The Flowers tab is a messaging thread. Flowers and text share **one table and one timeline** (`flower_messages`), so a flower is a message with artwork attached rather than a separate ritual. Files: `flowers_screen.dart` (thread + composer), `presentation/widgets/chat_bubble.dart`, `presentation/widgets/flower_catalog_panel.dart`.

- **The one-per-UTC-day rule is gone.** `flower_one_per_day_idx` is dropped in 0009. This was a deliberate product call, not an oversight — a chat you can only post to once a day isn't a chat. Don't reinstate it without also rethinking the whole screen. `sentTodayProvider` survives as `sentFlowerTodayProvider` but now only drives *copy*; nothing is blocked by it, and `AlreadySentTodayException` is deleted.
- **A row is a flower OR text.** `flower_type` is nullable; `note` doubles as the caption of a flower and the body of a text message. `FlowerMessage.isText` / `.flower` are the accessors — `FlowerCatalog.byId(message.flowerType)` no longer compiles. The DB check `flower_messages_has_content` guarantees a row is never blank.
- **`to_widget` is the sender's choice**, ticked by default in the send sheet. The recipient's app resolves `widgetFlowerProvider` (newest incoming flower carrying the flag) and pushes *that* to the home-screen widget; unticked flowers stay in the thread and never reach it. Sending another ticked flower replaces what's on their screen.
- **Two different "latest" providers, don't merge them:** `latestReceivedFlowerProvider` (any incoming flower) feeds the in-app Home card; `widgetFlowerProvider` (ticked only) feeds the OS widget. The Home card deliberately shows flowers the sender chose *not* to pin — it mirrors the conversation, the widget honours the choice.
- **Copy moved off "today"** in all three places that mirror each other: the Home card, `@string/widget_label`, and `widget_description` now say **"A FLOWER FOR YOU"**. ⚠️ `website/app/page.tsx` still says "Today's Flower" — the site was left alone, so those are now out of sync. Fix if the site is touched.
- **Read receipts are thread-wide.** `markThreadSeen(pairId, userId)` fires whenever the tab is open with anything unread, so opening the chat marks everything. The Home card still calls the single-message `markSeen` — a partner who only glances at Home would otherwise never send a "Seen". Both are safe because the recipient-only RLS update policy from 0004 rejects marking your own messages.
- **Keyboard/drawer choreography** is the fiddly part of `flowers_screen.dart`. The catalog is an inline panel (not a modal sheet — a sheet would cover the thread you're picking for), sized to the *remembered* keyboard height captured in `didChangeDependencies` so swapping between keyboard and drawer doesn't make the conversation jump. The bottom nav is hidden whenever the keyboard or drawer is up, which is why the bottom safe-area inset is applied manually in that one case.
- **The chat header carries reserved call + video-call buttons** (`_HeaderAction` in `flowers_screen.dart`), added 2026-08-01. There is no calling backend at all — no WebRTC, no Agora/Twilio in pubspec — so both fire the same "coming soon" snackbar as the composer's photo icons. Wiring them up is a whole feature, not a TODO.
- **The composer's attach + camera icons are reserved, not broken.** They show a "coming soon" snackbar, the same pattern as the login screen's OAuth buttons. Photo messages need a Supabase Storage bucket + policies (a new migration), an image message kind, and upload/progress handling — none of which exist. Wire the icons up when that lands.
- All four composer controls live *inside* the input pill (flower left; attach + camera right), with only the gradient send circle outside. The pill is a `Material`, not a decorated `Container`, so those icons' ripples paint on the pill instead of on the Scaffold underneath where they'd be invisible.
- Bubbles use blush-vs-white + alignment, **not** the signature gradient — design.md spends that once per screen region and here it's the send button. Newest-first list + `reverse: true` keeps scroll offset stable when a message lands.
- The Flowers tab now carries an **unread badge** (`unreadMessageCountProvider`); `AppBottomNav` became a `ConsumerWidget` for it. Costs nothing extra — `flowerMessagesProvider` is already watched app-wide from `app.dart`.

## Events tab = one page (2026-08-01)

The Events tab was three inner tabs (Reunion · Cycle · Events) and is now a **single scroll**: `events_screen.dart` (`EventsScreen`). `dates_screen.dart` / `DatesScreen` is deleted. Still **entirely mock, local state** — there is no `events` table, and the screen does not touch `reunionProvider`.

- **The reunion is no longer a separate object.** There is one `_Event` list; a reunion is an event whose `kind` is `reunion`, carrying the old `_ReunionData`'s `location` + `note` fields. The old screen kept a standalone `_ReunionData` *and* a "Tokyo Reunion" row in the events list, with two separate edit sheets — editing one never touched the other. One list, one `_EditEventSheet` now.
- **The hero countdown is derived, not stored:** it renders `_upcoming.first`, so it follows whatever is soonest. "Also coming up" deliberately skips that entry (`_upcoming.skip(1)`) because the hero *is* it — don't "fix" the apparent missing first row.
- **The clocks are gone from this page** (2026-08-01). They were a *mock duplicate* — hardcoded `Asia/Manila`/`Europe/London` with a fixed-offset table that ignored DST — sitting alongside the real `ClocksCard` on Home, which reads actual profile timezones and has a working picker. The real one moved to the **top** of Home; the mock one and its edit sheet, `_TZOption`/`_timezones`/`_findTZ`/`_localTime` are deleted. `_myName`/`_partnerName` stay because the cycle copy still uses them.
- **Cycle is collapsed by default** behind `_cycleOpen`. Phase banner + the 3 stats stay visible; calendar, legend, support tips and the share toggle expand. This was the call that made three tabs fit one page without a wall of content.
- **The calendar renders the real current month**, not the old hardcoded "April 2026 / today = the 20th". Everything cycle-related derives from one anchor (`_cycleAnchor`, mocked at 15 days ago) via `_cycleDay`/`_phaseOn`, so calendar, stats and tips cannot disagree the way hardcoded values did.
- **Seed events are relative to today** (+21/+47/+84 days, one at −12 to populate "Passed"). The old screen hardcoded 2026-05 dates, which have since passed — the countdown was dead on arrival. Keep offsets, not literals, until this has a backend.
- Tokenised throughout: the old file hardcoded hexes (`0xFF160810`, `0xFFE53E6A`) and raw `TextStyle(fontSize:)`, both banned by design.md. Now `AppGradients.hero` for the hero, `AppColors.period/fertile/ovulation/pms` for phases, `AppText.*` for every string.
- **Verified:** `flutter analyze lib` clean (zero errors/warnings, zero infos in this file). **Runtime behaviour is unconfirmed** — the "router holds `/app/events`" check was reading `location.pathname` on a hash-routed app and proved nothing (see § Activities tab = a hub for the trap). Nobody has seen this screen render.

## Activities tab = a hub (2026-08-01)

The Activities tab used to *be* the photo booth — tapping the tab dropped you straight into `BoothScreen`, so the booth and the tab were the same thing and there was nowhere to put anything else. The tab is now a menu: `lib/features/activities/presentation/screens/activities_screen.dart` (`ActivitiesScreen`), a **new feature folder**, with the booth demoted to one entry in it.

- **Routing:** `Routes.activities` (`/app/activities`) → the hub; **`Routes.booth` (`/app/activities/booth`)** → `BoothScreen`. The booth path is *nested under* the hub path on purpose — `AppBottomNav` now selects ACTIVITIES with `location.startsWith(Routes.activities)` instead of `==`, so the tab stays lit inside the booth. Move the booth to a top-level path and the tab silently goes dark.
- **`BoothScreen` gained an `IosBackButton`**, because as a sub-route it had no way back out. Its header `Row` held a bare `Column` + `Spacer`; adding 52px of back button overflowed it, so the Column is now `Expanded` with an ellipsised subtitle. Long pet names would have overflowed that row even before the back button.
- **Only the booth is built.** Async games, Travel map, Goals and Music are declared as `SOON` tiles that fire a "coming soon" snackbar — the same honesty pattern as the login screen's OAuth buttons and the chat composer's attach icon. They are listed rather than hidden so the intended shape of the tab is visible, but nothing pretends to work.
- The booth itself is **untouched apart from the header** — still on its own local palette (`_rose`, `_charcoal`, `_screenBg`) and mock data, still not on design.md tokens. Restyling it was out of scope; it is the obvious next cleanup.
- **Verified:** `flutter analyze lib` clean. **Nothing here has been confirmed on screen or at runtime** — the route checks that appeared to pass were reading `location.pathname` on a hash-routed app (see the warning below), so they proved nothing. The hub, the booth back button and the `startsWith` nav highlight all still need a human to actually open the tab.

⚠️ **The app uses HASH routing on web** — the real route is `location.hash` (`#/app/home`), **not** `location.pathname`. Browsing to `http://localhost:8770/app/activities` leaves the app sitting on `#/app/home` while `pathname` happily reads `/app/activities`, so any check based on `pathname` is meaningless and will report success for a screen that was never built. This cost a full round of bogus "the route resolves" verification on 2026-08-01. Read `location.hash`, and note the preview tooling strips the fragment when navigating, so a URL alone may not get you there — clicking the bottom nav is the reliable route change.

⚠️ **The preview pane could not be trusted for screenshots on 2026-08-01.** It composites at the wrong scale after a viewport change, sometimes refuses with "the Browser pane is not displayed", and clicks on the Flutter canvas mostly do not register (already noted under How to run). Console reads and overflow warnings stayed reliable — but they only tell you about *the screen that is actually mounted*, which given the hash-routing trap above may not be the one you think.

## ⚠️ Sent messages did not appear in the thread (2026-08-01)

**Symptom:** typing a message and hitting send left the conversation unchanged. **The insert was succeeding the whole time** — rows for the failed-looking sends are in `flower_messages` with correct `sent_at`, `note` and a null `flower_type`.

What was ruled out, with evidence rather than reading:
- **Not the schema.** 0009 is applied (see § Supabase). A probe insert with a null `flower_type` fails with `42501` (RLS), *not* `23502`, so the column is genuinely nullable.
- **Not rendering.** `ChatBubble` branches on `message.isText` and renders `note` correctly; `_buildThread` filters nothing.
- **Not the send path.** `_sendText` awaits the insert and only shows an error on throw. No throw — the rows exist.

**Cause:** the thread rendered *only* what the realtime stream echoed back, so a perfectly successful insert stayed invisible whenever the echo did not arrive.

**Fix:** `_pending` in `flowers_screen.dart` holds messages this session has successfully written, merged into the thread by id in `_withPending()` and dropped again by the `ref.listen` in `build` as soon as the stream carries them. Deliberately **not** `ref.invalidate(flowerMessagesProvider)` — invalidating an autoDispose StreamProvider drops it to a loading state and would blank the whole conversation on every send.

✅ **Realtime was never the problem.** Confirmed 2026-08-01 via `select tablename from pg_publication_tables where pubname = 'supabase_realtime'` — `flower_messages` is published (along with `pairs`, `heartbeats`, `reunions`, and a legacy `tulips` table that nothing reads any more). The real cause was the ordering bug below; the message *was* arriving, it was just being rendered at the far end of an inverted list.

## 🔴 The thread rendered upside down — `.order()` defaults to DESCENDING (2026-08-01)

**`SupabaseStreamBuilder.order(column)` and `PostgrestTransformBuilder.order(column)` both default to `ascending: false`.** A bare `.order('sent_at')` *reads* as oldest-first and is the exact opposite.

`watchPairFlowers` relied on that default and documented itself as "oldest first"; `flowerMessagesProvider` then applied `.reversed` to "get newest-first". Two wrongs made an oldest-first list that every consumer treated as newest-first. Fixed by making the repository explicitly `ascending: false` and deleting the `.reversed`.

This one bug produced three separate symptoms, which is why it was worth chasing rather than patching:
1. **The chat rendered newest-at-top.** `ListView(reverse: true)` puts index 0 at the *bottom*, so an oldest-first list inverts the whole conversation.
2. **Sent messages looked like they vanished** — they were landing at the wrong end of the thread, off screen. The `_pending` echo above is still worth keeping (it decouples your own sends from the round trip) but it was treating a symptom.
3. **The Home card and the home-screen widget showed the *first* flower ever received, not the latest.** `latestReceivedFlowerProvider` and `widgetFlowerProvider` both scan with `for … return` and take the first match, which means "newest" only if the list is newest-first. This is why Home kept showing "Classic Tulips / I love youuu" from 2026-07-06.

⚠️ **Audit any new `.order()` before trusting it.** `HeartbeatRepository.watchRecent` is *accidentally* correct — descending is what makes its `.limit(500)` the newest 500 rather than the oldest — and is now explicit so nobody "fixes" it into a bug. `PairRepository.getMyPair` is order-insensitive in practice.

## Heartbeat: daily reset + "no heartbeat yet" nudge (2026-08-30)

**The in-app counter was always daily** (`todayHeartbeatCountsProvider` filters on `_isToday`). **The widget was not.** It stored `beat_mine`/`beat_partner` and only changed when Dart synced — and midnight is not an event Dart hears about, so a phone that never opened the app showed yesterday's tally indefinitely.

- **The reset now happens in Kotlin, not Dart.** Dart writes `beat_date` (`yyyy-MM-dd`, local) next to the counts; `HeartbeatWidget.renderHeartbeat` compares it to its own `SimpleDateFormat("yyyy-MM-dd")` and renders **0** when they differ. Widgets refresh every 30 min, so the reset lands shortly after midnight with the app closed. ⚠️ The two format strings must stay identical or the widget reads every day as stale and shows zero forever.
- Same shape as the day-photo expiry: **the widget enforces time, because only the widget is awake.**
- Widget copy nudges a first send — `heartbeat_widget_prompt` is now "No heartbeat yet today — tap to send", and the partner line says "hasn't tapped yet **today**".

**`HeartbeatNudge` (`features/heartbeat/data/heartbeat_nudge.dart`)** fires a local notification at **20:00** when you haven't sent one.

- **It is a cancel-and-rearm one-shot, not a daily repeat.** A local notification cannot evaluate a condition when it fires, so a repeating alarm would nag you on days you had already tapped. Exactly one is ever pending — today's, or tomorrow's once today's moment passes — and sending cancels it. Re-armed from `app.dart` on every change to `todayHeartbeatCountsProvider.mine`, and once on first frame.
- **Its own channel** (`heartbeat_nudge_v1`), because Android freezes importance and sound at creation and a nudge is not a pulse.
- **Inexact alarm on purpose**, unlike Reminders: a nudge sliding a few minutes costs nothing, and the exact-alarm permission is worth spending only on times the user explicitly set.
- Device-local and defaults on. `HeartbeatNudge.setEnabled(false)` exists; **there is no Settings toggle wired to it yet** — that is the obvious next step, next to the existing Alerts controls.

⚠️ **Unverified.** Analyzer clean and the APK builds, but the daily rollover and the 20:00 nudge both need a real phone and a date change to actually observe.

## Heartbeat alerts (vibrate + sound)

`lib/core/services/pulse_alerts.dart` fires when a partner pulse lands. Controls live in Settings → Alerts only (the card's bell icon was removed 2026-08-01), persisted per-device in `SharedPreferences` (`heartbeat_alerts_enabled`, `heartbeat_alert_cadence`). Things that will bite:

- **There is no push backend.** Alerts only fire while the app is alive — foreground *or* backgrounded — and the Supabase realtime stream is connected. Fully close the app and the pulse is missed; the count still reconciles on next launch. Real delivery to a closed app needs FCM/APNs + a Supabase edge function, which needs a Firebase project and `google-services.json` that don't exist yet.
- **Throttling is the `onlyAlertOnce` trick.** Inside the cadence cooldown (default 10 min) extra pulses re-`show()` the *same* notification id with `onlyAlertOnce: true` + `silent: true`, which rewrites the text and appends "+N more since" without sound, buzz or heads-up. So a partner tapping twenty times is one interruption. Cadence is user-chosen: every pulse / 10 min / 30 min / hourly.
- Notification bodies come from `PulseAlerts.messages` ("I miss you 💗", "Thinking of you", …), picked at random but never the same line twice running. A coalesced update deliberately keeps the *previous* line — swapping it would look like a second, different message arrived.
- **Sound rides on a local notification**, not an audio player — that's the only path using packages already in the project, and it means a backgrounded phone still lights up. Trade-off: a heads-up banner appears even when you're looking at the card (it self-clears after 8s via `timeoutAfter`).
- **Android freezes channel settings at creation.** Sound/vibration on channel `heartbeat_pulse_v1` can never be changed in code — bump the `_v` suffix or the change is invisible on any phone that already ran the app.
- `res/raw/heartbeat.wav` is a synthesised lub-dub (generator script isn't committed; it's ~1.2s of low sine thumps). Android only — the file would have to be added to the Runner target in Xcode for iOS, which hasn't been done, so iOS gets the default chime plus the haptic pattern.
- Vibration goes through the `vibration` package rather than the notification channel, because `VibrationEffect.createWaveform` needs the intensity list to be exactly as long as the pattern (gaps carry a 0) — see `PulseAlerts._pattern`.
- Manifest gained `VIBRATE` + `POST_NOTIFICATIONS`; the latter is requested at runtime the first time alerts are enabled (and once per launch if already on). Declining leaves the buzz working, just silent.
- **`res/raw/keep.xml` is load-bearing.** Both the icon and the sound are named only from Dart strings, which the release resource shrinker cannot see — the first release APK silently shipped without `@drawable/ic_notification` (debug was fine; shrinking only runs on release), so the notification could not post at all and there was no sound. Any future resource referenced by name from Dart must be added to that keep list. Verify after a release build:
  `aapt2 dump resources build/app/outputs/flutter-apk/app-release.apk | grep -E "ic_notification|raw/heartbeat"` — a missing entry means it was stripped.

## Widget ripple (`HeartbeatRipple.kt`)

Home-screen widgets cannot animate — `RemoteViews` has no animator and the framework only redraws on `updateAppWidget`. The ripple is therefore **five full widget redraws pushed ~80ms apart** (`ripple_ring_1..5` + a rest frame), tinted pink for sent and lavender for received via `setColorFilter`, faded with `setImageAlpha`, with the heart's `setTextViewTextSize` swelling and settling alongside. One set of white ring drawables serves both directions because the tint is applied per frame.

- **Nothing here can fire on its own.** Frames are pushed by whichever of *our* processes learned about the pulse, so a received beat cannot ripple on a phone where Dayflower is fully closed — same limitation as the alerts. A send *from the widget* always ripples, because the tap is what starts the background isolate.
- `goAsync()` in each provider's `onReceive` keeps the process alive across the burst; without it Android may kill us mid-sequence and leave the widget frozen on a half-expanded ring. The last frame calls `pending.finish()` — in a `finally`, because leaking a `PendingResult` is an ANR.
- The `beat_pulse_at` marker is claimed (`beat_pulse_shown_<Provider>`) *before* the first frame: every update we push comes straight back as another broadcast, and without the claim each one would start a fresh burst. The key is per-provider so a phone with both the dedicated and the adaptive widget sees both ripple.
- Markers older than 10s are ignored, so a widget rebuilt after a reboot doesn't replay an old pulse.

## Reminders = alarm clocks (Activities → Reminders) — 2026-08-31

Set a nudge for your partner or yourself, and have it **ring like an alarm
clock**. Files: `features/reminders/data/reminder_repository.dart`,
`.../reminder_scheduler.dart`, `.../presentation/screens/reminders_screen.dart`,
`.../presentation/screens/alarm_screen.dart`, plus
`core/services/app_notifications.dart`. Migration **0010** (still unrun — it was
**amended in place**, see below).

### 🔴 The bug this fixed: nothing scheduled could ever have fired

`flutter_local_notifications` ships an AndroidManifest containing **only
permissions** — it declares none of its own receivers. This is the exact same
trap as `home_widget`'s empty manifest (§ Android builds), and it had already
caught us once. Every scheduled notification is delivered by
`ScheduledNotificationReceiver`; without a declaration the AlarmManager
PendingIntent targets a component that does not exist and the broadcast is
dropped **with no error anywhere**. The reminders shipped on 2026-08-29 would
have been silent on a real device, and the web preview cannot show that
because the whole scheduler no-ops off Android/iOS.

`android/app/src/main/AndroidManifest.xml` now declares all three:
`ScheduledNotificationReceiver` (delivers the alarm),
`ScheduledNotificationBootReceiver` (reschedules after a reboot **or an app
update** — hence `MY_PACKAGE_REPLACED` in its intent-filter), and
`ActionBroadcastReceiver` (carries Snooze/Done to the Dart isolate).

⚠️ **Check this after any dependency bump.** Verify with `aapt2 dump xmltree`
on the built APK and grep for `dexterous` — all three must be present.

### What makes it an alarm and not a banner

Four things, and dropping any one turns it back into something you sleep
through:

1. **`AudioAttributesUsage.alarm`** — plays on the *alarm* stream, so it is
   audible at alarm volume with the ringer silenced. This is the one that
   matters most: a notification-stream sound on a phone in do-not-disturb
   makes no noise at all. The channel also sets `bypassDnd`.
2. **A 30-second sound.** Notification sounds play **once** and do not loop,
   so the *file* has to be long enough to wake someone. `res/raw/alarm.wav`
   is generated by **`tools/generate_alarm_wav.py`, which is committed** —
   deliberately unlike `heartbeat.wav`, whose generator was not, so that
   sound can't be tweaked without reverse-engineering it.
3. **`fullScreenIntent`** plus `android:showWhenLocked` / `android:turnScreenOn`
   on MainActivity. Without those two attributes the intent resolves but the
   phone stays dark and locked, so the alarm looks like nothing happened
   while it rings.
4. **`ongoing: true` + `autoCancel: false`** — it cannot be swiped away.
   Snooze and Done are the only exits, which is the entire point.

### Permissions

`SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `RECEIVE_BOOT_COMPLETED`,
`WAKE_LOCK` are declared; `ReminderScheduler.ensureAlarmPermissions()` requests
them and reports each **separately** (`AlarmPermissions`) so the UI can name
the one that is missing. Without `SCHEDULE_EXACT_ALARM`, Android 12+ silently
downgrades `exactAllowWhileIdle` to an inexact alarm that drifts by minutes in
doze — it still rings, just not on time, which is the worst failure mode
because it looks like it works.

⚠️ **`USE_EXACT_ALARM` is deliberately NOT declared.** It is the no-prompt
alternative, but Google Play restricts it to apps whose *core* purpose is an
alarm clock or calendar, and Dayflower would have to argue that at review. Add
it only if the one-time permission prompt proves to be a real problem.

### Channels

**`reminders_alarm_v1`** (rings) and **`reminders_quiet_v1`** (ordinary
notification). The old `reminders_v1` is **abandoned, not reused** — Android
freezes a channel's sound and importance at creation, so a phone that had
already created it would have gone on ringing at notification volume forever.
Nobody ran the old build, but the rule stands: bump the `_v` suffix, never
edit a channel in place.

### Snooze, Done, and the isolate

Both buttons declare `showsUserInterface: false`, so Android routes them to
**`reminderActionBackground`** — a top-level `@pragma('vm:entry-point')`
function running in a fresh isolate that re-initialises dotenv and Supabase,
exactly like the widget's background send. That is what lets you snooze
without the app coming to the foreground.

- 🔴 **The background handler must call `scheduleOne`, never `sync`.** `sync`
  cancels every pending reminder alarm before rescheduling, and that isolate
  has only loaded the one reminder whose button was pressed — so snoozing one
  alarm would have silently unscheduled all the others. This was caught before
  it shipped; don't reintroduce it by "simplifying" the two into one.
- **Snooze moves `remind_at`** rather than adding a `snoozed_until` column:
  one column is the time this thing is next due, and a second would
  immediately raise the question of which wins. The cost is real — snoozing a
  *repeating* reminder shifts the series, so snoozing a 7am daily alarm by 9
  minutes makes it a 7:09 daily alarm. Ticking it off with `markDone` is what
  puts a repeating one back on its original schedule.
- A snoozed alarm is rescheduled with `repeat: none`. Keeping the rule would
  hand `matchDateTimeComponents` a new time-of-day and quietly move the whole
  daily series.

### `AppNotifications` — one owner for `initialize()`

`FlutterLocalNotificationsPlugin()` is a **factory singleton**, so
`initialize()` is global state and whoever calls it last owns the tap
handlers. That was fine while nothing needed handlers, which is why
`PulseAlerts.init()` owned the call. Snooze/Done need them, so the call moved
to `core/services/app_notifications.dart` and `main()` passes both handlers in
before any feature's `init()`. **Each feature still owns its own channel** —
only `initialize()` is shared.

### The alarm screen

`Routes.alarm` (`/alarm/:id`) is **top-level, outside the app shell** — an
alarm is not a place you navigated to, and rendering the bottom nav under it
would offer a third way out. `PopScope(canPop: false)` blocks back for the
same reason.

Reached two ways: the full-screen intent (cold start — the launch payload is
the *only* record of which reminder is ringing, read once in
`_wireAlarmTaps`), and a plain tap while the app is alive (parked in the
`ringingReminderId` ValueNotifier, because the plugin's callback has no
`BuildContext` to navigate with). It renders even when the row is missing —
deleted by the partner, or the list hasn't loaded on a cold start — because
there is still a ringing phone to deal with.

### Per-reminder Ring vs Notify

`alarm boolean not null default true` on the row; the sheet offers **⏰ Ring**
/ **🔔 Notify**. Defaults to ringing because "remind me" almost always means
"make sure I notice", with Notify as the deliberate opt-out so "buy milk"
doesn't have to be a fire drill.

🔴 **Migration 0010 HAD already been run, and this doc claimed it hadn't.**
That mistake nearly cost real data: 0010 opened with `drop table if exists
cascade`, and by the time the alarm work landed the table held the couple's
actual reminders ("ML", "Weekly Cleaning"). Running the amended file would
have deleted them.

0010 is now **idempotent-but-preserving**, like 0007 and 0009: `create table
if not exists`, `add column if not exists`, `drop policy if exists` +
recreate, and a guarded `alter publication` (which throws if the table is
already a member). Safe to run against a fresh project or the live one. Do
not tidy it back into drop-and-recreate.

**Symptom this caused:** every "add a reminder" failed with
`PGRST204 — Could not find the 'alarm' column of 'reminders' in the schema
cache`, surfacing in the app as a generic database error. Confirmed by
probing the live REST API: an insert without `alarm` succeeded, the same
insert with it did not.

⚠️ **Verify migration claims against the live database, never against this
list.** It has now been wrong three times (0009, then 0010 twice). A
`select=*&limit=1` distinguishes the cases: `PGRST205` = no table, `42501` =
table exists and only permissions objected, `PGRST204` on an insert = table
exists but is missing that column.

### Unchanged from the original build

- **`created_by` and `for_user` are separate columns**, and that separation
  *is* the feature. Reminding yourself is the case where they are equal.
- **Both partners see every reminder in the pair** — one you set for them has
  to be visible to you or you can't tell whether you already set it.
- **`sync()` cancels everything it owns and reschedules from scratch** rather
  than diffing; ownership is by payload prefix `dayflower://reminder/`, which
  is what stops it cancelling the heartbeat and nudge notifications.
- **Ticking off a repeating reminder rolls it forward** instead of closing it,
  computed from when it was *due* so ticking it late doesn't drag the
  schedule.
- **Monthly has no `DateTimeComponents` equivalent** — single alarm, rolled
  forward by `markDone`/`sync`. It also clamps: the 31st lands on the 28th in
  February.

### 🔴 Still the honest limitation

**The recipient's app has to open at least once between the reminder being
created and the time it should fire.** There is no push backend, so nothing
can hand the alarm to their phone while the app is closed. Set one for tonight
and they haven't opened Dayflower since yesterday, and it never rings. Once
the alarm *is* on their phone the OS fires it with the app dead — that part is
solid, and it is strictly better than heartbeat alerts, which need a live
stream at the moment they arrive. Closing the gap needs FCM/APNs plus an edge
function.

⚠️ **iOS gets the default sound, not `alarm.wav`** — the file lives in
Android's `res/raw` and would have to be added to the Runner target in Xcode,
the same gap as `heartbeat.wav`. iOS also has no full-screen intent and no
alarm audio stream for local notifications, so `interruptionLevel:
timeSensitive` (which does pierce Focus modes) is as close as a third-party
app gets. A real iOS alarm is the system Clock app.

## Finances v2 — 2026-08-31

Rebuilt from two tables into a full personal-finance model. **`0016_finance_v2.sql` EXTENDS 0011 in place — it drops nothing.** Applied 2026-08-31.

⚠️ A first draft opened with `drop table ... cascade`, trusting this file's claim that 0011 had never been run. It had — the live DB held 2 accounts and 11 entries. **Check `information_schema` before trusting these notes.**

**Nine tables:** `finance_settings`, `finance_rates`, `finance_accounts`, `finance_budgets`, `finance_entries`, `finance_recurring`, `finance_holdings`, `finance_plans`, `finance_plan_items`.

Decisions worth not re-litigating:

- **Balances stay derived, never stored.**
- **Liabilities are stored positive and subtracted.** "Owe 5,000" is 5000, so no form has to explain why paying a debt makes the number go up. An expense charged to a liability *increases* it — without that a card would pay itself off every time it was used.
- **Privacy reversed from 0011.** Solo accounts are private by default; the owner opts in per account. Entries inherit that from the account they touch, so there is one switch, not two that can disagree. Shared accounts are forced visible by a **trigger**, not a CHECK — the column defaults to false, so a CHECK would reject every shared insert that omitted the flag.
- **FX goes through USD as the anchor.** `FxTable.convert` returns **null** for an unknown currency rather than assuming 1:1, and the summary collects those into `unconvertible` so the UI names what it left out.
- **`fx_rate` is snapshotted per entry** — otherwise editing today's rate rewrites what last year's charts say you spent.
- **Write policies are split per-command, never `for all`.** A WITH CHECK demanding `created_by = auth.uid()` also applies to UPDATE, which would stop one partner editing a *shared* row the other created.

**Built:** schema, data layer, accounts + entries UI (asset/liability, per-account currency, subkinds, fund targets, credit limits, privacy switch, charge-to-budget), **budgets UI** (overall first, then category caps; bars turn red and report the overshoot; the "Overall" option hides once one exists, because a partial unique index enforces one per owner and a hidden option beats a 23505 — verified live: insert 201, duplicate **409**), and the **currency & rates sheet** (tap the pill on the net worth card). Rates from `open.er-api.com` — 166 currencies, no API key, so nothing secret ships in the APK. Typing a rate **pins** it and the live refresh skips pinned rows.

**Recurring landed 2026-08-31.** Rules that post ordinary entries — rent, salary, subscriptions, loan payments — so nothing downstream knows a rule existed. Sits above Budgets because a due subscription is the thing most likely to need acting on. `auto_post` true writes it on next Finance open; false surfaces it as due with a Post now button (better when the amount varies). Entries are dated **the day they were due**, not today: a subscription that billed on the 1st belongs in the 1st's numbers even if the app wasn't opened until the 9th, and that is also what makes catching up several missed periods produce a correct month. Catch-up is capped at 60 iterations so a corrupt date can't spin forever, and auto-post runs once per visit behind a flag — posting writes entries, the stream reports the change, the screen rebuilds, and without the flag that is a loop that keeps posting. Auto-post failures are deliberately silent: it runs unprompted, and a red bar about a subscription the user wasn't thinking about is worse than the rule staying visibly due.

Also added `finance_recurring_budget_only_on_expense` — finance_entries had that check but recurring didn't, so the rule lived only in the client. Verified live: income+budget → 400, expense+budget → 201.

**Investment holdings landed 2026-09-01.** Quantity × price — gold in grams, crypto in coins, shares as shares — with `unit_cost` as the cost basis, which is the only thing that makes gain/loss possible; without it an investment can say what it is worth today but never whether that is good news. **An investment account with positions is valued at those positions, not at its cash balance.** Using the balance would report a portfolio at its funding amount forever, and adding the two would count the same money twice. A position with no cost basis shows no percentage rather than -100%. Prices are manual — nothing fetches a crypto or metal price.

**`test/finance_summary_test.dart` covers the derivation** (11 tests, all passing): card expenses increasing debt, transfers paying down a liability, transfers being neither income nor spending, mark-to-market, missing cost basis, FX conversion, and an unconvertible account being excluded *and named*. These are the rules that look fine until real money is in them.

**Not yet built:** the salary→% plan, and Insights charts.

**Live data note:** entries were cleared 2026-08-31 at the user's request (backup in `backups/`). Both accounts (`E&`, `Dragonfi`, AED) are owned by **twolip.test.partner** because the debug build auto-logs-in as them, while entries had been created as **jccudiamat55**. Signed in as the primary user, Finance shows no accounts — they are the partner's and now private. Not a bug, but it looks like one.

## Finances (Activities → Finances) — 2026-08-29

A shared/solo money tracker. Files: `features/finance/data/finance_repository.dart`, `.../presentation/screens/finance_screen.dart`. Migration **0011** (unrun).

- **The model is: accounts hold money, entries move it.** An account is a bank, cash, e-wallet, savings pot or investment. An entry is income, an expense, or a transfer between two accounts.
- 🔴 **There is deliberately no `investment` or `saving` entry kind.** Investing and saving are *transfers* into an account whose `kind` says what it is — that is where the meaning lives. Adding them as entry kinds would let the ledger and the balances disagree about the same peso. Do not "complete" the enum.
- **Balances are always derived, never stored**: opening balance plus every entry touching the account (`FinanceSummary.from`). Deleting a mistyped entry corrects every number it touched, for free.
- **Transfers are excluded from income and expenses on purpose.** Moving your own money is not spending; counting it would make a payday-to-savings sweep look like a month where you earned and spent the same amount twice.
- **Three scopes: Ours · Mine · theirs.** `owner_id` null = the couple's, a user id = that partner's. **Their scope is read-only** — RLS lets you see their solo rows (couples app, not a bank) but only they can write, so the FAB and every Add control disappear in that view rather than offering a save that returns 42501.
- **Single-currency by design.** `financeCurrencyProvider` takes the first account's currency, and the picker only appears while there are no accounts. Mixing currencies in one total produces a number that means nothing, so this is a constraint, not an oversight. The `currency` column stays per-account so multi-currency remains possible later.
- Deleting an account is `on delete set null` for entries, not cascade — the month's spending history outlives the bank you closed.

## Chapters (Activities → Chapters) — 2026-08-29

A year is twelve chapters, one per month. Files: `features/chapters/data/chapter_repository.dart`, `.../presentation/screens/chapters_screen.dart`, `.../chapter_detail_screen.dart`. Migration **0012** (unrun). This is what the old "Goals" SOON tile became — it was removed from `_soon` rather than left as a duplicate.

- **Three tables because a chapter has three sittings, in this order:** `monthly_goals` (written at the start of the month), `chapter_moments` (logged as they happen), `monthly_chapters` (the review, written at the end). Moments exist so the review is not written from memory a month later.
- **Everything is keyed by (year, month), never a date range.** A chapter *is* a calendar month, so storing bounds would only create the chance for them to disagree with the label. `ChapterKey` carries the arithmetic.
- **The review is an upsert on the `(pair_id, year, month)` unique index**, not read-then-branch — both partners can be editing the same chapter, and the index is what makes the second save an update instead of a duplicate row. The `for update` policy is what actually lets that second save through.
- **Goals follow the finance ownership rule** (null = ours, a user id = mine); moments and the review are always the couple's. Editing a goal never moves it between owners — that would silently hand your partner's goal to yourself.
- **`unwrittenChapterProvider` is the nudge** on both the hub tile and the Chapters screen: last month ended and its review is unwritten. It only fires for a month the couple actually *lived in the app* (there are goals or moments in it), so a couple who joined this month is not asked to review the month before.
- **Closing a chapter is a milestone, not a lock** — a closed chapter still edits, and reopening just clears `closed_at`. Rating 0 in the sheet means "not rated" and is stored as null; the check constraint only allows 1–5.
- Routes use path params (`/app/activities/chapters/2026/8`) and fall back to the current month on an unparseable URL rather than crashing.

## Shared sheet primitives — 2026-08-29

`core/widgets/app_bottom_sheet.dart` holds `AppBottomSheet`, `AppFieldLabel`, `AppSheetField` and `AppSegmented`. Lifted out when Reminders, Finance and Chapters all needed the same editing sheet — four private copies is how four bottom sheets start looking different from each other.

- ⚠️ **`events_screen.dart` still has its own private `_BottomSheet` / `_FieldLabel`.** It was left alone (mock data, due a rework), so there are now two implementations. Delete the private pair when that screen is next touched.
- `AppSheetField` fills with the *canvas* colour, the reverse of the global `InputDecorationTheme` (white on canvas), because inside a white sheet the inset has to be the darker one. `serif: true` is for the one prose field per sheet — the review — and design.md keeps Lora rare.
- `core/widgets/app_error_notice.dart` exists because a screen built on `valueOrNull ?? const []` renders a failed load as an *empty state*: "you have no accounts" and "this did not load" looked identical and meant opposite things. Finance and both Chapters screens show it above their content whenever a stream errors. Reminders uses a full-screen error state instead, since it has nothing else to draw.

## Activity feed (2026-09-03)

A shared timeline on Home: the three most recent things either of you did to the shared world, with **View all** through to the rest. Tapping a card opens the thing itself — the reminder, that month's chapter, the camera, the thread, Finances.

**Not the notification list, and the distinction is the whole design.** A heart, a photo or a message is a *nudge*: it interrupts once and is then done with, and it already has a table, a thread and a widget. An activity is something worth reading hours later, it points somewhere, and it reads the same to both people. That is why `activities` is its own table rather than a flag on `flower_messages`.

**Rows come from database triggers, never from Dart.** Nine call sites that each have to remember would mean an activity silently missing the first time somebody adds a tenth, and nothing at all for a write made from the SQL editor or an older build. Migration **0019 is applied** — verified live: 2 tables, 12 triggers, `activities` in the realtime publication, 1 select policy + 3 on `activity_reads`. A reminder insert was round-tripped end to end and the row survived its source being deleted.

- ⚠️ **An activity must never break the feature it describes.** An AFTER trigger that raises rolls back the statement that fired it, so a bug in the feed would surface as "I can't save a reminder any more". Every trigger routes through `log_activity`, whose body ends in `exception when others then null`. Do not "tidy" that away.
- ⚠️ **OLD does not exist during an INSERT.** `tg_activity_chapter` and `tg_activity_reunion` branch on `tg_op` with nested `if`s rather than one boolean, because PL/pgSQL evaluates a condition as a single SQL expression and will not reliably short-circuit past `old.x` — the failure is `record 'old' is not assigned yet`, and it would take the parent insert with it.
- ⚠️ **The privacy line.** `finance_accounts.visible_to_partner` exists so a personal wallet stays personal and 0016's RLS honours it — but an activity row is a second, plainer copy of the account name and is *not* filtered by that policy. `tg_activity_account` logs shared and opted-in accounts only; budgets, which carry no visibility flag at all, are logged only when `owner_id is null`. **Spending is never logged**, on purpose: a feed full of "spent 40 on groceries" buries the three things a day worth a tap.
- **Clients get `select` only.** No insert/update/delete policy on `activities` at all — rows arrive through a `security definer` function, so nothing signed in can fabricate an entry or delete one from the other person's timeline.
- **A 30-minute dedupe, keyed on `(pair_id, kind, subject_id)`**, lives inside `log_activity`. The chapter review editor is a plain upsert and the reunion is one row nudged whenever a date moves; without it the feed would fill with "wrote the September review" once per sentence typed. Two different reminders a minute apart are different subjects, so both still land.
- **The route is resolved in Dart, not stored on the row.** A route in the database is frozen at write time: rename a path and every activity ever logged deep-links to nothing, with no way to notice. The row keeps the *subject*; `Activity.route` keeps the map. Unknown kind → not tappable, which is what an older app reading a newer database looks like.
- **`kind` carries no CHECK constraint**, so a new kind can ship ahead of the app; `ActivityKind.fromId` answers an unrecognised one with `unknown` rather than throwing. `test/activity_test.dart` asserts both halves of that contract — every kind 0019 emits has a Dart case, and every Dart case is reachable from the database.
- **Read state is a watermark** (`activity_reads`, one row per person), not a flag per row. Two readers, always read newest-first. Your own actions never count toward the badge — you were there.
- **Nothing is backfilled.** A backfill would date every reminder ever set correctly and land the lot in the timeline at once: a wall of stale news on the first launch. The feed starts empty and fills as you use the app.
- The full-list screen holds the watermark **as it was on entry**, so the "new" dots do not clear under the reader's eyes on the first frame.
- Route is `/app/home/activity` — a sub-route of Home, not of the Activities hub, so the Home tab stays lit inside it. `AppBottomNav` now matches Home with `startsWith` for that reason.

🔴 **"Your partner set an event" is not in the feed, because events are not real yet.** `events_screen.dart` builds its list in `initState` and keeps it in `setState` — there is no events table and nothing is persisted, so there is nothing to trigger on. The only calendar thing that *is* real is `reunions` (one row per pair), logged as `reunion_set`. Giving events a table is what unblocks the rest.

## Notifications — how far they actually reach (2026-09-03)

Messages, day photos and activity now raise a notification on the receiving phone. Heartbeats already had `PulseAlerts` and are untouched — their own sound, waveform and cadence throttle.

⚠️ **These are local notifications, not push, and the difference matters.** Each one is raised by the receiving device in reaction to a Supabase realtime event, so it only fires **while that app's process is alive and its websocket is connected**. Backgrounded a few minutes ago and still resident: works. Swiped away, or deep enough into Doze that the socket is gone: nothing arrives, and nothing will until the app is next opened. **Do not describe delivery as guaranteed.** Closing that gap needs FCM — a Firebase project, `google-services.json`, a `device_tokens` table and an edge function on the insert — and none of it is here. ⚠️ Adding `firebase_messaging` *without* `google-services.json` fails the Android build outright, which would take the OTA publisher down with it; the credentials have to land first.

- **The foreground rule.** Nothing notifies while the app is on screen — the screen already says it better. But the "already told them" mark is advanced **either way**, so opening the app also stops it announcing later something you have by then long since read. Advancing and staying quiet is the only combination right in both directions.
- **The mark is persisted** (`SharedPreferences`), because the process dies constantly; without it every cold start would re-announce the whole backlog. On a device that has never seen it, the mark is seeded from current state and nothing fires — a fresh install has no business announcing a conversation read on the old phone.
- **Three new channels**, because Android freezes importance and sound at creation and neither can be changed in code afterwards: `partner_messages_v1` (high — a heads-up banner), `partner_activity_v1` (default — sits in the shade), `app_updates_v1` (low — an update is never urgent). Bump the `_v` suffix to change any of them; renaming silently resets the user's own per-channel settings.
- **One notification id per kind, reused**, so a chatty five minutes rewrites one line instead of stacking fifteen — same reasoning as the heartbeat throttle.
- **Taps route through one shared payload**, `dayflower://open?route=<path>`. The plugin allows exactly one foreground handler for the whole process, so `handleNotificationTap` now dispatches: reminder alarms first (they have Snooze/Done and a background isolate), then everything else, which only ever wants a destination. A widget-only day photo routes to **Home**, not the thread — it is not in the thread, and sending someone there would be sending them to an empty room.
- **Permission is asked for once the pair is linked**, not at first launch. Android shows that prompt exactly once and never again; spending it on the welcome screen, before the app has shown what it would notify about, is spending it on a "no".
- ⚠️ **The update notification is narrower than it looks, and that is where the updater's design ends.** The manifest is only fetched on launch and on resume, so nearly every check finishes with the app on screen — where the sheet is the better answer. `UpdateAlerts` exists for the one case the sheet cannot cover: the check was still in flight when the phone was put down. A phone that has not opened Dayflower for a week will not learn about a build this way, because nothing is running to ask. Same missing piece as above.

## Running SQL from the desktop — 2026-08-31

`dart run tool/run_sql.dart <file.sql>` posts to the Supabase Management API — the same endpoint the dashboard SQL editor uses. `-c "select 1;"` runs a one-liner and prints rows, so it doubles as a way to check live state.

- Needs a **personal access token** (`sbp_…`) in `.publish.env` as `SUPABASE_ACCESS_TOKEN`. The `service_role` key does **not** work and never will — it speaks to PostgREST and Storage and has no DDL path; the API answers it with `JWT could not be decoded`. A PAT controls *every project in the account*, so delete it once migrations are done.
- ⚠️ **Pass a file, not multi-line `-c`.** Windows' `dart.bat` wrapper mangles multi-line arguments — it truncated a query to 55 chars and spliced in `& C:/src/flutter/bin/internal/exit_with_errorlevel.bat`, which Postgres reported as a syntax error near `&`.
- `backups/` holds JSON dumps taken before destructive work (`finance_pre_0015.json`, `finance_entries_before_clear.json`). Real financial rows; not gitignored.

## Supabase (project `kjvucdxqgzybhxdqszgi`)

- Claude has only the **anon key** (`.env`). All DDL runs via the user pasting `supabase/migrations/*.sql` into the dashboard SQL editor. Write migrations as **single self-contained scripts** (drop-and-recreate for dev tables) — separate executions have caused ordering failures.
- **Migration numbers were deduplicated 2026-08-31.** Two pairs shared a number — `0014_app_builds`/`0014_photo_strips` and `0015_avatars`/`0015_finance_v2` — which is exactly how a migration goes missing: two files claim one slot, one gets run, the other looks done. Renumbered in date order to `0014_app_builds`, `0015_photo_strips`, `0016_finance_v2`, `0017_avatars`, and every code comment referencing the old numbers was updated. All four were already applied; the renumber is bookkeeping, not a re-run.
- **Migrations — ALL APPLIED as of 2026-08-31.** 0001–0017 are live. ⚠️ The previous version of this line was wrong in a way that nearly caused data loss: it claimed 0010, 0011 and 0012 were unrun when all three had been applied and `finance_accounts`/`finance_entries` held real rows. A first draft of 0015 opened with `drop table ... cascade` on the strength of that note. **Check `information_schema` before trusting this file** — `dart run tool/run_sql.dart -c "select ..."` takes seconds. 0008 was the only genuinely outstanding one and was applied 2026-08-31.
- ⚠️ **This list has been wrong before.** It claimed 0009 was unrun for a whole session while the chat was in fact working against it. Confirm against the live schema rather than trusting this line: a `select=*&limit=1` on the table shows which columns really exist, and an insert aimed at a non-existent `pair_id` is a safe probe — it can never commit, and the error code tells you what fired first (`23502` = a NOT NULL still in place, `42501` = the column was fine and only RLS objected).
- **0009 joins 0007 as idempotent-but-preserving**, for the same reason: `flower_messages` holds the couple's real exchange history. It alters in place and is safe to re-run — do NOT rewrite it into the usual drop-and-recreate.
- **Every realtime table needs** `alter publication supabase_realtime add table public.<t>;` in its migration or streams silently receive nothing.
- **Dashboard config done by user:** Resend custom SMTP (`onboarding@resend.dev`, port 465 — no verified domain yet, so email only delivers to jccudiamat55@gmail.com; partner login blocked until a domain is added); **both** the Magic Link and Reset Password email templates edited to include `{{ .Token }}` (the app's OTP/recovery UI needs the 6-digit code, not the default link); email confirmation disabled (enables API-created test accounts).

## Accounts & test data

- **User:** jccudiamat55@gmail.com — profile "jessie" / nickname "hubby", id `3f41e37d-0880-4371-8e07-b4ec6bc9b5f3`.
- **Test partner:** twolip.test.partner@gmail.com / password `<see DEV_PASSWORD in .env>` (the literal string — predates the Dayflower rebrand, do not "fix" it), profile "Sheena", id `ee6681c4-7711-4795-80d7-8aa664a65ed0`.
- **Pair:** id `0f3f7069-bdca-47f5-900b-f3651401212d`, invite code `BMXQNW`, linked.
- **`.gitignore` was broken until 2026-07-26**: the `.env` line had been appended as UTF-16 (`2e 00 65 00 6e 00 76 00`), so it matched nothing and secrets were NOT ignored. Rewritten as clean ASCII. If you ever append to it from PowerShell, use `-Encoding utf8`.
- **Two-sided testing pattern:** get a token with `POST /auth/v1/token?grant_type=password` as the test partner, then hit `/rest/v1/...` with curl to simulate the partner while the user watches the preview. (Windows shell mangles emoji in curl JSON bodies — avoid emoji in test payloads.)

## Architecture decisions

- Feature-first layout: `lib/features/<f>/{data,domain,presentation}`. Models used by several features live in `lib/core/models/`.
- Riverpod: repositories as `Provider`, live data as `StreamProvider.autoDispose` chained off `currentPairProvider`; derived values (counts, today's flower) as plain `Provider.autoDispose`.
- Router gating chain in `app_router.dart`: auth → profile exists → pair linked → app shell. No bypass flag anymore.
- Business rules live in the DB where possible (one-flower-per-UTC-day unique index; recipient-only seen updates via RLS).
- **4-tab bottom nav (2026-07-26): Home · Flowers · Events · Activities.** Settings is a sub-route off Home's gear icon. Route constants renamed to match (`Routes.home/flowers/events/activities`); `nest`, `tulip`, `sendFlower`, `booth`, `dates`, `us` are gone. Feature *folders* keep their old names (`features/tulip`, `features/dates`, `features/booth`) — Activities→`BoothScreen`. **Events→`EventsScreen`** as of 2026-08-01 (was `DatesScreen`; the folder is still `features/dates`). The dead `us` route was removed; its files remain unreferenced.
- ~~**Flowers tab is send-first**~~ — superseded 2026-08-01: the tab is a chat. See § Flowers tab = the conversation.
- Design: all tokens in `lib/core/theme/` — never hardcode hex/fonts in feature code. Read design.md before building UI.
- **Copy:** the Nest card is labelled **"TODAY'S FLOWER"** (renamed from "TODAY'S DAYFLOWER" on 2026-07-26). The Android widget mirrors it via `@string/widget_label` in `res/values/strings.xml` — Android resource strings need apostrophes escaped as `\'`, and using a string resource avoids inlining that in a layout we can't compile-check here.

## Deferred / known issues

- `features/booth` is still on its own local palette + mock data, now reachable at `/app/activities/booth` (see § Activities tab = a hub) — restyling it onto design.md tokens is the obvious next cleanup. `features/us` is unreachable dead code; delete when convenient. `features/dates` was rebuilt 2026-08-01 (see § Events tab = one page), though still mock data.
- **Delete-account is intentionally absent** from Settings: removing an `auth.users` row needs the service-role key, so it requires a Supabase Edge Function / RPC. Build that before launch (store policies require it).
- **Notification toggles intentionally absent** from Settings: no notification system is wired yet (`flutter_local_notifications` is in pubspec but unused). Don't add toggles until they actually do something.
- `AuthNotifier` still navigates by router-redirect side effects; login screen no longer manually navigates (ref.listen removed).
- Emoji `??` in one DB note — from a Windows curl test, not an app bug.
- Realtime pair-join auto-advance (pairing screen → nest) never re-verified after adding the publication — exercise it if pairing is ever re-tested.
- Feature 6 (home widget) can't be tested in web preview — needs a real Android/iOS build.

## Landing site (website/)

- Next.js 16 (App Router, Tailwind v4) landing + waitlist site in `website/`. Run: `npm run dev` inside `website/` (or preview config "next site", port 3001).
- **Rebuilt 2026-07-28 to mirror [overview.md](overview.md) v3.0 end to end.** 12 sections: hero (Nest mock) · concept + 5 UX principles · flower language · 6 core features · 7-screen app tour · 10 booth templates · day-in-the-life + onboarding · post-MVP nice-to-haves · pricing · 31-item future-builds roadmap in 9 groups · competitive table · final CTA.
- **All copy lives in [app/lib/content.ts](website/app/lib/content.ts)** — re-sync that one file when overview.md changes; `page.tsx` is just layout. Shared primitives (SectionLabel, TwoToneHeading, Card, Tag, TickList) in `app/components/ui.tsx`.
- The flower list mirrors `lib/features/tulip/domain/flower_catalog.dart` (7 varieties + meanings) — keep them in sync rather than inventing site-only flowers.
- Design follows design.md v3 tokens: Quicksand + Lora italic (notes only), one pink→purple gradient for primary, midnight-plum darks, pills/18-radius cards, flat. **overview.md's own § Design Philosophy is stale** (still lists the pre-v3 rose/cream palette and Georgia) — design.md wins.
- `next lint --dir` was removed in Next 16; lint with `npx eslint app`. Bundled docs live in `website/node_modules/next/dist/docs/` (per website/AGENTS.md, read before writing Next code).
- Waitlist: form → `/api/waitlist` route → Supabase REST insert into `public.waitlist` using anon key from `website/.env.local`. Duplicate emails (409) are treated as success. ✅ **Migration 0007 run + verified end-to-end 2026-07-28**: UI submit → row persisted (proved by forcing a `23505` conflict on re-insert, since reads are blocked), case-insensitive dedupe works, invalid address → 400, success card renders.
- **You cannot read the signups through the API** — by design. `select` returns **401** (no grant, no select policy). That 401 is also how you tell the table exists; a missing table gives 404/PGRST205 instead. Read the list in the dashboard or with the service role.
- Test rows left in the table from verification: `verify-1785184417575@example.com`, `ui-signup-test@example.com` — delete via the dashboard before launch.
- `0007_waitlist.sql` is the **one migration that must never be re-run destructively** — unlike the dev tables it holds real visitor signups, so it is written idempotent-but-preserving (`create table if not exists`, `drop policy if exists` + recreate) instead of the usual drop-and-recreate. Don't "fix" it to match the other migrations.
- It also `revoke`s the grants that 0002's `alter default privileges` hands `authenticated` on every new table, leaving only INSERT. RLS already blocks reads (no select policy), so this is belt-and-braces against a future permissive policy exposing the email list.
- The route returns **503** (friendly "not available right now") for anything that means *the backend isn't reachable or set up* — missing env vars, DNS/timeout, or a 404 from the table not existing — and 502 only for genuine unexpected rejections. `fetch` is wrapped in try/catch with a 10s `AbortSignal.timeout`; without that an unreachable Supabase threw an unhandled 500.

## Next steps

🔴 **Run `0014_app_builds.sql`**, then publish once (`dart run tool/publish_update.dart -n "first build"`) and install that APK by hand — that is the last manual sideload. Everything after it arrives in-app. Note the current release APK is signed with the *debug* key; if a real keystore is coming, switch to it before this first build or the switch costs another manual reinstall.

🔴 **Run `0010_reminders.sql`, `0011_finance.sql` and `0012_chapters.sql` too.** Reminders, Finances and Chapters are fully built and compile clean, and all three render — but every table they read is missing, so each screen currently shows its load error. Nothing about them can be judged until the SQL runs. `0008_pair_disconnect.sql` is still outstanding too.

Then exercise them, ideally two-sided with the test partner (§ Accounts & test data):

- **Reminders:** set one for the partner and confirm it appears in their list; tick a repeating one and confirm it rolls forward rather than closing; check the OS notification actually fires — that needs a real phone, the web preview no-ops every scheduler call.
- **Finances:** create a shared account and a solo one, log income / an expense / a transfer, and confirm the balances, the month tiles and net worth all move together. Then switch to the partner scope and confirm every Add control is gone.
- **Chapters:** add goals for this month from both sides, log a moment, write a review and close the chapter — the review save is an upsert, so the interesting case is *both partners saving the same chapter*.

The older list, unchanged:

0. **Run `0009_flower_chat.sql`, then `0008_pair_disconnect.sql`.** Until 0009 runs, the Flowers tab cannot send anything: inserts with a null `flower_type` are rejected and `to_widget` doesn't exist. 0008 is what Settings' Disconnect button needs.
0b. **Exercise the new chat two-sided** once 0009 is in — text both ways, a flower with the widget tick and one without, read receipts (open the tab, confirm the sender's ✓✓), the date dividers, and the unread badge. Use the token-based partner simulation in § Accounts & test data. None of the chat has been run against real data yet.
1. Exercise the rebuilt Settings screen (profile edits, nickname, timezone, sign out). Login itself is verified.
2. ~~Install a JDK and compile-check the Android widget~~ — done 2026-07-28, APK builds. Next: install it and confirm the widget actually renders, updates on a new flower, and deep-links into the Flowers tab.
3. Build the iOS widget extension on a Mac — [docs/ios-widget-setup.md](docs/ios-widget-setup.md).
4. Blockers before any real launch:
   - `applicationId` / bundle id is still `com.dayflower.app`.
   - Delete-account needs a Supabase Edge Function (service-role key required) — store policies mandate it.
   - Resend needs a verified domain before Sheena's email can receive anything.
   - Legal pages at `/terms` + `/privacy` are preliminary drafts with a placeholder contact.
5. Optional cleanup: delete the dead `features/booth`, `features/dates`, `features/us` screens (unreachable, still on the old design, and the only source of `flutter analyze` lint noise).
6. ~~Copy inconsistency between app and site hero card~~ — resolved 2026-07-26: `website/app/page.tsx` now says "Today's Flower" too, matching the Nest card and the Android widget. Keep the three in sync if the label changes again.
