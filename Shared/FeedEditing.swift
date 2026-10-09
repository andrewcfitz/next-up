import Foundation

extension CalendarFeed {
    /// Accepts http(s) and webcal(s) links with a host; anything else is a typo worth catching before saving.
    static func validatedURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "webcal", "webcals"].contains(scheme),
              url.host() != nil
        else { return nil }
        return url
    }

    /// A new feed, or `existing` with a new name and URL. Nil when the URL isn't valid.
    static func edited(name: String, urlText: String, from existing: CalendarFeed?) -> CalendarFeed? {
        guard let url = validatedURL(urlText) else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? (url.host() ?? "Calendar") : trimmedName
        guard var feed = existing else { return CalendarFeed(name: displayName, url: url) }
        feed.name = displayName
        feed.url = url
        return feed
    }
}

extension Array where Element == CalendarFeed {
    func upserting(_ feed: CalendarFeed) -> [CalendarFeed] {
        guard let index = firstIndex(where: { $0.id == feed.id }) else { return self + [feed] }
        var copy = self
        copy[index] = feed
        return copy
    }

    func removing(_ ids: Set<UUID>) -> [CalendarFeed] {
        filter { !ids.contains($0.id) }
    }
}
