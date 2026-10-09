import Foundation
import Testing

struct RefreshRuleTests {
    @Test func nothingToFetchWithoutEnabledFeeds() {
        #expect(!RefreshRule.widgetShouldFetch(snapshotAge: nil, refreshMinutes: 60, hasEnabledFeeds: false))
    }

    @Test func fetchesWithoutASnapshot() {
        #expect(RefreshRule.widgetShouldFetch(snapshotAge: nil, refreshMinutes: 60, hasEnabledFeeds: true))
    }

    @Test func followsTheRefreshInterval() {
        #expect(!RefreshRule.widgetShouldFetch(snapshotAge: 59 * 60, refreshMinutes: 60, hasEnabledFeeds: true))
        #expect(RefreshRule.widgetShouldFetch(snapshotAge: 60 * 60, refreshMinutes: 60, hasEnabledFeeds: true))
    }

    @Test func neverMoreOftenThanFifteenMinutes() {
        #expect(!RefreshRule.widgetShouldFetch(snapshotAge: 14 * 60, refreshMinutes: 5, hasEnabledFeeds: true))
        #expect(RefreshRule.widgetShouldFetch(snapshotAge: 15 * 60, refreshMinutes: 5, hasEnabledFeeds: true))
    }
}
