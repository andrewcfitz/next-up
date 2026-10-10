import Foundation

/// What the iPhone app sends the watch, which can't see the phone's App Group:
/// the feeds (the phone owns them) and its latest fetch.
struct WatchPayload: Codable, Sendable {
    static let key = "payload"

    var feeds: [CalendarFeed]
    var snapshot: StaySnapshot?

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
}

extension WatchPayload {
    init?(dictionary: [String: Any]) {
        guard let data = dictionary[Self.key] as? Data,
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = decoded
    }
}
