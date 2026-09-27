import Foundation

/// Downloads and parses every enabled feed.
struct FeedService: Sendable {
    /// How far ahead to look for upcoming stays.
    static let lookAheadDays = 365

    var session: URLSession = .shared
    var calendar: Calendar = .current

    enum FeedError: LocalizedError {
        case http(Int)
        case notCalendar

        var errorDescription: String? {
            switch self {
            case .http(let code): "Couldn’t load (\(code))"
            case .notCalendar: "Not an iCal feed"
            }
        }
    }

    /// Fetches all enabled feeds concurrently. A failing feed doesn't fail the whole refresh:
    /// its error is reported in `statuses`, and its stays from `previous` are kept.
    func fetch(_ feeds: [CalendarFeed], previous: StaySnapshot? = nil, now: Date = .now) async -> StaySnapshot {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: Self.lookAheadDays, to: today) ?? today
        let range = DateInterval(start: today, end: end)

        let results = await withTaskGroup(of: (UUID, Result<[Stay], Error>).self) { group in
            for feed in feeds where feed.isEnabled {
                group.addTask {
                    do {
                        return (feed.id, .success(try await fetch(feed, in: range)))
                    } catch {
                        return (feed.id, .failure(error))
                    }
                }
            }
            var collected: [(UUID, Result<[Stay], Error>)] = []
            for await result in group { collected.append(result) }
            return collected
        }

        var stays: [Stay] = []
        var statuses: [UUID: FeedStatus] = [:]
        for (id, result) in results {
            switch result {
            case .success(let feedStays):
                stays += feedStays
                statuses[id] = FeedStatus(stayCount: feedStays.count)
            case .failure(let error):
                let stale = previous?.stays.filter { $0.feedID == id }.upcoming(from: now, calendar: calendar) ?? []
                stays += stale
                statuses[id] = FeedStatus(stayCount: stale.count, error: error.localizedDescription)
            }
        }

        stays.sort { ($0.checkIn, $0.title) < ($1.checkIn, $1.title) }
        return StaySnapshot(stays: stays, fetchedAt: now, statuses: statuses)
    }

    func fetch(_ feed: CalendarFeed, in range: DateInterval) async throws -> [Stay] {
        var request = URLRequest(url: feed.fetchURL, timeoutInterval: 20)
        request.setValue("text/calendar, */*;q=0.5", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.http(http.statusCode)
        }
        let text = String(decoding: data, as: UTF8.self)
        guard text.contains("BEGIN:VCALENDAR") else { throw FeedError.notCalendar }
        return ICSParser(calendar: calendar).stays(from: text, checkingInWithin: range, feed: feed)
    }
}
