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

    @Test func ignoresSameDayTimedEvents() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Oil Change
        DTSTART:20261002T150000Z
        DTEND:20261002T160000Z
        END:VEVENT
        BEGIN:VEVENT
        UID:2
        SUMMARY:No End
        DTSTART:20261003T150000Z
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).isEmpty)
    }

    @Test func timedOvernightEventIsAStay() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Pine Hollow RV Resort
        DTSTART;TZID=America/Denver:20261002T140000
        DTEND;TZID=America/Denver:20261005T110000
        END:VEVENT
        """)
        let stays = parser.stays(from: text, checkingInWithin: range)
        #expect(stays.first?.checkIn == day(2026, 10, 2))
        #expect(stays.first?.checkOut == day(2026, 10, 5))
        #expect(stays.first?.nights == 3)
    }

    @Test func timedStayWithUTCTimesUsesLocalDates() {
        // 2 PM to 11 AM Mountain Daylight Time, written in UTC.
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Lakeside State Park
        DTSTART:20261012T200000Z
        DTEND:20261019T170000Z
        END:VEVENT
        """)
        let stays = parser.stays(from: text, checkingInWithin: range)
        #expect(stays.first?.checkIn == day(2026, 10, 12))
        #expect(stays.first?.nights == 7)
    }

    /// Matches the shape of the Louie feed: .NET-generated, Windows time zone names,
    /// timed check-in/check-out, and multi-line (sometimes empty) addresses.
    @Test func parsesLouieStyleFeed() {
        let text = ics("""
        BEGIN:VEVENT
        DESCRIPTION:
        DTEND;TZID=Central Standard Time:20261017T120000
        DTSTAMP:20260926T233430Z
        DTSTART;TZID=Central Standard Time:20261012T150000
        LOCATION:123 Park Rd\\nSpringfield\\, MO\\n65801\\n
        SEQUENCE:0
        SUMMARY:Lakeside Park RV Campground - 409
        UID:a
        END:VEVENT
        BEGIN:VEVENT
        DESCRIPTION:
        DTEND;TZID=America/Chicago:20261023T120000
        DTSTART;TZID=America/Chicago:20261018T150000
        LOCATION:\\n\\, \\n\\n
        SUMMARY:Lakeside Park RV Campground - 406
        UID:b
        END:VEVENT
        """)
        var central = calendar
        central.timeZone = TimeZone(identifier: "America/Chicago")!
        let stays = ICSParser(calendar: central).stays(
            from: text,
            checkingInWithin: DateInterval(start: central.date(from: DateComponents(year: 2026, month: 9, day: 27))!, duration: 86_400 * 365)
        )
        #expect(stays.map(\.title) == ["Lakeside Park RV Campground - 409", "Lakeside Park RV Campground - 406"])
        #expect(stays.first?.checkIn == central.date(from: DateComponents(year: 2026, month: 10, day: 12)))
        #expect(stays.first?.checkOut == central.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        #expect(stays.first?.location == "123 Park Rd\nSpringfield, MO\n65801")
        #expect(stays.first?.place == "Springfield, MO")
        #expect(stays.last?.location == nil)
    }

    @Test func windowsTimeZoneNamesResolve() {
        #expect(ICSDate.timeZone("Central Standard Time")?.identifier == "America/Chicago")
        #expect(ICSDate.timeZone("Eastern Standard Time")?.identifier == "America/New_York")
        #expect(ICSDate.timeZone("America/Denver")?.identifier == "America/Denver")
        #expect(ICSDate.timeZone("Nowhere Standard Time") == nil)
    }

    @Test func timedStayWithDuration() {
        let text = ics("""
        BEGIN:VEVENT
        UID:1
        SUMMARY:Desert Sky
        DTSTART;TZID=America/Denver:20261002T140000
        DURATION:P2DT21H
        END:VEVENT
        """)
        #expect(parser.stays(from: text, checkingInWithin: range).first?.checkOut == day(2026, 10, 5))
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
