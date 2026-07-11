//
//  LoomTrustStoreTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/10/26.
//

@testable import Loom
import Foundation
import Testing

@Suite("Loom Trust Store", .serialized)
struct LoomTrustStoreTests {
    @MainActor
    @Test("Trust store only matches the exact authenticated peer identity")
    func trustStoreMatchesExactIdentity() throws {
        let suiteName = "com.ethanlipnik.loom.tests.trust.\(UUID().uuidString)"
        defer {
            clearSuite(named: suiteName)
        }

        let deviceID = UUID()
        let trustedPeer = try makePeerIdentity(deviceID: deviceID)
        let rotatedPeer = try makePeerIdentity(deviceID: deviceID)

        let store = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )
        store.addTrustedDevice(try LoomTrustedDevice(peerIdentity: trustedPeer, trustedAt: .distantPast))

        #expect(store.isTrusted(peerIdentity: trustedPeer))
        #expect(!store.isTrusted(peerIdentity: rotatedPeer))
        #expect(store.trustedDevices.count == 1)
        let trustedDevice = try #require(store.trustedDevices.first)
        #expect(trustedDevice.identityKeyID == trustedPeer.identityKeyID)
        #expect(trustedDevice.identityPublicKey == trustedPeer.identityPublicKey)
    }

    @MainActor
    @Test("Trust store persists through a shared suite and reloads deduplicated state")
    func trustStorePersistsThroughSharedSuite() throws {
        let suiteName = "com.ethanlipnik.loom.tests.shared-trust.\(UUID().uuidString)"
        defer {
            clearSuite(named: suiteName)
        }

        let peer = try makePeerIdentity(deviceID: UUID())
        let firstStore = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )
        firstStore.addTrustedDevice(try LoomTrustedDevice(peerIdentity: peer, trustedAt: Date()))

        let secondStore = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )
        #expect(secondStore.isTrusted(peerIdentity: peer))
        #expect(secondStore.trustedDevices.count == 1)

        secondStore.revokeTrust(for: peer.deviceID)

        let thirdStore = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )
        #expect(!thirdStore.isTrusted(peerIdentity: peer))
        #expect(thirdStore.trustedDevices.isEmpty)
    }

    @MainActor
    @Test("Old device-ID-only trust records are invalidated on load")
    func oldTrustStoreFormatDoesNotAutoTrust() throws {
        let suiteName = "com.ethanlipnik.loom.tests.legacy-trust.\(UUID().uuidString)"
        defer {
            clearSuite(named: suiteName)
        }

        let deviceID = UUID()
        let defaults = UserDefaults(suiteName: suiteName)!
        let legacyRecord = LegacyTrustedDevice(
            id: deviceID,
            name: "Legacy Mac",
            deviceType: .mac,
            trustedAt: Date()
        )
        let encodedLegacy = try JSONEncoder().encode([legacyRecord])
        defaults.set(encodedLegacy, forKey: "TrustedDevices")

        let store = LoomTrustStore(
            storageKey: "TrustedDevices",
            suiteName: suiteName
        )

        #expect(store.trustedDevices.isEmpty)
        #expect(!store.isTrusted(deviceID: deviceID))
    }

    private func clearSuite(named suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func makePeerIdentity(deviceID: UUID) throws -> LoomPeerIdentity {
        let identityManager = LoomIdentityManager(
            service: "com.ethanlipnik.loom.tests.trust-store.\(UUID().uuidString)",
            account: "p256-signing",
            synchronizable: false
        )
        let identity = try identityManager.currentIdentity()
        return LoomPeerIdentity(
            deviceID: deviceID,
            name: "Trusted Mac",
            deviceType: .mac,
            iCloudUserID: nil,
            identityKeyID: identity.keyID,
            identityPublicKey: identity.publicKey,
            isIdentityAuthenticated: true,
            endpoint: "127.0.0.1:22"
        )
    }
}

private struct LegacyTrustedDevice: Codable {
    let id: UUID
    let name: String
    let deviceType: DeviceType
    let trustedAt: Date
}
