import Foundation
import Testing

struct FeedEditingTests {
    @Test func acceptsWebAndCalendarSchemes() {
        #expect(CalendarFeed.validatedURL("https://example.com/a.ics") != nil)
        #expect(CalendarFeed.validatedURL("  webcal://example.com/a.ics\n") == URL(string: "webcal://example.com/a.ics"))
        #expect(CalendarFeed.validatedURL("webcals://example.com/a.ics") != nil)
    }

    @Test func rejectsTyposAndOtherSchemes() {
        #expect(CalendarFeed.validatedURL("") == nil)
        #expect(CalendarFeed.validatedURL("example.com/a.ics") == nil)
        #expect(CalendarFeed.validatedURL("ftp://example.com/a.ics") == nil)
        #expect(CalendarFeed.validatedURL("https://") == nil)
    }

    @Test func httpFeedsAreFetchedOverHTTPS() {
        let http = CalendarFeed(name: "Test", url: URL(string: "http://example.com/a.ics")!)
        #expect(http.fetchURL == URL(string: "https://example.com/a.ics"))
        #expect(CalendarFeed(name: "Test", url: URL(string: "webcal://example.com/a.ics")!).fetchURL == URL(string: "https://example.com/a.ics"))
        #expect(CalendarFeed(name: "Test", url: URL(string: "https://example.com/a.ics")!).fetchURL == URL(string: "https://example.com/a.ics"))
    }

    @Test func newFeedNamesFallBackToTheHost() throws {
        let feed = try #require(CalendarFeed.edited(name: "  ", urlText: "webcal://cal.example.com/x.ics", from: nil))
        #expect(feed.name == "cal.example.com")
        #expect(feed.isEnabled)
    }

    @Test func editingKeepsIdentityAndEnabledState() throws {
        var original = CalendarFeed(name: "Old", url: URL(string: "https://a.example/x.ics")!)
        original.isEnabled = false
        let edited = try #require(CalendarFeed.edited(name: "New", urlText: "https://b.example/y.ics", from: original))
        #expect(edited.id == original.id)
        #expect(edited.name == "New")
        #expect(edited.url == URL(string: "https://b.example/y.ics"))
        #expect(edited.isEnabled == false)
        #expect(CalendarFeed.edited(name: "New", urlText: "nope", from: original) == nil)
    }

    @Test func upsertAndRemove() {
        let a = CalendarFeed(name: "A", url: URL(string: "https://a.example/a.ics")!)
        let b = CalendarFeed(name: "B", url: URL(string: "https://b.example/b.ics")!)
        var renamed = a
        renamed.name = "A2"
        #expect([a].upserting(b).map(\.name) == ["A", "B"])
        #expect([a, b].upserting(renamed).map(\.name) == ["A2", "B"])
        #expect([a, b].removing([a.id]).map(\.name) == ["B"])
    }
}
