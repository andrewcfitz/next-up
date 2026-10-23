import Foundation
import Testing

struct StayBreakTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()
    let locale = Locale(identifier: "en_US")

    func day(_ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: m, day: d))! }

    func stay(_ title: String, _ checkIn: Date, _ checkOut: Date) -> Stay {
        Stay(id: title, title: title, checkIn: checkIn, checkOut: checkOut)
    }

    func items(_ stays: [Stay], now: Date) -> [StayListItem] {
        stays.upcomingWithBreaks(from: now, calendar: calendar)
    }

    @Test func missingNightBetweenStaysIsAGap() {
        let list = items([stay("A", day(10, 22), day(10, 23)), stay("B", day(10, 24), day(10, 25))], now: day(10, 22))
        #expect(list == [
            .stay(stay("A", day(10, 22), day(10, 23))),
            .breakBetween(StayBreak(kind: .gap, start: day(10, 23), end: day(10, 24))),
            .stay(stay("B", day(10, 24), day(10, 25))),
        ])
    }

    @Test func backToBackStaysHaveNoBreak() {
        let list = items([stay("A", day(10, 22), day(10, 24)), stay("B", day(10, 24), day(10, 25))], now: day(10, 22))
        #expect(list.breaks.isEmpty)
    }

    @Test func sharedNightsAreAnOverlap() {
        let list = items([stay("A", day(10, 27), day(10, 30)), stay("B", day(10, 29), day(11, 2))], now: day(10, 22))
        #expect(list.breaks == [StayBreak(kind: .overlap, start: day(10, 29), end: day(10, 30))])
    }

    @Test func stayInsideAnotherOverlapsOnlyItsOwnNights() {
        let list = items([stay("Long", day(10, 22), day(10, 31)), stay("Short", day(10, 24), day(10, 26)),
                          stay("Next", day(10, 31), day(11, 2))], now: day(10, 22))
        // The short stay ends before the long one, so the long one still covers through Oct 31: no gap.
        #expect(list.breaks == [StayBreak(kind: .overlap, start: day(10, 24), end: day(10, 26))])
    }

    @Test func gapAfterTheStayInProgressStillShows() {
        // Checked in yesterday, so the stay itself is hidden, but tonight is unbooked.
        let list = items([stay("Current", day(10, 21), day(10, 22)), stay("Next", day(10, 24), day(10, 26))], now: day(10, 22))
        #expect(list == [
            .breakBetween(StayBreak(kind: .gap, start: day(10, 22), end: day(10, 24))),
            .stay(stay("Next", day(10, 24), day(10, 26))),
        ])
    }

    @Test func pastGapsAreDropped() {
        let list = items([stay("A", day(10, 10), day(10, 12)), stay("B", day(10, 15), day(10, 25))], now: day(10, 22))
        #expect(list.isEmpty)
    }

    @Test func gapThatStartedBeforeTodayCountsFromTonight() {
        let list = items([stay("A", day(10, 18), day(10, 20)), stay("B", day(10, 19), day(10, 20)),
                          stay("C", day(10, 25), day(10, 27))], now: day(10, 22))
        #expect(list.breaks == [StayBreak(kind: .gap, start: day(10, 22), end: day(10, 25))])
    }

    @Test func nightCounts() {
        #expect(StayBreak(kind: .gap, start: day(10, 23), end: day(10, 24)).nights(calendar: calendar) == 1)
        #expect(StayBreak(kind: .gap, start: day(11, 2), end: day(11, 5)).nights(calendar: calendar) == 3)
    }

    @Test func prefixKeepsBreaksBeforeTheLastStay() {
        let list = items([stay("A", day(10, 22), day(10, 23)), stay("B", day(10, 24), day(10, 25)),
                          stay("C", day(10, 27), day(10, 28))], now: day(10, 22))
        #expect(list.prefix(stays: 2).count == 3)
        #expect(list.prefix(stays: 3).count == 5)
    }

    @Test func labels() {
        let gap = StayBreak(kind: .gap, start: day(10, 23), end: day(10, 24))
        let longGap = StayBreak(kind: .gap, start: day(11, 2), end: day(11, 5))
        let overlap = StayBreak(kind: .overlap, start: day(10, 29), end: day(10, 30))
        let longOverlap = StayBreak(kind: .overlap, start: day(10, 30), end: day(11, 1))

        #expect(StayFormatting.title(gap) == "No stay booked")
        #expect(StayFormatting.title(overlap) == "Stays overlap")
        #expect(StayFormatting.nights(gap, calendar: calendar) == "1 night")
        #expect(StayFormatting.nights(longGap, calendar: calendar) == "3 nights")

        #expect(StayFormatting.detail(gap, calendar: calendar, locale: locale) == "Night of Fri, Oct 23")
        #expect(StayFormatting.detail(longGap, calendar: calendar, locale: locale) == "Nights of Mon, Nov 2 – Wed, Nov 4")
        #expect(StayFormatting.detail(overlap, calendar: calendar, locale: locale) == "Night of Thu, Oct 29 is booked twice")
        #expect(StayFormatting.detail(longOverlap, calendar: calendar, locale: locale) == "Nights of Fri, Oct 30 – Sat, Oct 31 are booked twice")

        #expect(StayFormatting.short(gap, calendar: calendar, locale: locale) == "No stay Fri, Oct 23")
        #expect(StayFormatting.short(longGap, calendar: calendar, locale: locale) == "No stay Nov 2 – 4")
        #expect(StayFormatting.short(overlap, calendar: calendar, locale: locale) == "Overlap Thu, Oct 29")
        #expect(StayFormatting.short(longOverlap, calendar: calendar, locale: locale) == "Overlap Oct 30 – 31")
    }

    @Test func summary() {
        let list = items([stay("A", day(10, 22), day(10, 23)), stay("B", day(10, 24), day(10, 28)),
                          stay("C", day(10, 27), day(10, 29)), stay("D", day(11, 1), day(11, 2))], now: day(10, 22))
        #expect(StayFormatting.summary(list.breaks) == "2 gaps · 1 overlap")
        #expect(StayFormatting.summary([]) == nil)
    }
}
