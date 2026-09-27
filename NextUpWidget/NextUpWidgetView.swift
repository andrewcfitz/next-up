import SwiftUI
import WidgetKit

struct NextUpWidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let next = entry.upcoming.first {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    NextStayView(stay: next, now: entry.date, showsCheckOut: true)
                        .frame(width: 150, alignment: .leading)
                    Divider()
                    LaterStaysView(stays: Array(entry.upcoming.dropFirst().prefix(3)))
                }
            default:
                NextStayView(stay: next, now: entry.date, showsCheckOut: false)
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
}

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
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetHeader: View {
    var body: some View {
        Label("NEXT STAY", systemImage: "tent")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tint)
            .imageScale(.small)
    }
}
