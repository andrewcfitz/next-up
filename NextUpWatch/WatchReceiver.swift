import Foundation
import WatchConnectivity
import WidgetKit

/// Stores what the iPhone sends where the complication's provider reads it.
final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchReceiver()

    /// Lets the open app redraw when new data lands.
    @MainActor var onUpdate: (@MainActor () -> Void)?

    func activate() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Picks up context that arrived while the app wasn't running.
        if activationState == .activated { apply(session.receivedApplicationContext) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }

    private func apply(_ dictionary: [String: Any]) {
        guard let payload = WatchPayload(dictionary: dictionary) else { return }
        SharedStore.feeds = payload.feeds
        SharedStore.snapshot = WatchPayload.newer(payload.snapshot, than: SharedStore.snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor in self.onUpdate?() }
    }
}
