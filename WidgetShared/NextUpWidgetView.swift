import SwiftUI
import WidgetKit

struct NextUpWidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        #if os(watchOS)
        AccessoryView(entry: entry, family: family)
        #elseif os(iOS)
        switch family {
        case .accessoryInline, .accessoryRectangular:
            AccessoryView(entry: entry, family: family)
        // WidgetKit has no "in CarPlay" flag; CarPlay and StandBy both remove the background, so that's the cue.
        case .systemSmall where !showsBackground:
            GlanceView(entry: entry)
        default:
            systemBody
        }
        #else
        systemBody
        #endif
    }

    #if !os(watchOS)
    @ViewBuilder private var systemBody: some View {
        if let next = entry.upcoming.first {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    NextStayView(stay: next, now: entry.date, showsCheckOut: true)
                        .frame(width: 150, alignment: .leading)
                        .linked(to: next.url)
                    Divider()
                    LaterStaysView(stays: Array(entry.upcoming.dropFirst().prefix(3)))
                }
            default:
                // A small widget is a single tap target.
                NextStayView(stay: next, now: entry.date, showsCheckOut: false)
                    .widgetURL(next.url)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader()
                Spacer(minLength: 0)
                Text(entry.hasFeeds ? "No upcoming stays." : "Open Next Up to add your reservations calendar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    #endif
}

#if os(iOS)
/// The small widget in CarPlay and StandBy, read at a glance from across a car or a room.
private struct GlanceView: View {
    var entry: Entry

    var body: some View {
        if let next = entry.upcoming.first {
            let countdown = StayFormatting.glance(next, now: entry.date)
            VStack(alignment: .leading, spacing: 0) {
                Text(countdown.value)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                if let unit = countdown.unit {
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(next.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                if let place = next.place {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            // CarPlay dims taps for apps without a CarPlay scene; StandBy still opens the reservation.
            .widgetURL(next.url)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "tent.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text(entry.hasFeeds ? "No stays" : "Add a feed in Next Up")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif

/// The countdown and details for the next check-in.
private struct NextStayView: View {
    var stay: Stay
    var now: Date
    var showsCheckOut: Bool

    var body: some View {
        let days = StayFormatting.daysUntil(stay, now: now)

        VStack(alignment: .leading, spacing: 2) {
            WidgetHeader()
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                switch days {
                case 0:
                    Text("Today").font(.system(size: 28, weight: .bold))
                case 1:
                    Text("Tomorrow").font(.system(size: 24, weight: .bold))
                default:
                    Text("\(days)").font(.system(size: 38, weight: .bold))
                    Text("days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            Text(stay.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
            if let place = stay.place {
                Text(place)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var detail: String {
        let dates = showsCheckOut
            ? StayFormatting.shortDates(stay)
            : stay.checkIn.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(dates) · \(StayFormatting.nights(stay))"
    }
}

/// The stays after the next one.
private struct LaterStaysView: View {
    var stays: [Stay]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("THEN")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            if stays.isEmpty {
                Text("Nothing else booked yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(stays) { stay in
                VStack(alignment: .leading, spacing: 0) {
                    Text(stay.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("\(StayFormatting.shortDates(stay)) · \(StayFormatting.nights(stay))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .linked(to: stay.url)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if os(iOS) || os(watchOS)
struct AccessoryView: View {
    var entry: Entry
    var family: WidgetFamily

    var body: some View {
        let next = entry.upcoming.first
        switch family {
        #if os(watchOS)
        case .accessoryCircular, .accessoryCorner:
            CountdownComplication(stay: next, now: entry.date, family: family)
        #endif
        case .accessoryInline:
            Text(next.map { StayFormatting.inline($0, now: entry.date) } ?? emptyText)
        default:
            if let next {
                let lines = StayFormatting.rectangularLines(next, now: entry.date)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .font(index == 0 ? .headline : .caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(next.url)
            } else {
                Text(emptyText)
            }
        }
    }

    private var emptyText: String {
        #if os(watchOS)
        return entry.hasFeeds ? "No upcoming stays" : "Add a feed in Next Up on iPhone"
        #else
        return entry.hasFeeds ? "No upcoming stays" : "Add a feed in Next Up"
        #endif
    }
}
#endif

#if os(watchOS)
/// Circular and corner faces have room for a number; corner faces also curve the stay along the bezel.
private struct CountdownComplication: View {
    var stay: Stay?
    var now: Date
    var family: WidgetFamily

    var body: some View {
        if let stay, family == .accessoryCorner {
            Text(StayFormatting.circular(stay, now: now))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.5)
                .widgetCurvesContent()
                .widgetLabel(StayFormatting.inline(stay, now: now))
        } else if let stay {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "tent.fill")
                        .font(.caption)
                        .widgetAccentable()
                    Text(StayFormatting.circular(stay, now: now))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(4)
            }
        } else if family == .accessoryCorner {
            Image(systemName: "tent.fill")
                .font(.title3)
                .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "tent.fill")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }
}
#endif

private struct WidgetHeader: View {
    var body: some View {
        Label("NEXT STAY", systemImage: "tent")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tint)
            .imageScale(.small)
    }
}

private extension View {
    /// Wraps the view in a `Link` when there's a URL, so tapping it opens the reservation.
    @ViewBuilder func linked(to url: URL?) -> some View {
        if let url {
            // Keep the text colors; a Link would otherwise tint its label with the accent color.
            Link(destination: url) { self.foregroundStyle(.primary) }
        } else {
            self
        }
    }
}
