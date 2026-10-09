# Next Up for iOS: design

Date: 2026-10-09
Status: approved in brainstorming
Model: `~/workspace/next-game` (spec `docs/superpowers/specs/2026-10-08-next-game-ios-design.md`, setup `docs/ios-setup.md`). Next Game reached TestFlight on 2026-10-09 with this exact setup; this design reuses it and only spells out what differs.

## Purpose

Bring Next Up to iPhone: the next campground check-in on the Home Screen and Lock Screen, with feeds managed in an iPhone app, distributed through TestFlight. The macOS app and its Homebrew release keep working exactly as today.

Success: a TestFlight build installs on Andrew's iPhone, he adds his reservation feeds in the app, adds a Home Screen and a Lock Screen widget, and they show the next stay without opening the app again.

## Decisions

| Question | Decision |
|---|---|
| Distribution | TestFlight via Fastlane `ios beta`, GitHub-hosted runner, manual `testflight.yml`. Homebrew Mac release unchanged. |
| Feeds across devices | Separate per device. No iCloud sync (it would need a provisioning profile on the Developer ID Mac build). |
| Widget | Same "next stay across enabled feeds" widget, no per-widget configuration. Home Screen small and medium, Lock Screen rectangular and inline. |
| iOS app | One screen: Upcoming stays and Feeds (add, edit, enable, delete), pull to refresh, status line. |
| Who fetches | Unchanged rule on both platforms: the widget fetches when the snapshot is older than the refresh interval (default 60 minutes), now with a 15 minute floor. The iOS app refreshes when opened and from a best-effort background task. |
| Devices | iPhone only, iOS 18.0+. |

## Out of scope

iCloud sync, iPad, App Store listing, Live Activities, per-widget feed selection, notifications, a settings screen on iOS.

## Project and build (as Next Game)

- XcodeGen: `project.yml` source of truth, generated `NextUp.xcodeproj` gitignored, `Scripts/generate.sh`, `mise.toml` pins xcodegen 2.46.0, Fastlane `before_all` regenerates.
- Targets:

| Target | Platform | Sources |
|---|---|---|
| `NextUp` | macOS 15.0 | `NextUp/`, `Shared/` |
| `NextUpWidgetExtension` | macOS 15.0 | `NextUpWidget/`, `WidgetShared/`, `Shared/` |
| `NextUpiOS` | iOS 18.0 | `NextUpiOS/`, `Shared/` |
| `NextUpiOSWidgetExtension` | iOS 18.0 | `NextUpiOSWidget/`, `WidgetShared/`, `Shared/` |
| `NextUpTests` | macOS 15.0 | `NextUpTests/`, `Shared/` (host-less) |

- Migration gate: tests pass and a signed macOS Release build matches `/Applications/NextUp.app` (Homebrew 1.0.1) in bundle IDs, App Group entitlement, `LSUIElement`, display name, category (`public.app-category.travel`), and the widget's `NSExtension`, ignoring version keys.
- Environments (`Config/Prod.xcconfig` for Release, `Config/Dev.xcconfig` for Debug):

| | prod | dev |
|---|---|---|
| `NEXTUP_IOS_BUNDLE_ID` | `biz.fitz.NextUp` | `biz.fitz.NextUp.dev` |
| widget | `$(NEXTUP_IOS_BUNDLE_ID).Widget` | same rule |
| `NEXTUP_APP_GROUP` | `group.biz.fitz.NextUp` | `group.biz.fitz.NextUp.dev` |
| `NEXTUP_DISPLAY_NAME` | `Next Up` | `Next Up Dev` |

macOS keeps `biz.fitz.NextUp`, `biz.fitz.NextUp.Widget` and `$(TeamIdentifierPrefix)biz.fitz.NextUp`.
- Fastlane `platform :ios`: `bootstrap` (in-process `produce` for the App IDs first so the Apple ID login happens where it can prompt, then `produce group`, `enable_services`, `associate_group`), `appstore_record` (`NEXTUP_ASC_NAME`), `certificates`, `setup`, `beta`, and a new `internal_testers` lane that creates an internal TestFlight group with access to all builds (raw API call, because spaceship's `create_beta_group` sends public-link fields Apple rejects for internal groups) and adds `TESTER_EMAIL`.
- GitHub: secrets already exist on `andrewcfitz/next-up` (set for the Mac release); CI gains an iOS simulator build; new manual `testflight.yml`.
- Privacy manifests in both iOS bundles (UserDefaults reasons `1C8F.1`, `CA92.1`). Generated 1024 opaque icon: white `tent` on `#2F5D50`.

## Shared code changes

- `SharedStore.appGroupID`: iOS reads the `NextUpAppGroup` Info.plist key (pure, tested `groupID(infoDictionary:)` rejecting missing, empty, and unexpanded `$(...)` values); macOS keeps the entitlement lookup.
- Feed editing moves into `Shared/FeedEditing.swift`, pure and tested:
  - `CalendarFeed.validatedURL(_ text: String) -> URL?` (the editor's current rule: http, https, webcal, webcals with a host; trims whitespace).
  - `CalendarFeed.edited(name:urlText:from:) -> CalendarFeed?`: builds a new feed or updates an existing one; empty name falls back to the URL host, then "Calendar".
  - `[CalendarFeed]` helpers `upserting(_:)` and `removing(_ ids:)`.
- `Shared/FeedRefresh.swift`: `FeedRefresh.run(feeds:previous:) async -> StaySnapshot` fetches, writes `SharedStore.snapshot`, and calls `WidgetCenter.shared.reloadAllTimelines()`. The Mac `AppModel.refresh()` and the iOS model both use it.
- `Shared/RefreshRule.swift`: `widgetShouldFetch(snapshotAge: TimeInterval?, refreshMinutes: Int, hasEnabledFeeds: Bool) -> Bool`: no enabled feeds means no fetch; no snapshot means fetch; otherwise fetch when age `>= max(15, refreshMinutes) * 60`.
- Lock Screen text in `StayFormatting`, tested:
  - `inline(_ stay: Stay, now:) -> String`: "Pine Hollow · in 3d", "Pine Hollow · Today".
  - `rectangularLines(_ stay: Stay, now:) -> [String]`: [title, "in 3d · Fri Oct 16" (or "Today · Fri Oct 16"), place when present].
  - Countdown inside these uses `Today`, `in Nd` (`1d` reads "in 1d"); line 2 never exceeds 24 characters.

## Widget

- `Entry`, `Provider` and views move to `WidgetShared/`; each extension keeps only its `@main` bundle.
- Families: macOS `.systemSmall`, `.systemMedium`; iOS adds `.accessoryRectangular`, `.accessoryInline` (behind `#if os(iOS)`, unavailable on macOS).
- Provider uses `widgetShouldFetch`.
- Taps: small widget `widgetURL(stay.url)`, medium uses `Link`s, as today. On iOS the system opens the app with the URL; the app forwards http(s) URLs to Safari with `openURL`, matching the Mac `AppDelegate`.

## iOS app

- `IOSAppModel` (`@MainActor @Observable`): `feeds` (loaded from and saved to `SharedStore`), `snapshot`, `isRefreshing`, `hasLoaded`, `add/update/remove/setEnabled`, `refresh()` (via `FeedRefresh`), `becameActive()`, `scheduleBackgroundRefresh()` / `backgroundRefresh()` (`BGAppRefreshTask` id `$(NEXTUP_IOS_BUNDLE_ID).refresh`, earliest begin = refresh interval).
- `ContentView`: `NavigationStack` with a `List`:
  - Upcoming: next stays (title, place, dates, nights, countdown); tapping opens `stay.url` in Safari.
  - Feeds: name, URL, toggle, stay count or last error; swipe to delete; tap to edit; "Add Feed" button.
  - Footer status: "Updated now" / "Updated 5 minutes ago" / error.
  - Empty state (only after first load): how to add a feed, then how to add Home Screen and Lock Screen widgets.
  - `.refreshable` refreshes.
- `FeedFormView`: sheet with Name and URL fields (URL keyboard, no autocapitalization), Save disabled until `validatedURL` passes.
- Scene: `.onChange(of: scenePhase, initial: true)` (refresh on cold launch: the Next Game lesson), `.backgroundTask(.appRefresh(...))`, `.onOpenURL` forwarding to Safari.
- Saving a feed change triggers a refresh, like the Mac.

## Testing

- Existing 20 parser and formatting tests keep passing through the migration.
- New: App Group key parsing, feed editing helpers, `widgetShouldFetch`, Lock Screen formatters.
- CI builds the iOS app for the simulator. Simulator check: add a feed through the UI is not automated; the screen and empty state are screenshotted.

## Risks

- App Store Connect name: "Next Up" is taken; choose with Andrew at `appstore_record`.
- XcodeGen migration changing the Mac build: gated by the plist and entitlement comparison.
- Background fetch of user feeds in the widget: feeds are small; same 20 s timeout as today.
