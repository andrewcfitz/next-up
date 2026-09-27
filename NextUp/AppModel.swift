import AppKit
import Observation
import ServiceManagement
import WidgetKit

/// App-wide state: the configured feeds, settings, and the latest fetched stays.
/// Everything is persisted to the App Group so the widget sees the same data.
@MainActor
@Observable
final class AppModel {
    var feeds: [CalendarFeed] {
        didSet {
            guard feeds != oldValue else { return }
            SharedStore.feeds = feeds
            Task { await refresh() }
        }
    }

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            SharedStore.settings = settings
            if settings.refreshInterval != oldValue.refreshInterval { startRefreshLoop() }
        }
    }

    private(set) var snapshot: StaySnapshot?
    private(set) var isRefreshing = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Bumped at midnight so countdowns stay correct.
    private(set) var now = Date.now

    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherRefresh = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        feeds = SharedStore.feeds
        settings = SharedStore.settings
        snapshot = SharedStore.snapshot
        startRefreshLoop()
        observeSystemEvents()
    }

    /// Stays that haven't started yet, soonest first.
    var upcomingStays: [Stay] {
        snapshot?.stays.upcoming(from: now) ?? []
    }

    var nextStay: Stay? { upcomingStays.first }

    func status(for feed: CalendarFeed) -> FeedStatus? {
        snapshot?.statuses[feed.id]
    }

    // MARK: Feeds

    func addFeed(_ feed: CalendarFeed) {
        feeds.append(feed)
    }

    func updateFeed(_ feed: CalendarFeed) {
        guard let index = feeds.firstIndex(where: { $0.id == feed.id }) else { return }
        feeds[index] = feed
    }

    func removeFeeds(_ ids: Set<CalendarFeed.ID>) {
        feeds.removeAll { ids.contains($0.id) }
    }

    // MARK: Refreshing

    func refresh() async {
        guard !isRefreshing else {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            needsAnotherRefresh = false
            now = .now
            let result = await FeedService().fetch(feeds, previous: snapshot)
            snapshot = result
            SharedStore.snapshot = result
        } while needsAnotherRefresh

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func startRefreshLoop() {
        refreshLoop?.cancel()
        let minutes = max(settings.refreshInterval, 5)
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(minutes * 60))
            }
        }
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter

        // Midnight: countdowns tick down, and today's check-in drops off tomorrow.
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.now = .now
                WidgetCenter.shared.reloadAllTimelines()
            }
        })
        // The laptop lid was closed for a while; the data is probably stale.
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        })
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Next Up: couldn't update login item: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
