import Foundation
import Testing
@testable import TurnkeeperKit

@MainActor
@Suite("An app ended right after a change arrives")
struct CampaignSyncRestartTests {
    @Test("The change survives a restart, and the old copy isn't sent back")
    func restartKeepsReceivedChange() {
        let (mac, ipad) = SyncDevice.pair()
        var renamed = mac.host.library.encounters[0]
        renamed.name = "B. Renamed"
        mac.host.library.save(renamed)

        ipad.download(mac.upload())

        let restarted = FakeSyncHost()
        restarted.library = ipad.host.savedLibrary
        let sync = CampaignSync(host: restarted, folder: ipad.folder)
        #expect(restarted.library.encounters.map(\.name) == ["B. Renamed"])
        #expect(sync.pendingChanges().isEmpty)
    }
}
