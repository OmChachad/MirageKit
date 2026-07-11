import Foundation
import Testing
@testable import Loom

@Suite("Loom Host Catalog")
struct LoomHostCatalogTests {
    @Test("Source and target app IDs round-trip independently through metadata")
    func sourceAndTargetAppIDsRoundTripIndependently() {
        var metadata: [String: String] = [:]
        metadata = LoomHostCatalogCodec.addingTargetAppID(
            "com.example.target",
            to: metadata
        )
        metadata = LoomHostCatalogCodec.addingSourceAppID(
            "com.example.source",
            to: metadata
        )

        let advertisement = LoomPeerAdvertisement(
            deviceID: UUID(),
            deviceType: .mac,
            metadata: metadata
        )

        #expect(
            LoomHostCatalogCodec.targetAppID(from: advertisement) == "com.example.target"
        )
        #expect(
            LoomHostCatalogCodec.sourceAppID(from: advertisement) == "com.example.source"
        )
    }

    @Test("Clearing source app ID preserves target app routing metadata")
    func clearingSourceAppIDPreservesTargetAppRoutingMetadata() {
        var metadata = LoomHostCatalogCodec.addingTargetAppID(
            "com.example.target",
            to: [:]
        )
        metadata = LoomHostCatalogCodec.addingSourceAppID(
            "com.example.source",
            to: metadata
        )
        metadata = LoomHostCatalogCodec.addingSourceAppID(nil, to: metadata)

        let advertisement = LoomPeerAdvertisement(
            deviceID: UUID(),
            deviceType: .mac,
            metadata: metadata
        )

        #expect(
            LoomHostCatalogCodec.targetAppID(from: advertisement) == "com.example.target"
        )
        #expect(LoomHostCatalogCodec.sourceAppID(from: advertisement) == nil)
    }
}
