import Foundation
import Testing

struct ICSParserTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Denver")!
        return calendar
    }()

    var parser: ICSParser { ICSParser(calendar: calendar) }

    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// The year ahead of Sep 27, 2026.
    var range: DateInterval {
        DateInterval(start: day(2026, 9, 27), end: day(2027, 9, 27))
    }

    func ics(_ events: String) -> String {
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Test//EN\r\n\(events)\r\nEND:VCALENDAR\r\n"
    }

    @Test func parsesAllDayStay() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Pine Hollow RV Resort
        LOCATION:Moab\\, UT
        DTSTART;VALUE=DATE:20261002
        DTEND;VALUE=DATE:20261005
        END:VEVENT
        """)
        let stays = parser.stays(from: text, checkingInWithin: range)
        #expect(stays.count == 1)
        #expect(stays.first?.title == "Pine Hollow RV Resort")
        #expect(stays.first?.location == "Moab, UT")
        #expect(stays.first?.checkIn == day(2026, 10, 2))
        #expect(stays.first?.checkOut == day(2026, 10, 5))
        #expect(stays.first?.nights == 3)
    }

    @Test func stayWithoutEndIsOneNight() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Overnight
        DTSTART;VALUE=DATE:20261002
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).first?.nights == 1)
    }

    @Test func durationSetsCheckOut() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:A Week
        DTSTART;VALUE=DATE:20261002
        DURATION:P1W
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).first?.checkOut == day(2026, 10, 9))
    }

    @Test func ignoresTimedEvents() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Oil Change
        DTSTART:20261002T150000Z
        DTEND:20261002T160000Z
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).isEmpty)
    }

    @Test func treatsOutlookAllDayFlagAsAllDay() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Lakeside State Park
        DTSTART;TZID=America/Denver:20261012T000000
        DTEND;TZID=America/Denver:20261019T000000
        X-MICROSOFT-CDO-ALLDAYEVENT:TRUE
        END:VEVENT
        """)
        let stays = parser.stays(from: text, checkingInWithin: range)
        #expect(stays.first?.checkIn == day(2026, 10, 12))
        #expect(stays.first?.nights == 7)
    }

    @Test func stayAlreadyInProgressIsNotUpcoming() {
        let text = ics("""
        BEGIN:VEVENT
        UID:current
        SUMMARY:Where We Are Now
        DTSTART;VALUE=DATE:20260920
        DTEND;VALUE=DATE:20261002
        END:VEVENT
        BEGIN:VEVENT
        UID:next
        SUMMARY:Where We're Going
        DTSTART;VALUE=DATE:20261002
        DTEND;VALUE=DATE:20261005
        END:VEVENT
        """)
        let stays = parser.stays(from: text, checkingInWithin: range)
        #expect(stays.map(\.title) == ["Where We're Going"])
    }

    @Test func stayCheckingInTodayIsUpcoming() {
        let stay = Stay(id: "1", title: "Today", checkIn: day(2026, 9, 27), checkOut: day(2026, 9, 29))
        let noon = calendar.date(byAdding: .hour, value: 12, to: day(2026, 9, 27))!
        #expect([stay].upcoming(from: noon, calendar: calendar).count == 1)
        #expect(StayFormatting.daysUntil(stay, now: noon, calendar: calendar) == 0)
    }

    @Test func sortsByCheckIn() {
        let text = ics("""
        BEGIN:VEVENT
        UID:b
        SUMMARY:Second
        DTSTART;VALUE=DATE:20261012
        END:VEVENT
        BEGIN:VEVENT
        UID:a
        SUMMARY:First
        DTSTART;VALUE=DATE:20261005
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).map(\.title) == ["First", "Second"])
    }

    @Test func unfoldsLinesAndUnescapesText() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Desert Sky Campground\\; Site 12\\,
          pull-through
        DTSTART;VALUE=DATE:20261012
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).first?.title == "Desert Sky Campground; Site 12, pull-through")
    }

    @Test func skipsCancelledStays() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Cancelled
        STATUS:CANCELLED
        DTSTART;VALUE=DATE:20261002
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).isEmpty)
    }

    @Test func ignoresNestedAlarms() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:With Alarm
        DTSTART;VALUE=DATE:20261002
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:Reminder
        TRIGGER:-P1D
        END:VALARM
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).map(\.title) == ["With Alarm"])
    }

    @Test func webcalURLsAreFetchedOverHTTPS() {
        let feed = CalendarFeed(name: "Reservations", url: URL(string: "webcal://example.com/stays.ics")!)
        #expect(feed.fetchURL.absoluteString == "https://example.com/stays.ics")
    }
}
