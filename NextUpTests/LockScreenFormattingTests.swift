import Foundation
import Testing

struct LockScreenFormattingTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()
    let locale = Locale(identifier: "en_US")

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }

    func stay(_ title: String, checkIn: Date, nights: Int = 3, location: String? = "123 Main St\nMoab, UT\n84532") -> Stay {
        Stay(id: title, title: title, checkIn: checkIn, checkOut: calendar.date(byAdding: .day, value: nights, to: checkIn)!,
             location: location)
    }

    @Test func inlineCountsDays() {
        let now = day(2026, 10, 13)
        #expect(StayFormatting.inline(stay("Pine Hollow", checkIn: day(2026, 10, 16)), now: now, calendar: calendar) == "in 3d · Pine Hollow")
        #expect(StayFormatting.inline(stay("Pine Hollow", checkIn: day(2026, 10, 13)), now: now, calendar: calendar) == "Today · Pine Hollow")
    }

    @Test func rectangularLines() {
        let now = day(2026, 10, 13)
        #expect(StayFormatting.rectangularLines(stay("Pine Hollow", checkIn: day(2026, 10, 16)), now: now, calendar: calendar, locale: locale)
                == ["Pine Hollow", "in 3d · Fri, Oct 16", "Moab, UT"])
        #expect(StayFormatting.rectangularLines(stay("Lakeside", checkIn: day(2026, 10, 13), location: nil), now: now, calendar: calendar, locale: locale)
                == ["Lakeside", "Today · Tue, Oct 13"])
    }

    @Test func secondLineFitsTheLockScreen() {
        let now = day(2026, 10, 13)
        let far = stay("Far Away", checkIn: day(2027, 9, 29))
        let line = StayFormatting.rectangularLines(far, now: now, calendar: calendar, locale: locale)[1]
        #expect(line.count <= 24, "\(line)")
    }
}
