//
//  LoomLocalTrustProviderTests.swift
//  LoomKitTests
//
//  Created by Ethan Lipnik on 3/10/26.
//

@testable import Loom
@testable import LoomKit
import Foundation
import Testing

@Suite("Loom Local Trust Provider", .serialized)
struct LoomLocalTrustProviderTests {
    @MainActor
    @Test("Locally trusted peers require an exact authenticated identity match")
    func locallyTrustedPeersRequireExactIdentityMatch() async throws {
        let suiteName = "com.ethanlipnik.loom.tests.local-trust.\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }

        let trustedPeer = try makePeerIdentity(deviceID: UUID())
        let rotatedPeer = try makePeerIdentity(deviceID: trustedPeer.deviceID)

        let trustStore = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )
        trustStore.addTrustedDevice(
            try LoomTrustedDevice(peerIdentity: trustedPeer, trustedAt: Date())
        )
        let provider = LoomLocalTrustProvider(trustStore: trustStore)

        let trustedOutcome = await provider.evaluateTrustOutcome(for: trustedPeer)
        let rotatedOutcome = await provider.evaluateTrustOutcome(for: rotatedPeer)

        #expect(trustedOutcome.decision == .trusted)
        #expect(rotatedOutcome.decision == .requiresApproval)
    }

    @MainActor
    @Test("Local trust provider denies unauthenticated peers")
    func localTrustProviderDeniesUnauthenticatedPeers() async throws {
        let provider = LoomLocalTrustProvider(
            trustStore: LoomTrustStore(storageKey: "TrustedDevices", suiteName: UUID().uuidString)
        )
        let unauthenticatedPeer = LoomPeerIdentity(
            deviceID: UUID(),
            name: "Unknown",
            deviceType: .mac,
            iCloudUserID: nil,
            identityKeyID: nil,
            identityPublicKey: nil,
            isIdentityAuthenticated: false,
            endpoint: "127.0.0.1:22"
        )

        let outcome = await provider.evaluateTrustOutcome(for: unauthenticatedPeer)

        #expect(outcome.decision == .denied)
    }

    @MainActor
    private func makePeerIdentity(deviceID: UUID) throws -> LoomPeerIdentity {
        let identityManager = LoomIdentityManager(
            service: "com.ethanlipnik.loom.tests.local-trust-provider.\(UUID().uuidString)",
            account: "p256-signing",
            synchronizable: false
        )
        let identity = try identityManager.currentIdentity()
        return LoomPeerIdentity(
            deviceID: deviceID,
            name: "Peer Mac",
            deviceType: .mac,
            iCloudUserID: nil,
            identityKeyID: identity.keyID,
            identityPublicKey: identity.publicKey,
            isIdentityAuthenticated: true,
            endpoint: "127.0.0.1:22"
        )
    }
}
