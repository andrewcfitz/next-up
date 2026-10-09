import Foundation
import WidgetKit

/// The refresh both apps run: fetch every enabled feed, keep the result for the widget, redraw it.
enum FeedRefresh {
    static func run(feeds: [CalendarFeed], previous: StaySnapshot?) async -> StaySnapshot {
        let snapshot = await FeedService().fetch(feeds, previous: previous)
        SharedStore.snapshot = snapshot
        WidgetCenter.shared.reloadAllTimelines()
        return snapshot
    }
}
