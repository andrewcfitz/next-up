import Foundation

enum RefreshRule {
    /// WidgetKit throttles reloads below about 15 minutes anyway.
    static let minimumMinutes = 15

    static func widgetShouldFetch(snapshotAge: TimeInterval?, refreshMinutes: Int, hasEnabledFeeds: Bool) -> Bool {
        guard hasEnabledFeeds else { return false }
        guard let snapshotAge else { return true }
        return snapshotAge >= TimeInterval(Swift.max(minimumMinutes, refreshMinutes) * 60)
    }
}
