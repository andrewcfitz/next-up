import SwiftUI

struct FeedFormView: View {
    var existing: CalendarFeed?
    var onSave: (CalendarFeed) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlText: String

    init(existing: CalendarFeed?, onSave: @escaping (CalendarFeed) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _urlText = State(initialValue: existing?.url.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("Campground Reservations"))
                TextField("URL", text: $urlText, prompt: Text("webcal://… or https://….ics"))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle(existing == nil ? "Add Feed" : "Edit Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let feed = CalendarFeed.edited(name: name, urlText: urlText, from: existing) {
                            onSave(feed)
                            dismiss()
                        }
                    }
                    .disabled(CalendarFeed.validatedURL(urlText) == nil)
                }
            }
        }
    }
}
