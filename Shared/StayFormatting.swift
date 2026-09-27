import Foundation

/// Human-friendly labels for stays, shared by the app and the widget.
enum StayFormatting {
    /// Whole days from today until check-in (0 = checking in today).
    static func daysUntil(_ stay: Stay, now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: stay.checkIn).day ?? 0)
    }

    /// "Today", "Tomorrow", "in 5 days".
    static func countdown(_ stay: Stay, now: Date = .now) -> String {
        switch daysUntil(stay, now: now) {
        case 0: "Today"
        case 1: "Tomorrow"
        case let days: "in \(days) days"
        }
    }

    /// Compact countdown for the menu bar: "Today", "1d", "5d".
    static func shortCountdown(_ stay: Stay, now: Date = .now) -> String {
        let days = daysUntil(stay, now: now)
        return days == 0 ? "Today" : "\(days)d"
    }

    /// "3 nights".
    static func nights(_ stay: Stay) -> String {
        stay.nights == 1 ? "1 night" : "\(stay.nights) nights"
    }

    /// "Fri, Oct 2 – Mon, Oct 5".
    static func dates(_ stay: Stay) -> String {
        let style = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        return "\(stay.checkIn.formatted(style)) – \(stay.checkOut.formatted(style))"
    }

    /// "Oct 2".
    static func checkInDay(_ stay: Stay) -> String {
        stay.checkIn.formatted(.dateTime.month(.abbreviated).day())
    }
}

extension Array where Element == Stay {
    /// Stays that check in today or later. Stays already in progress are skipped:
    /// what matters is where you're headed next.
    func upcoming(from now: Date = .now, calendar: Calendar = .current) -> [Stay] {
        let today = calendar.startOfDay(for: now)
        return filter { $0.checkIn >= today }
    }
}
