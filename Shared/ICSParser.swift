import Foundation

/// A small iCalendar (RFC 5545) parser that extracts campground stays.
///
/// A stay is an all-day event (`VALUE=DATE`, or Outlook's `X-MICROSOFT-CDO-ALLDAYEVENT`),
/// or a timed event that spans at least one night. It understands line folding and text
/// escaping. Same-day timed events and cancelled events are ignored, and recurrence rules
/// aren't expanded (reservations don't repeat).
struct ICSParser {
    var calendar: Calendar = .current

    /// Parses `ics` and returns the stays that check in within `range`.
    func stays(from ics: String, checkingInWithin range: DateInterval, feed: CalendarFeed? = nil) -> [Stay] {
        Self.parseComponents(ics)
            .filter { $0.name == "VEVENT" }
            .compactMap { makeStay($0, feed: feed) }
            .filter { range.start <= $0.checkIn && $0.checkIn < range.end }
            .sorted { ($0.checkIn, $0.title) < ($1.checkIn, $1.title) }
    }

    private func makeStay(_ event: Component, feed: CalendarFeed?) -> Stay? {
        guard let startProperty = event.first("DTSTART"),
              let start = ICSDate.parse(startProperty, calendar: calendar),
              event.first("STATUS")?.value.uppercased() != "CANCELLED"
        else { return nil }

        let microsoftAllDay = event.first("X-MICROSOFT-CDO-ALLDAYEVENT")?.value.uppercased() == "TRUE"
        let isAllDay = start.isDateOnly || microsoftAllDay
        let checkIn = calendar.startOfDay(for: start.date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: checkIn)!

        var checkOut: Date
        if let endProperty = event.first("DTEND"), let end = ICSDate.parse(endProperty, calendar: calendar) {
            checkOut = calendar.startOfDay(for: end.date)
        } else if let duration = event.first("DURATION"), let seconds = ICSDate.durationSeconds(duration.value) {
            checkOut = calendar.startOfDay(for: calendar.date(byAdding: .second, value: seconds, to: start.date)!)
        } else {
            // An all-day event with no end lasts one day; a timed one is just a moment.
            checkOut = isAllDay ? nextDay : checkIn
        }

        if isAllDay {
            checkOut = max(checkOut, nextDay)
        } else if checkOut <= checkIn {
            // A timed event only counts as a stay if it runs past midnight,
            // e.g. check-in at 2 PM Friday, check-out at 11 AM Monday.
            return nil
        }

        let uid = event.first("UID")?.value ?? UUID().uuidString
        let location = event.first("LOCATION").flatMap { Self.cleanAddress(Self.unescape($0.value)) }
        return Stay(
            id: "\(feed?.id.uuidString ?? "local")|\(uid)|\(ICSDate.dayStamp(checkIn, calendar: calendar))",
            title: Self.unescape(event.first("SUMMARY")?.value ?? "Untitled"),
            checkIn: checkIn,
            checkOut: checkOut,
            location: location,
            feedID: feed?.id,
            feedName: feed?.name
        )
    }

    // MARK: - Content lines

    struct Property {
        var name: String
        var params: [String: String]
        var value: String
    }

    struct Component {
        var name: String
        var properties: [Property] = []

        func first(_ name: String) -> Property? {
            properties.first { $0.name == name }
        }
    }

    /// Unfolds lines and groups properties by their innermost component.
    /// Nested components (e.g. `VALARM` inside `VEVENT`) are kept separate.
    static func parseComponents(_ ics: String) -> [Component] {
        var stack: [Component] = []
        var finished: [Component] = []

        for line in unfold(ics) {
            guard let property = parseLine(line) else { continue }
            switch property.name {
            case "BEGIN":
                stack.append(Component(name: property.value.uppercased()))
            case "END":
                if let component = stack.popLast() { finished.append(component) }
            default:
                if !stack.isEmpty { stack[stack.count - 1].properties.append(property) }
            }
        }
        return finished
    }

    static func unfold(_ ics: String) -> [String] {
        var lines: [String] = []
        // Split on any newline style; "\r\n" is a single Character in Swift.
        for raw in ics.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if let first = raw.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += raw.dropFirst()
            } else {
                lines.append(String(raw))
            }
        }
        return lines.filter { !$0.isEmpty }
    }

    static func parseLine(_ line: String) -> Property? {
        // The value starts at the first colon that isn't inside a quoted parameter.
        var inQuotes = false
        var colonIndex: String.Index?
        for index in line.indices {
            let character = line[index]
            if character == "\"" { inQuotes.toggle() }
            if character == ":" && !inQuotes {
                colonIndex = index
                break
            }
        }
        guard let colonIndex else { return nil }

        let head = line[..<colonIndex]
        let value = String(line[line.index(after: colonIndex)...])
        let parts = head.split(separator: ";", omittingEmptySubsequences: true)
        guard let rawName = parts.first else { return nil }

        var params: [String: String] = [:]
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            params[pair[0].uppercased()] = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return Property(name: rawName.uppercased(), params: params, value: value)
    }

    /// Trims each line of a multi-line address and drops blank or punctuation-only lines.
    /// Some feeds send an empty address template like "\n, \n\n"; that becomes `nil`.
    static func cleanAddress(_ text: String) -> String? {
        let junk = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;"))
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: junk) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            guard character == "\\", let next = iterator.next() else {
                result.append(character)
                continue
            }
            switch next {
            case "n", "N": result.append("\n")
            default: result.append(next)
            }
        }
        return result
    }
}

// MARK: - Dates

enum ICSDate {
    struct Parsed {
        var date: Date
        var isDateOnly: Bool
    }

    static func parse(_ property: ICSParser.Property, calendar: Calendar) -> Parsed? {
        let value = property.value.trimmingCharacters(in: .whitespaces)
        let digits = value.filter(\.isNumber)

        // All-day: YYYYMMDD, interpreted in the user's calendar.
        if property.params["VALUE"]?.uppercased() == "DATE" || (value.count == 8 && digits.count == 8) {
            guard digits.count >= 8,
                  let year = Int(digits.prefix(4)),
                  let month = Int(digits.dropFirst(4).prefix(2)),
                  let day = Int(digits.dropFirst(6).prefix(2)),
                  let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
            else { return nil }
            return Parsed(date: date, isDateOnly: true)
        }

        // Date-time: YYYYMMDDTHHMMSS[Z]
        guard digits.count >= 14,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2)),
              let hour = Int(digits.dropFirst(8).prefix(2)),
              let minute = Int(digits.dropFirst(10).prefix(2)),
              let second = Int(digits.dropFirst(12).prefix(2))
        else { return nil }

        var source = calendar
        if value.hasSuffix("Z") {
            source.timeZone = TimeZone(identifier: "UTC")!
        } else if let tzid = property.params["TZID"], let zone = timeZone(tzid) {
            source.timeZone = zone
        }
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let date = source.date(from: components) else { return nil }
        return Parsed(date: date, isDateOnly: false)
    }

    /// Resolves a `TZID`, including the Windows names that Outlook and .NET feeds use
    /// (e.g. "Central Standard Time"), which `TimeZone(identifier:)` doesn't know.
    static func timeZone(_ tzid: String) -> TimeZone? {
        TimeZone(identifier: tzid) ?? windowsTimeZones[tzid].flatMap(TimeZone.init(identifier:))
    }

    private static let windowsTimeZones: [String: String] = [
        "Eastern Standard Time": "America/New_York",
        "US Eastern Standard Time": "America/Indiana/Indianapolis",
        "Central Standard Time": "America/Chicago",
        "Mountain Standard Time": "America/Denver",
        "US Mountain Standard Time": "America/Phoenix",
        "Pacific Standard Time": "America/Los_Angeles",
        "Alaskan Standard Time": "America/Anchorage",
        "Hawaiian Standard Time": "Pacific/Honolulu",
        "Atlantic Standard Time": "America/Halifax",
        "Newfoundland Standard Time": "America/St_Johns",
        "Canada Central Standard Time": "America/Regina",
        "Central Standard Time (Mexico)": "America/Mexico_City",
        "Mountain Standard Time (Mexico)": "America/Mazatlan",
        "Pacific Standard Time (Mexico)": "America/Tijuana",
    ]

    /// Total seconds in an iCal `DURATION` such as `P1D`, `P2W` or `PT24H`.
    static func durationSeconds(_ value: String) -> Int? {
        var seconds = 0
        var number = ""
        var inTime = false
        for character in value.uppercased() {
            if character.isNumber {
                number.append(character)
                continue
            }
            let amount = Int(number) ?? 0
            number = ""
            switch character {
            case "T": inTime = true
            case "W": seconds += amount * 7 * 86_400
            case "D": seconds += amount * 86_400
            case "H" where inTime: seconds += amount * 3600
            case "M" where inTime: seconds += amount * 60
            case "S" where inTime: seconds += amount
            default: break
            }
        }
        return seconds > 0 ? seconds : nil
    }

    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
