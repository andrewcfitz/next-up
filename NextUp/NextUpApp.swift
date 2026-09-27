import AppKit
import SwiftUI

@main
struct NextUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Next Up", id: SettingsView.windowID) {
            SettingsView()
                .environment(model)
        }
        .windowResizability(.contentMinSize)
        // Next Up lives in the menu bar; only show settings on launch until a feed is set up.
        .defaultLaunchBehavior(model.feeds.isEmpty ? .presented : .suppressed)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep running in the menu bar after the settings window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// The title shown in the menu bar, controlled by the "Menu bar shows" setting.
struct MenuBarLabel: View {
    var model: AppModel

    var body: some View {
        let icon = Image(systemName: "tent")
        switch (model.settings.menuBarStyle, model.nextStay) {
        case (.nextStay, let stay?):
            Text("\(icon) \(truncated(stay.title)) · \(StayFormatting.shortCountdown(stay, now: model.now))")
        case (.daysUntil, let stay?):
            Text("\(icon) \(StayFormatting.shortCountdown(stay, now: model.now))")
        default:
            icon
        }
    }

    private func truncated(_ title: String, limit: Int = 24) -> String {
        title.count > limit ? String(title.prefix(limit - 1)) + "…" : title
    }
}
