# Next Up for Apple Watch: design

Date: 2026-10-09
Status: approved in brainstorming
Builds on: `docs/superpowers/specs/2026-10-09-next-up-ios-design.md`. Everything there stays as is; this spec only covers what the watch adds.

## Purpose

Put the countdown to the next campground check-in on the watch face and in the Smart Stack. Feeds stay managed on the iPhone; the watch needs no setup beyond adding a complication.

Success: with the TestFlight build installed, the watch app arrives alongside the iPhone app. Andrew adds a Next Up complication to a face, it shows the same next stay as the iPhone widget within a minute or two of the phone app refreshing, and it keeps counting down with the phone out of range.

## Decisions

| Question | Decision |
|---|---|
| How stays reach the watch | The iPhone app pushes `{feeds, snapshot}` over WatchConnectivity. The watch widget renders that and fetches the feeds itself when the snapshot is stale, using the existing `RefreshRule`. |
| Sync transport | `WCSession.updateApplicationContext` (latest state wins), plus `transferCurrentComplicationUserInfo` when a complication is active so the watch app wakes promptly. No iCloud. |
| Families | `accessoryCircular`, `accessoryCorner`, `accessoryRectangular` (also the Smart Stack card), `accessoryInline`. |
| Watch app | Read-only list of upcoming stays, an "Updated" line, pull to refresh. No feed editing. |
| Platform | watchOS 11.0+, bundled inside the iPhone app (not independently installable), shipped by the existing `ios beta` lane. |

## Out of scope

Editing or toggling feeds on the watch, opening reservation links from the watch, Live Activities, an independently installable watch app, syncing from the iOS widget extension, a Mac or iCloud path.

## Targets

| Target | Platform | Sources |
|---|---|---|
| `NextUpWatch` (single-target watch app, embedded in `NextUpiOS`) | watchOS 11.0 | `NextUpWatch/`, `Shared/` |
| `NextUpWatchWidgetExtension` (embedded in `NextUpWatch`) | watchOS 11.0 | `NextUpWatchWidget/`, `WidgetShared/`, `Shared/` |

- Bundle IDs: `$(NEXTUP_IOS_BUNDLE_ID).watchkitapp` and `$(NEXTUP_IOS_BUNDLE_ID).watchkitapp.Widget`.
- Both use the existing `$(NEXTUP_APP_GROUP)` through entitlements and the `NextUpAppGroup` Info.plist key. App Group containers are per device, so the watch gets its own container under the same ID and `SharedStore` works unchanged (its non-macOS branch already reads Info.plist).
- Watch app Info.plist: `WKApplication = true`, `WKCompanionAppBundleIdentifier = $(NEXTUP_IOS_BUNDLE_ID)`, `WKRunsIndependentlyOfCompanionApp = false`, `NextUpAppGroup`.
- Widget extension Info.plist: `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `NextUpAppGroup`.
- Privacy manifests in both watch bundles (same UserDefaults reasons as iOS). App icon: the iOS 1024 icon, copied.
- New `NextUpWatch` scheme for the simulator build. The `NextUpiOS` scheme builds the watch app through the dependency.
- The built iOS app must contain `Watch/NextUpWatch.app`, and that must contain `PlugIns/NextUpWatchWidgetExtension.appex`. Checked after the first build.

## Shared code

### `Shared/WatchPayload.swift` (pure, tested on macOS)

```swift
struct WatchPayload: Codable, Sendable {
    var feeds: [CalendarFeed]
    var snapshot: StaySnapshot?
}
```

- `static let key = "payload"`: the single key in the context and user-info dictionaries. The value is JSON `Data` (WatchConnectivity dictionaries only carry property-list types).
- `func dictionary() -> [String: Any]` and `init?(dictionary: [String: Any])`. A missing key or undecodable data gives nil.
- `static func newer(_ incoming: StaySnapshot?, than current: StaySnapshot?) -> StaySnapshot?`: returns whichever has the later `fetchedAt`. A nil on one side returns the other. A tie keeps `current`.
- Applying a payload on the watch: feeds are replaced unconditionally (the phone owns them); the snapshot becomes `newer(incoming.snapshot, than: SharedStore.snapshot)`.

### `StayFormatting` additions (tested)

- `circular(_ stay: Stay, now:) -> String`: `"Today"` or the day count as a bare number (`"12"`). Never "Tomorrow"; it doesn't fit.

### Widget

- `NextUpWidget.families` gains a `#if os(watchOS)` branch with the four accessory families. macOS and iOS lists are unchanged.
- `NextUpWidgetView`: the `#if os(iOS)` guard around accessory views becomes `#if os(iOS) || os(watchOS)`. On watchOS the body always takes the accessory path (no system families there).
- `AccessoryView` handles the two new families:
  - Circular: `tent` symbol above `circular(...)` in a bold rounded font, `widgetAccentable()` on the symbol, wrapped in `AccessoryWidgetBackground`.
  - Corner: `circular(...)` as the content with `.widgetLabel(inline(...))` curving along the bezel.
  - Empty, with feeds: rectangular and inline "No upcoming stays"; circular and corner show the tent symbol alone.
  - Empty, no feeds ever received: rectangular and inline "Add a feed in Next Up on iPhone"; circular and corner show the tent symbol alone.
- `Provider` is unchanged: it reads `SharedStore`, fetches when `RefreshRule` says so, and emits midnight entries for three days.
- macOS code paths and appearance do not change.

## iPhone side

- `NextUpiOS/PhoneWatchSync.swift`: an `NSObject` `WCSessionDelegate` singleton. Activates the default session at app launch when `WCSession.isSupported()`.
- `send(feeds:snapshot:)`:
  - Skips when the session isn't activated, isn't paired, or `isWatchAppInstalled` is false.
  - Always calls `updateApplicationContext(payload.dictionary())`, ignoring errors (next refresh retries).
  - Also calls `transferCurrentComplicationUserInfo` when `isComplicationEnabled` and `remainingComplicationUserInfoTransfers > 0`.
- `IOSAppModel.refresh()` calls `send` after each completed refresh (including background refreshes). Feed edits already trigger a refresh, so they reach the watch through that path and the snapshot sent is always newer than the edit.
- On activation completing, the phone sends the current `SharedStore` state once, so a freshly installed watch app gets data without waiting for the next refresh.

## Watch side

- `NextUpWatch/WatchReceiver.swift`: the watch's `WCSessionDelegate`, activated from the `App` initializer so a background launch from a complication transfer can deliver.
  - `didReceiveApplicationContext` and `didReceiveUserInfo` both decode a `WatchPayload`, apply it to `SharedStore` as above, then call `WidgetCenter.shared.reloadAllTimelines()` and notify the model.
  - On activation it also applies `session.receivedApplicationContext`, covering context delivered while the app wasn't running.
  - Undecodable payloads are ignored; existing state stays.
- `NextUpWatch/WatchAppModel.swift` (`@MainActor @Observable`): `snapshot`, `hasFeeds`, `isRefreshing`, `now`; `reload()` from `SharedStore`; `refresh()` runs `FeedRefresh.run` with the stored feeds (no-op without enabled feeds).
- `NextUpWatch/WatchContentView.swift`: `List` of upcoming stays (title, `countdown`, `shortDates`, place). Footer "Updated 12 min ago" from `snapshot.fetchedAt` (relative). Empty states: "No upcoming stays." or "Add a feed in Next Up on your iPhone." `.refreshable` calls `refresh()`. Reloads on becoming active.

## Failure handling

- No paired watch or watch app not installed: phone skips sending.
- Watch app not running: context is delivered at next launch; complication transfers wake it while a complication is on the face. When the transfer budget (about 50 a day) is spent, context alone still arrives on next launch.
- Watch offline or fetch fails: the cached snapshot plus midnight entries keep the countdown right for three days. `FeedService` already keeps a failing feed's previous stays.
- Phone feeds deleted: the next refresh pushes empty feeds and a newer snapshot, which replaces the watch's.

## Build and release

- `project.yml`: the two targets, a `NextUpWatch` scheme, `NextUpiOS` depends on `NextUpWatch`, `NextUpWatch` depends on `NextUpWatchWidgetExtension`. Signing settings copy the iOS targets (Automatic for Debug, Manual `match AppStore` profiles for Release). `deploymentTarget` gains `watchOS: "11.0"`.
- Fastlane `ios_ids` returns four IDs: app, widget, watch app, watch widget. `bootstrap`, `certificates`, `setup` and `beta` (match identifiers and `provisioningProfiles`) all use the list. `bootstrap` names: `<name> Watch`, `<name> Watch Widget`.
- Andrew reruns `ios bootstrap` and `ios certificates` locally once before the next TestFlight upload; both are safe to rerun for existing IDs.
- CI adds `xcodebuild build -scheme NextUpWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- `docs/ios-setup.md` gets a short Apple Watch section.

## Testing

- macOS unit tests (host-less, `Shared/` compiled in):
  - `WatchPayloadTests`: dictionary round trip; missing key and garbage data give nil; `newer` picks later `fetchedAt`, handles nil on each side, keeps current on a tie.
  - `LockScreenFormattingTests`: `circular` gives "Today", "1", "12".
- Builds: macOS tests pass, iOS simulator build passes, watchOS simulator build passes, embedded bundle layout verified.
- Manual on device (Andrew): add a feed on the phone, add a complication, confirm it updates; airplane mode the phone, confirm the watch still counts down and the watch app's pull to refresh fetches over Wi-Fi.

## Risks

- XcodeGen embedding of a single-target watch app: verify the bundle layout; if XcodeGen doesn't produce the "Embed Watch Content" phase, add it via `copyFiles` on the dependency.
- Widget network on watchOS is best effort and may be skipped by the system; the phone push is the main path.
- Rerunning `bootstrap` against prod: `enable_services` before `associate_group` order already handles the known group-clearing problem.
