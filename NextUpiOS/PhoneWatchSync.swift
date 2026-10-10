import Foundation
import WatchConnectivity

/// Keeps the watch's copy of the feeds and stays current. The watch has its own App Group container,
/// so it can't read the phone's.
final class PhoneWatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneWatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(feeds: [CalendarFeed], snapshot: StaySnapshot?) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = WatchPayload(feeds: feeds, snapshot: snapshot).dictionary()
        // A failed update gets retried by the next refresh.
        try? session.updateApplicationContext(payload)
        // Context waits for the watch app's next launch; this wakes it now, within a daily budget.
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }
    }

    private func sendStored() {
        send(feeds: SharedStore.feeds, snapshot: SharedStore.snapshot)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // A freshly installed watch app shouldn't wait for the next refresh.
        sendStored()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        sendStored()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched watches; the new one needs a session too.
        session.activate()
    }
}
