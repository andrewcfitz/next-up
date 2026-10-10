import Foundation

/// What the iPhone app sends the watch, which can't see the phone's App Group:
/// the feeds (the phone owns them) and its latest fetch.
struct WatchPayload: Codable, Sendable {
    static let key = "payload"

    var feeds: [CalendarFeed]
    var snapshot: StaySnapshot?
    var sentAt: Date

    init(feeds: [CalendarFeed], snapshot: StaySnapshot?, sentAt: Date = .now) {
        self.feeds = feeds
        self.snapshot = snapshot
        self.sentAt = sentAt
    }

    /// WatchConnectivity dictionaries only carry property-list values, so the payload travels as JSON.
    func dictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.key: data]
    }

    /// The watch fetches on its own too, so a push can arrive older than what it already has.
    static func newer(_ incoming: StaySnapshot?, than current: StaySnapshot?) -> StaySnapshot? {
        guard let incoming else { return current }
        guard let current else { return incoming }
        return incoming.fetchedAt > current.fetchedAt ? incoming : current
    }

    /// What the watch should store after this payload, or nil when an older payload arrives after a newer one
    /// (queued complication transfers are delivered after the latest context).
    func merged(currentFeeds: [CalendarFeed], currentSnapshot: StaySnapshot?, lastAppliedAt: Date?) -> (feeds: [CalendarFeed], snapshot: StaySnapshot?)? {
        if let lastAppliedAt, sentAt < lastAppliedAt { return nil }
        // A snapshot the watch fetched with feeds the phone has since replaced can't be trusted, however new.
        if feeds != currentFeeds { return (feeds, snapshot) }
        return (feeds, Self.newer(snapshot, than: currentSnapshot))
    }
}

extension WatchPayload {
    init?(dictionary: [String: Any]) {
        guard let data = dictionary[Self.key] as? Data,
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = decoded
    }
}
