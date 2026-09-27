import AppKit
import SwiftUI

/// The popover shown when clicking the menu bar icon.
struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private let maxLater = 5

    var body: some View {
        let stays = model.upcomingStays

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("NEXT STAY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                Spacer()
                if model.isRefreshing {
                    ProgressView().controlSize(.mini)
                } else if let fetchedAt = model.snapshot?.fetchedAt {
                    Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if let next = stays.first {
                NextStayCard(stay: next, now: model.now)
                    .padding(.horizontal, 14)

                let later = stays.dropFirst().prefix(maxLater)
                if !later.isEmpty {
                    Text("THEN")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    ForEach(later) { LaterStayRow(stay: $0, now: model.now) }
                }
            } else {
                Text(model.feeds.isEmpty
                     ? "Add your reservations calendar in Settings to get started."
                     : "No upcoming stays.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
            }

            Divider().padding(.vertical, 6).padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 0) {
                MenuButton("Refresh Now", shortcut: "r") {
                    Task { await model.refresh() }
                }
                MenuButton("Settings…", shortcut: ",") {
                    openWindow(id: SettingsView.windowID)
                    NSApp.activate()
                }
                Divider().padding(.vertical, 5).padding(.horizontal, 8)
                MenuButton("Quit Next Up", shortcut: "q") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(width: 320)
    }
}

private struct NextStayCard: View {
    var stay: Stay
    var now: Date

    var body: some View {
        let days = StayFormatting.daysUntil(stay, now: now)

        HStack(spacing: 14) {
            VStack(spacing: 0) {
                if days == 0 {
                    Text("Today").font(.title3.weight(.bold))
                } else {
                    Text("\(days)").font(.system(size: 32, weight: .bold))
                    Text(days == 1 ? "day" : "days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(stay.title).font(.headline).lineLimit(2)
                if let place = stay.place {
                    Text(place).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Text("\(StayFormatting.dates(stay)) · \(StayFormatting.nights(stay))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct LaterStayRow: View {
    var stay: Stay
    var now: Date

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(stay.title).lineLimit(1)
                Text("\(StayFormatting.dates(stay)) · \(StayFormatting.nights(stay))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(StayFormatting.countdown(stay, now: now))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

/// A full-width, menu-style button that highlights on hover.
private struct MenuButton: View {
    var title: String
    var shortcut: KeyEquivalent
    var action: () -> Void
    @State private var isHovered = false

    init(_ title: String, shortcut: KeyEquivalent, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text("⌘\(String(shortcut.character).uppercased())")
                    .foregroundStyle(isHovered ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .foregroundStyle(isHovered ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            .background(isHovered ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: .command)
        .onHover { isHovered = $0 }
    }
}
