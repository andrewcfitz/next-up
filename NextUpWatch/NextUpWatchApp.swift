import SwiftUI

@main
struct NextUpWatchApp: App {
    @State private var model = WatchAppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before any UI: a background launch from a complication transfer delivers only once a session is active.
        WatchReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(model)
                .onAppear { WatchReceiver.shared.onUpdate = { [model] in model.reload() } }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.reload() }
        }
    }
}
