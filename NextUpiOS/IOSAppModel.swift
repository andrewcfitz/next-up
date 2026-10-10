import BackgroundTasks
import Foundation
import Observation

@MainActor
@Observable
final class IOSAppModel {
    nonisolated static let refreshTaskID = (Bundle.main.bundleIdentifier ?? "biz.fitz.NextUp") + ".refresh"

    private(set) var feeds: [CalendarFeed] = SharedStore.feeds
    private(set) var snapshot: StaySnapshot? = SharedStore.snapshot
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false
    private(set) var now = Date.now

    @ObservationIgnored private var needsAnotherRefresh = false

    var upcomingStays: [Stay] { snapshot?.stays.upcoming(from: now) ?? [] }

    func status(for feed: CalendarFeed) -> FeedStatus? { snapshot?.statuses[feed.id] }

    func save(_ feed: CalendarFeed) { setFeeds(feeds.upserting(feed)) }
    func remove(_ ids: Set<UUID>) { setFeeds(feeds.removing(ids)) }
    func setEnabled(_ feed: CalendarFeed, _ enabled: Bool) {
        var updated = feed
        updated.isEnabled = enabled
        save(updated)
    }

    private func setFeeds(_ newFeeds: [CalendarFeed]) {
        feeds = newFeeds
        SharedStore.feeds = newFeeds
        Task { await refresh() }
    }

    /// The widget fetches on its own; opening the app is a cheap extra so the list is current.
    func becameActive() async {
        now = .now
        feeds = SharedStore.feeds
        snapshot = SharedStore.snapshot
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            needsAnotherRefresh = false
            snapshot = await FeedRefresh.run(feeds: feeds, previous: snapshot)
            now = .now
        } while needsAnotherRefresh

        PhoneWatchSync.shared.send(feeds: feeds, snapshot: snapshot)
    }

    /// iOS decides when, or whether, this runs; it only ever helps the widget's own fetching.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = .now + TimeInterval(max(RefreshRule.minimumMinutes, SharedStore.settings.refreshInterval) * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func backgroundRefresh() async {
        feeds = SharedStore.feeds
        await refresh()
        scheduleBackgroundRefresh()
    }
}
