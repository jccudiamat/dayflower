# iOS — Today's Tulip widget setup

> **Status: not implemented.** The Dart and Android sides of Feature 6 are done.
> The iOS half requires creating a Widget Extension target inside
> `ios/Runner.xcodeproj`, which needs Xcode on macOS — it cannot be produced
> from the Windows dev machine, and hand-editing `project.pbxproj` would be
> unverifiable guesswork. These are the steps for whoever has a Mac.

The Dart side is already platform-agnostic: `TodaysTulipWidget.push()` writes
the same keys on both platforms and calls `updateWidget(iOSName: ...)`, so no
Dart changes are needed once the extension exists.

## Contract the extension must honour

| Thing | Value | Defined in |
|---|---|---|
| App Group | `group.com.dayflower.app` | `TodaysTulipWidget.appGroupId` |
| Widget kind | `TodaysTulipWidget` | `TodaysTulipWidget.iOSWidgetKind` |
| Deep link | `dayflower://tulip` | `TodaysTulipWidget.deepLink` |
| Keys | `tulip_state`, `tulip_emoji`, `tulip_title`, `tulip_body` | `widget_sync.dart` |

`tulip_state` is one of `received` · `sent` · `empty`.

## Steps

1. **Xcode → File → New → Target → Widget Extension.** Name it
   `TodaysTulipWidget`. Uncheck "Include Live Activity" and
   "Include Configuration Intent" (this widget takes no config).
2. **Add the App Group** to *both* the `Runner` target and the new
   `TodaysTulipWidget` target: Signing & Capabilities → + App Groups →
   `group.com.dayflower.app`. Both must have it or the extension reads an
   empty store.
3. **Add `home_widget` to the extension** so it can read the shared store —
   either via the package's `HomeWidgetPlugin` pod or by reading
   `UserDefaults(suiteName: "group.com.dayflower.app")` directly (simpler,
   no dependency).
4. **Implement the view** — read the four keys and render them against the
   midnight-plum background (`#171027` → `#120C1F`, 24pt corner radius) to
   match `android/app/src/main/res/layout/todays_tulip_widget.xml`:

   ```swift
   let store = UserDefaults(suiteName: "group.com.dayflower.app")
   let emoji = store?.string(forKey: "tulip_emoji") ?? "🌷"
   let title = store?.string(forKey: "tulip_title") ?? "No flower yet today"
   let body  = store?.string(forKey: "tulip_body")  ?? "Tap to send yours first."
   ```

5. **Wire the tap** with `.widgetURL(URL(string: "dayflower://tulip"))`.
6. **Register the URL scheme** on the Runner target: Info → URL Types → add
   scheme `dayflower`. Android's equivalent is already in `AndroidManifest.xml`.

Once the target exists, `HomeWidget.initiallyLaunchedFromHomeWidget()` and
`HomeWidget.widgetClicked` in `lib/app.dart` handle routing to the Tulip tab
with no further changes.

## Before shipping either platform

The bundle id / applicationId is still the Flutter placeholder
`com.dayflower.app`. Changing it means updating, in lockstep:
`android/app/build.gradle.kts`, the Kotlin package path, the App Group id,
and the `androidProvider` / `appGroupId` constants in `widget_sync.dart`.
