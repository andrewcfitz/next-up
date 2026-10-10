import Foundation
import Observation

@MainActor
@Observable
final class WatchAppModel {
    private(set) var snapshot: StaySnapshot? = SharedStore.snapshot
    private(set) var hasFeeds = !SharedStore.feeds.isEmpty
    private(set) var isRefreshing = false
    private(set) var now = Date.now

    var upcomingStays: [Stay] { snapshot?.stays.upcoming(from: now) ?? [] }

    func reload() {
        snapshot = SharedStore.snapshot
        hasFeeds = !SharedStore.feeds.isEmpty
        now = .now
    }

    /// The phone usually keeps the watch current; this is for when it's out of reach.
    func refresh() async {
        guard !isRefreshing, SharedStore.feeds.contains(where: \.isEnabled) else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // A phone push can replace the feeds mid-fetch; go again so the stays match them.
        var feeds: [CalendarFeed]
        repeat {
            feeds = SharedStore.feeds
            _ = await FeedRefresh.run(feeds: feeds, previous: SharedStore.snapshot)
        } while feeds != SharedStore.feeds
        reload()
    }
}
