import CloudKit
import Foundation
import TablesideSync
import Testing
@testable import TurnkeeperKit

@MainActor
@Suite("What iCloud refuses or takes away")
struct CampaignSyncFailureTests {
    @Test("A server version of a refused save is merged, and what's left goes up")
    func refusedSave() throws {
        let (mac, ipad) = SyncDevice.pair()
        mac.editNotes("From the Mac")
        let server = try #require(mac.upload().first)
        ipad.editNotes("From the iPad")
        let attempt = try ipad.nextAttempt()
        let error = CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
        #expect(!ipad.sync.settle([(record: attempt, error: error)]))
        #expect(ipad.encounterNames.contains("A. Signal Jammer (conflict copy)"))
        #expect(ipad.pendingCount > 0)
    }

    @Test("A full iCloud stops sending until the library changes")
    func storageFull() throws {
        let (mac, _) = SyncDevice.pair()
        mac.editNotes("Edited")
        let attempt = try mac.nextAttempt()
        _ = mac.sync.settle([(record: attempt, error: CKError(.quotaExceeded))])
        #expect(mac.pendingCount == 0)
        mac.sync.libraryChanged()
        #expect(mac.pendingCount == 1)
    }

    @Test("A missing zone sends everything again")
    func zoneMissing() throws {
        let (mac, _) = SyncDevice.pair()
        mac.editNotes("Edited")
        let attempt = try mac.nextAttempt()
        #expect(mac.sync.settle([(record: attempt, error: CKError(.zoneNotFound))]))
        #expect(mac.pendingCount == 1)
    }

    @Test("Another account starts over and keeps the library")
    func accountChange() {
        let (mac, _) = SyncDevice.pair()
        mac.sync.accountChanged(to: "first")
        #expect(mac.pendingCount == 1)
        mac.upload()
        mac.sync.accountChanged(to: "first")
        #expect(mac.pendingCount == 0)
        mac.sync.accountChanged(to: nil)
        #expect(mac.pendingCount == 0)
        mac.sync.accountChanged(to: "second")
        #expect(mac.pendingCount == 1 && mac.host.library.encounters.count == 1)
    }

    @Test("Deleting the app's iCloud data pauses syncing")
    func purged() {
        let (mac, _) = SyncDevice.pair()
        #expect(!mac.sync.zoneDeleted(CampaignRecordCoder.zone, reason: .purged))
        #expect(mac.host.isCloudSyncPaused && mac.pendingCount == 0)
    }

    @Test("A zone deleted any other way is uploaded again")
    func zoneDeleted() {
        let (mac, _) = SyncDevice.pair()
        #expect(mac.sync.zoneDeleted(CampaignRecordCoder.zone, reason: .deleted))
        #expect(mac.pendingCount == 1)
        let other = CKRecordZone.ID(zoneName: "Library", ownerName: CKCurrentUserDefaultName)
        #expect(!mac.sync.zoneDeleted(other, reason: .purged))
    }
}
