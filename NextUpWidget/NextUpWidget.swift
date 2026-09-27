import SwiftUI
import WidgetKit

@main
struct NextUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextUpWidget()
    }
}

struct NextUpWidget: Widget {
    let kind = "NextUpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NextUpWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Next Stay")
        .description("Counts down to your next campground check-in.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    var date: Date
    var stays: [Stay]
    var hasFeeds: Bool

    /// Stays that haven't started as of this entry's date, soonest first.
    var upcoming: [Stay] { stays.upcoming(from: date) }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview, SharedStore.snapshot == nil {
            completion(.sample)
        } else {
            completion(entry(from: SharedStore.snapshot, at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let snapshot = await loadSnapshot()
            let now = Date.now
            let calendar = Calendar.current

            // One entry now, plus one at each of the next few midnights so the
            // countdown ticks down even if we can't refresh.
            var entries = [entry(from: snapshot, at: now)]
            var day = calendar.startOfDay(for: now)
            for _ in 0..<3 {
                day = calendar.date(byAdding: .day, value: 1, to: day)!
                entries.append(entry(from: snapshot, at: day))
            }

            let interval = TimeInterval(max(SharedStore.settings.refreshInterval, 15) * 60)
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(interval))))
        }
    }

    /// Uses the app's cached stays when they're fresh, otherwise fetches the feeds directly.
    private func loadSnapshot() async -> StaySnapshot? {
        let cached = SharedStore.snapshot
        let feeds = SharedStore.feeds
        let maxAge = TimeInterval(SharedStore.settings.refreshInterval * 60)

        if let cached, Date.now.timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached
        }
        guard feeds.contains(where: \.isEnabled) else { return cached }

        let fresh = await FeedService().fetch(feeds, previous: cached)
        SharedStore.snapshot = fresh
        return fresh
    }

    private func entry(from snapshot: StaySnapshot?, at date: Date) -> Entry {
        Entry(date: date, stays: snapshot?.stays ?? [], hasFeeds: !SharedStore.feeds.isEmpty)
    }
}

// MARK: - Sample data

extension Entry {
    static var sample: Entry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func stay(_ title: String, _ location: String, _ start: Int, _ nights: Int) -> Stay {
            let checkIn = calendar.date(byAdding: .day, value: start, to: today)!
            let checkOut = calendar.date(byAdding: .day, value: nights, to: checkIn)!
            return Stay(id: title, title: title, checkIn: checkIn, checkOut: checkOut, location: location)
        }
        return Entry(
            date: .now,
            stays: [
                stay("Pine Hollow RV Resort", "Moab, UT", 5, 3),
                stay("Lakeside State Park", "Site 42", 8, 7),
                stay("Desert Sky Campground", "Page, AZ", 15, 7),
                stay("Red Canyon KOA", "Panguitch, UT", 22, 4),
            ],
            hasFeeds: true
        )
    }
}

#Preview(as: .systemSmall) {
    NextUpWidget()
} timeline: {
    Entry.sample
}

#Preview(as: .systemMedium) {
    NextUpWidget()
} timeline: {
    Entry.sample
}
