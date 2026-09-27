import SwiftUI

/// Sheet for adding a new feed or editing an existing one.
struct FeedEditorView: View {
    enum Mode: Identifiable {
        case add
        case edit(CalendarFeed)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let feed): feed.id.uuidString
            }
        }
    }

    var mode: Mode
    var onSave: (CalendarFeed) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlString: String

    init(mode: Mode, onSave: @escaping (CalendarFeed) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _urlString = State(initialValue: "")
        case .edit(let feed):
            _name = State(initialValue: feed.name)
            _urlString = State(initialValue: feed.url.absoluteString)
        }
    }

    private var url: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "webcal", "webcals"].contains(scheme),
              url.host() != nil
        else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isAdding ? "Add Calendar Feed" : "Edit Calendar Feed").font(.headline)

            Form {
                TextField("Name", text: $name, prompt: Text("Campground Reservations"))
                TextField("URL", text: $urlString, prompt: Text("webcal://… or https://….ics"))
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isAdding ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url == nil)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var isAdding: Bool {
        if case .add = mode { true } else { false }
    }

    private func save() {
        guard let url else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? (url.host() ?? "Calendar") : trimmedName

        var feed: CalendarFeed
        if case .edit(let existing) = mode {
            feed = existing
            feed.name = displayName
            feed.url = url
        } else {
            feed = CalendarFeed(name: displayName, url: url)
        }
        onSave(feed)
        dismiss()
    }
}
