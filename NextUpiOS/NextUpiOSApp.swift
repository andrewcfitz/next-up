import SwiftUI

@main
struct NextUpiOSApp: App {
    @State private var model = IOSAppModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                // Widget taps arrive here; reservation pages belong in Safari, as on the Mac.
                .onOpenURL { url in
                    if ["http", "https"].contains(url.scheme?.lowercased()) { openURL(url) }
                }
        }
        // initial: true, or a cold launch never refreshes (found on Next Game).
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: Task { await model.becameActive() }
            case .background: model.scheduleBackgroundRefresh()
            default: break
            }
        }
        .backgroundTask(.appRefresh(IOSAppModel.refreshTaskID)) {
            await model.backgroundRefresh()
        }
    }
}
