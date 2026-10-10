import SwiftUI

struct WatchContentView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.upcomingStays.isEmpty {
                    Text(model.hasFeeds ? "No upcoming stays." : "Add a feed in Next Up on your iPhone.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.upcomingStays) { stay in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(StayFormatting.countdown(stay, now: model.now))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text(stay.title)
                            .font(.headline)
                            .lineLimit(2)
                        if let place = stay.place {
                            Text(place)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("\(StayFormatting.shortDates(stay)) · \(StayFormatting.nights(stay))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let fetchedAt = model.snapshot?.fetchedAt {
                    Text("Updated \(fetchedAt, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Next Up")
            .refreshable { await model.refresh() }
        }
    }
}
