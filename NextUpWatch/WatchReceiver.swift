import Foundation
import WatchConnectivity
import WidgetKit

/// Stores what the iPhone sends where the complication's provider reads it.
final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchReceiver()
    private static let lastSentAtKey = "lastPayloadSentAt"

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
        // On the main actor so the read-then-write of the snapshot can't interleave with the model's refresh.
        Task { @MainActor in
            let lastApplied = UserDefaults.standard.object(forKey: Self.lastSentAtKey) as? Date
            guard let merged = payload.merged(currentFeeds: SharedStore.feeds, currentSnapshot: SharedStore.snapshot, lastAppliedAt: lastApplied) else { return }
            UserDefaults.standard.set(payload.sentAt, forKey: Self.lastSentAtKey)
            SharedStore.feeds = merged.feeds
            SharedStore.snapshot = merged.snapshot
            WidgetCenter.shared.reloadAllTimelines()
            onUpdate?()
        }
    }
}
