import SwiftUI

struct ContentView: View {
    @Environment(IOSAppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var editing: EditTarget?

    enum EditTarget: Identifiable {
        case add
        case edit(CalendarFeed)
        var id: String {
            switch self {
            case .add: "add"
            case .edit(let feed): feed.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.hasLoaded && model.feeds.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add your reservations calendar").font(.headline)
                            Text("Tap Add Feed and paste the iCal (.ics) or webcal:// link from your campground or booking site.")
                            Text("Then add the Next Up widget: touch and hold the Home Screen, tap Edit, then Add Widget. On the Lock Screen, touch and hold it and tap Customize.")
                        }
                        .font(.callout)
                        .padding(.vertical, 4)
                    }
                }

                if !model.feeds.isEmpty {
                    Section("Upcoming") {
                        if model.upcomingStays.isEmpty {
                            Text("No upcoming stays.").foregroundStyle(.secondary)
                        }
                        ForEach(model.upcomingStays.prefix(10)) { stay in
                            Button {
                                if let url = stay.url { openURL(url) }
                            } label: {
                                StayRow(stay: stay, now: model.now)
                            }
                            .buttonStyle(.plain)
                            .disabled(stay.url == nil)
                        }
                    }
                }

                Section("Feeds") {
                    ForEach(model.feeds) { feed in
                        FeedRow(feed: feed, status: model.status(for: feed)) { enabled in
                            model.setEnabled(feed, enabled)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = .edit(feed) }
                        .swipeActions(edge: .leading) {
                            Button("Edit") { editing = .edit(feed) }.tint(.blue)
                        }
                        .accessibilityAction(named: "Edit") { editing = .edit(feed) }
                    }
                    .onDelete { offsets in
                        model.remove(Set(offsets.map { model.feeds[$0].id }))
                    }
                    Button("Add Feed") { editing = .add }
                }

                Section {
                    Text(statusLine).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Next Up")
            .refreshable { await model.refresh() }
            .sheet(item: $editing) { target in
                switch target {
                case .add: FeedFormView(existing: nil) { model.save($0) }
                case .edit(let feed): FeedFormView(existing: feed) { model.save($0) }
                }
            }
        }
    }

    private var statusLine: String {
        guard let fetchedAt = model.snapshot?.fetchedAt else { return model.isRefreshing ? "Updating…" : "Not updated yet" }
        if model.now.timeIntervalSince(fetchedAt) < 60 { return "Updated now" }
        return "Updated \(fetchedAt.formatted(.relative(presentation: .named)))"
    }
}

private struct StayRow: View {
    var stay: Stay
    var now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stay.title).font(.headline).lineLimit(2)
                if let place = stay.place { Text(place).font(.subheadline).foregroundStyle(.secondary) }
                Text("\(StayFormatting.dates(stay)) · \(StayFormatting.nights(stay))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(StayFormatting.countdown(stay, now: now)).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

private struct FeedRow: View {
    var feed: CalendarFeed
    var status: FeedStatus?
    var setEnabled: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { feed.isEnabled }, set: setEnabled)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.name)
                Text(detail).font(.caption).foregroundStyle(status?.error == nil ? Color.secondary : Color.red).lineLimit(1)
            }
        }
    }

    private var detail: String {
        if !feed.isEnabled { return "Off" }
        if let error = status?.error { return error }
        if let status { return status.stayCount == 1 ? "1 stay" : "\(status.stayCount) stays" }
        return feed.url.host() ?? feed.url.absoluteString
    }
}
