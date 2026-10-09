import Foundation
import WidgetKit

/// The refresh both apps run: fetch every enabled feed, keep the result for the widget, redraw it.
enum FeedRefresh {
    static func run(feeds: [CalendarFeed], previous: StaySnapshot?, reloadWidgets: Bool = true) async -> StaySnapshot {
        let snapshot = await FeedService().fetch(feeds, previous: previous)
        SharedStore.snapshot = snapshot
        // Widget provider's timeline build already has the fresh snapshot; skip redundant reload to preserve WidgetKit budget.
        if reloadWidgets { WidgetCenter.shared.reloadAllTimelines() }
        return snapshot
    }
}
