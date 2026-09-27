# Next Up

A small macOS menu bar app and widget for full-time RVers. You subscribe it to one or more
iCal feeds of campground reservations, and it tells you when your **next stay begins**: a
countdown to check-in, plus the campground, location, dates and number of nights.

- **Widget** (small and medium): a countdown to the next check-in. The medium size also lists the stays after it.
- **Menu bar**: a tent icon, optionally followed by the next stay and its countdown. Click it for the full list.
- **Settings window**: add, edit or disable feeds, and pick the refresh interval, the menu bar style and launch at login.

A stay is any **all-day event** in a feed, or a **timed event that runs past midnight** (such
as check-in at 2 PM Friday and check-out at 11 AM Monday). Its check-in is the start date and
its check-out is the end date, so an event from Oct 2 to Oct 5 is three nights. A stay that's
already in progress is ignored: "next" always means the next check-in, today or later.
Same-day timed events are skipped.

## Requirements

- Xcode 16 or later. The project uses synchronized folders, so any file you add to a folder
  is picked up automatically.
- macOS 15 or later.

## Getting started

1. Open `NextUp.xcodeproj`.
2. For both the **NextUp** and **NextUpWidgetExtension** targets, choose your team under
   *Signing & Capabilities*.
3. The app and the widget share data through the App Group
   `$(TeamIdentifierPrefix)com.andrewcfitz.NextUp`, set in `NextUp/NextUp.entitlements` and
   `NextUpWidget/NextUpWidget.entitlements`; keep the two identical. The code reads the group
   from the entitlements at runtime. On macOS, use the Team ID prefix, not `group.`: a
   `group.` identifier only works once it's registered in your provisioning profile. Without
   that, the shared container is unavailable and nothing is saved.
4. Run the **NextUp** scheme. On first launch, with no feeds set up yet, the settings window
   opens. After that the app lives in the menu bar only (`LSUIElement`), with no Dock icon:
   open settings from the tent icon, or by opening the app again while it's running.
5. Add the widget from the desktop or Notification Center: *Edit Widgets → Next Up*.

Run the parser tests with ⌘U. They use Swift Testing.

## Project layout

| Folder | Target(s) | What's in it |
| --- | --- | --- |
| `NextUp/` | App | `NextUpApp` (menu bar extra and settings window), `AppModel`, and the views |
| `NextUpWidget/` | Widget extension | The timeline provider and the small and medium widget views |
| `Shared/` | App, widget, tests | Models, the iCal parser, feed fetching, App Group storage, formatting |
| `NextUpTests/` | Unit tests | Parser and formatting tests |

### How data flows

1. `AppModel` fetches every enabled feed on launch, every *N* minutes (the refresh interval)
   and when the Mac wakes from sleep. It saves the result to the App Group and reloads the
   widget's timelines.
2. The widget reads that cached snapshot. If the snapshot is older than the refresh interval
   (say, the app isn't running), the widget fetches the feeds itself.
3. If a feed fails to load, its previously fetched stays are kept and the settings window
   shows the error next to it.

## Parser scope

`ICSParser` handles line folding, text escaping, `VALUE=DATE` dates, timed dates (UTC or
`TZID`, including Windows names like `Central Standard Time`), `DURATION`, Outlook's
`X-MICROSOFT-CDO-ALLDAYEVENT`, cancelled events and nested `VALARM`s. Multi-line addresses are
tidied up, and the widget and menu show just the "City, ST" line. A stay's link comes from
the event's `URL` property, or else the first web link in its `DESCRIPTION`; clicking the stay
in the menu or widget opens it. It doesn't expand recurrence rules, since reservations don't
repeat.
