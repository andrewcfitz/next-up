import Foundation
import Testing

struct SharedStoreTests {
    @Test func readsTheGroupFromInfoPlist() {
        #expect(SharedStore.groupID(infoDictionary: ["NextUpAppGroup": "group.biz.fitz.NextUp"]) == "group.biz.fitz.NextUp")
    }

    @Test func rejectsMissingEmptyOrUnexpandedGroups() {
        #expect(SharedStore.groupID(infoDictionary: nil) == nil)
        #expect(SharedStore.groupID(infoDictionary: [:]) == nil)
        #expect(SharedStore.groupID(infoDictionary: ["NextUpAppGroup": ""]) == nil)
        #expect(SharedStore.groupID(infoDictionary: ["NextUpAppGroup": "$(NEXTUP_APP_GROUP)"]) == nil)
    }
}
