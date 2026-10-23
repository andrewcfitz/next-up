import Foundation

/// Nights between stays that are either unbooked or booked twice.
struct StayBreak: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// Nowhere to stay.
        case gap
        /// Two stays claim the same night.
        case overlap
    }

    var kind: Kind
    /// The first affected night.
    var start: Date
    /// The morning after the last affected night, exclusive like `Stay.checkOut`.
    var end: Date

    func nights(calendar: Calendar = .current) -> Int {
        max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
    }
}

/// A row in a list of upcoming stays: a stay, or the break before it.
enum StayListItem: Hashable, Identifiable, Sendable {
    case stay(Stay)
    case breakBetween(StayBreak)

    var id: String {
        switch self {
        case .stay(let stay): "stay-\(stay.id)"
        case .breakBetween(let gap): "break-\(gap.kind)-\(gap.start.timeIntervalSince1970)"
        }
    }

    var stay: Stay? {
        if case .stay(let stay) = self { stay } else { nil }
    }
}

extension Array where Element == Stay {
    /// The upcoming stays with a break before each stay that doesn't pick up where the
    /// stays before it left off. Stays in progress are hidden like in `upcoming(from:)`,
    /// but still count, so tonight's gap after the current stay shows. Nights before
    /// today are dropped.
    func upcomingWithBreaks(from now: Date = .now, calendar: Calendar = .current) -> [StayListItem] {
        let today = calendar.startOfDay(for: now)
        var items: [StayListItem] = []
        // The latest check-out so far: a short stay inside a long one doesn't end the coverage.
        var coveredUntil: Date?

        for stay in sorted(by: { ($0.checkIn, $0.checkOut) < ($1.checkIn, $1.checkOut) }) {
            if let coveredUntil {
                let gap: StayBreak? = if stay.checkIn > coveredUntil {
                    StayBreak(kind: .gap, start: coveredUntil, end: stay.checkIn)
                } else if stay.checkIn < coveredUntil {
                    StayBreak(kind: .overlap, start: stay.checkIn, end: Swift.min(stay.checkOut, coveredUntil))
                } else {
                    nil
                }
                if var gap, gap.end > today {
                    gap.start = Swift.max(gap.start, today)
                    items.append(.breakBetween(gap))
                }
            }
            if stay.checkIn >= today { items.append(.stay(stay)) }
            coveredUntil = Swift.max(coveredUntil ?? stay.checkOut, stay.checkOut)
        }
        return items
    }
}

extension Sequence where Element == StayListItem {
    var breaks: [StayBreak] {
        compactMap { if case .breakBetween(let gap) = $0 { gap } else { nil } }
    }
}

extension Array where Element == StayListItem {
    /// The first `count` stays and the breaks before them. A break before a stay that's
    /// cut off is cut too, along with the stay it leads up to.
    func prefix(stays count: Int) -> [StayListItem] {
        var seen = 0
        var end = 0
        for (index, item) in enumerated() where item.stay != nil {
            guard seen < count else { break }
            seen += 1
            end = index + 1
        }
        return Array(self[..<end])
    }
}

extension StayFormatting {
    /// "No stay booked", "Stays overlap".
    static func title(_ gap: StayBreak) -> String {
        switch gap.kind {
        case .gap: "No stay booked"
        case .overlap: "Stays overlap"
        }
    }

    /// "1 night", "3 nights".
    static func nights(_ gap: StayBreak, calendar: Calendar = .current) -> String {
        let nights = gap.nights(calendar: calendar)
        return nights == 1 ? "1 night" : "\(nights) nights"
    }

    /// "Night of Fri, Oct 23", "Nights of Mon, Nov 2 – Wed, Nov 4 are booked twice".
    static func detail(_ gap: StayBreak, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day()
        let single = gap.nights(calendar: calendar) == 1
        let nights = single
            ? "Night of \(gap.start.formatted(style))"
            : "Nights of \(gap.start.formatted(style)) – \(lastNight(gap, calendar: calendar).formatted(style))"
        switch gap.kind {
        case .gap: return nights
        case .overlap: return nights + (single ? " is booked twice" : " are booked twice")
        }
    }

    /// For tight spaces: "No stay Fri, Oct 23", "No stay Nov 2 – 4", "Overlap Thu, Oct 29".
    static func short(_ gap: StayBreak, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let prefix = gap.kind == .gap ? "No stay" : "Overlap"
        let base = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        guard gap.nights(calendar: calendar) > 1 else {
            return "\(prefix) \(gap.start.formatted(base.weekday(.abbreviated).month(.abbreviated).day()))"
        }
        let last = lastNight(gap, calendar: calendar)
        let endStyle = calendar.isDate(gap.start, equalTo: last, toGranularity: .month)
            ? base.day()
            : base.month(.abbreviated).day()
        return "\(prefix) \(gap.start.formatted(base.month(.abbreviated).day())) – \(last.formatted(endStyle))"
    }

    /// "2 gaps · 1 overlap", or nil when every night is booked once.
    static func summary(_ breaks: [StayBreak]) -> String? {
        let gaps = breaks.count { $0.kind == .gap }
        let overlaps = breaks.count { $0.kind == .overlap }
        let parts = [
            gaps == 0 ? nil : gaps == 1 ? "1 gap" : "\(gaps) gaps",
            overlaps == 0 ? nil : overlaps == 1 ? "1 overlap" : "\(overlaps) overlaps",
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func lastNight(_ gap: StayBreak, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -1, to: gap.end) ?? gap.start
    }
}
