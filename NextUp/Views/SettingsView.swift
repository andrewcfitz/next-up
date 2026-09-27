import SwiftUI

/// The app's only window: manage feeds and a handful of preferences.
struct SettingsView: View {
    static let windowID = "settings"

    @Environment(AppModel.self) private var model
    @State private var editing: FeedEditorView.Mode?

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Calendar Feeds") {
                feedList
            }

            Section {
                Picker("Refresh every", selection: $model.settings.refreshInterval) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("3 hours").tag(180)
                }
                Picker("Menu bar shows", selection: $model.settings.menuBarStyle) {
                    ForEach(AppSettings.MenuBarStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section {
                HStack {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh Now") {
                        Task { await model.refresh() }
                    }
                    .disabled(model.isRefreshing || model.feeds.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 440, idealHeight: 540)
        .sheet(item: $editing) { mode in
            FeedEditorView(mode: mode) { feed in
                switch mode {
                case .add: model.addFeed(feed)
                case .edit: model.updateFeed(feed)
                }
            }
        }
    }

    @ViewBuilder private var feedList: some View {
        if model.feeds.isEmpty {
            Text("No feeds yet. Add the iCal (.ics) or webcal:// URL of your reservations calendar.")
                .foregroundStyle(.secondary)
        }
        ForEach(model.feeds) { feed in
            FeedRow(
                feed: feed,
                status: model.status(for: feed),
                setEnabled: { enabled in
                    var updated = feed
                    updated.isEnabled = enabled
                    model.updateFeed(updated)
                },
                edit: { editing = .edit(feed) },
                remove: { model.removeFeeds([feed.id]) }
            )
        }
        HStack {
            Spacer()
            Button("Add Feed…") { editing = .add }
        }
    }

    private var summary: String {
        let count = model.upcomingStays.count
        let stays = count == 1 ? "1 upcoming stay" : "\(count) upcoming stays"
        guard let fetchedAt = model.snapshot?.fetchedAt else { return stays }
        return "\(stays) · updated \(fetchedAt.formatted(date: .omitted, time: .shortened))"
    }
}

private struct FeedRow: View {
    var feed: CalendarFeed
    var status: FeedStatus?
    var setEnabled: (Bool) -> Void
    var edit: () -> Void
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: Binding(get: { feed.isEnabled }, set: setEnabled))
                .labelsHidden()
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 1) {
                Text(feed.name).fontWeight(.medium)
                Text(feed.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            statusLabel
            Menu {
                Button("Edit…", action: edit)
                Button("Remove", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Feed options")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Remove", role: .destructive, action: remove)
        }
    }

    @ViewBuilder private var statusLabel: some View {
        if !feed.isEnabled {
            Text("Off").font(.caption).foregroundStyle(.secondary)
        } else if let error = status?.error {
            Text(error).font(.caption).foregroundStyle(.red).help(error)
        } else if let status {
            Text(status.stayCount == 1 ? "1 stay" : "\(status.stayCount) stays")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
