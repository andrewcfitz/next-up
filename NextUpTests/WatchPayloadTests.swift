import Foundation
import Testing

struct WatchPayloadTests {
    let feed = CalendarFeed(name: "Reservations", url: URL(string: "webcal://example.com/r.ics")!)

    func snapshot(_ id: String = "a", fetchedAt seconds: TimeInterval) -> StaySnapshot {
        let checkIn = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let stay = Stay(id: id, title: "Pine Hollow", checkIn: checkIn, checkOut: checkIn + 3 * 86_400, location: "Moab, UT")
        return StaySnapshot(stays: [stay], fetchedAt: Date(timeIntervalSinceReferenceDate: seconds))
    }

    @Test func roundTripsThroughADictionary() throws {
        let payload = WatchPayload(feeds: [feed], snapshot: snapshot(fetchedAt: 100))
        let decoded = try #require(WatchPayload(dictionary: payload.dictionary()))
        #expect(decoded.feeds == [feed])
        #expect(decoded.snapshot?.stays == payload.snapshot?.stays)
        #expect(decoded.snapshot?.fetchedAt == payload.snapshot?.fetchedAt)
    }

    @Test func roundTripsWithoutASnapshot() throws {
        let decoded = try #require(WatchPayload(dictionary: WatchPayload(feeds: [], snapshot: nil).dictionary()))
        #expect(decoded.feeds.isEmpty)
        #expect(decoded.snapshot == nil)
    }

    @Test func rejectsMissingOrGarbageData() {
        #expect(WatchPayload(dictionary: [:]) == nil)
        #expect(WatchPayload(dictionary: [WatchPayload.key: Data("nope".utf8)]) == nil)
        #expect(WatchPayload(dictionary: [WatchPayload.key: "not data"]) == nil)
        #expect(WatchPayload(dictionary: ["other": WatchPayload(feeds: [feed], snapshot: nil).dictionary()[WatchPayload.key]!]) == nil)
    }

    @Test func newerSnapshotWins() {
        let old = snapshot("old", fetchedAt: 100)
        let new = snapshot("new", fetchedAt: 200)
        #expect(WatchPayload.newer(new, than: old)?.stays.first?.id == "new")
        #expect(WatchPayload.newer(old, than: new)?.stays.first?.id == "new")
    }

    @Test func missingSideFallsBackToTheOther() {
        let only = snapshot("only", fetchedAt: 100)
        #expect(WatchPayload.newer(nil, than: only)?.stays.first?.id == "only")
        #expect(WatchPayload.newer(only, than: nil)?.stays.first?.id == "only")
        #expect(WatchPayload.newer(nil, than: nil) == nil)
    }

    @Test func tieKeepsCurrent() {
        let incoming = snapshot("incoming", fetchedAt: 100)
        let current = snapshot("current", fetchedAt: 100)
        #expect(WatchPayload.newer(incoming, than: current)?.stays.first?.id == "current")
    }
}
