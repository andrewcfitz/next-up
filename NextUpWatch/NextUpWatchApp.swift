import SwiftUI
import WatchConnectivity

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
        .backgroundTask(.watchConnectivity) {
            // Stay awake until the session has delivered everything, then let apply()'s main-actor work drain.
            while WCSession.default.activationState != .activated || WCSession.default.hasContentPending {
                try? await Task.sleep(for: .milliseconds(200))
            }
            await MainActor.run {}
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.reload() }
        }
    }
}
