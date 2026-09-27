import Foundation

/// An iCal feed the user has subscribed to, e.g. a calendar of campground reservations.
struct CalendarFeed: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var url: URL
    var isEnabled: Bool = true

    /// `webcal://` is just `https://` with a different hat on.
    var fetchURL: URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "webcal" || scheme == "webcals" else {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }
}

/// A stay: one all-day event from a feed.
///
/// All-day events in iCal are "floating" dates with no time zone. They are stored
/// as midnight in the user's current time zone. `checkOut` is the iCal `DTEND`,
/// which is exclusive — so a stay from Oct 2 to Oct 5 is three nights.
struct Stay: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var checkIn: Date
    var checkOut: Date
    var location: String?
    var feedID: UUID?
    var feedName: String?

    /// The most recognizable line of the address for tight spaces: the "City, ST" line
    /// when there is one ("678 MO-147\nTroy, MO\n63379" → "Troy, MO"), else the first line.
    var place: String? {
        let lines = location?.split(whereSeparator: \.isNewline).map(String.init) ?? []
        return lines.first { $0.contains(",") } ?? lines.first
    }

    var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
    }
}
