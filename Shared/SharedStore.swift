import Foundation

/// Persistence shared between the app and the widget extension through an App Group.
///
/// If you change the App Group identifier, update it here and in both
/// `NextUp.entitlements` and `NextUpWidget.entitlements`.
enum SharedStore {
    static let appGroupID = "group.com.andrewcfitz.NextUp"

    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    private enum Key {
        static let feeds = "feeds"
        static let settings = "settings"
        static let snapshot = "snapshot"
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static var feeds: [CalendarFeed] {
        get { load([CalendarFeed].self, key: Key.feeds) ?? [] }
        set { save(newValue, key: Key.feeds) }
    }

    static var settings: AppSettings {
        get { load(AppSettings.self, key: Key.settings) ?? AppSettings() }
        set { save(newValue, key: Key.settings) }
    }

    /// The most recent fetch, used by the widget when it can't reach the network.
    static var snapshot: StaySnapshot? {
        get { load(StaySnapshot.self, key: Key.snapshot) }
        set { save(newValue, key: Key.snapshot) }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct AppSettings: Codable, Equatable {
    enum MenuBarStyle: String, Codable, CaseIterable, Identifiable {
        case iconOnly, nextStay, daysUntil
        var id: Self { self }

        var label: String {
            switch self {
            case .iconOnly: "Icon only"
            case .nextStay: "Next stay"
            case .daysUntil: "Days until next stay"
            }
        }
    }

    /// Minutes between background refreshes.
    var refreshInterval: Int = 60
    var menuBarStyle: MenuBarStyle = .nextStay
}

struct FeedStatus: Codable, Hashable, Sendable {
    var stayCount: Int
    var error: String?
}

struct StaySnapshot: Codable, Sendable {
    var stays: [Stay]
    var fetchedAt: Date
    var statuses: [UUID: FeedStatus] = [:]
}
