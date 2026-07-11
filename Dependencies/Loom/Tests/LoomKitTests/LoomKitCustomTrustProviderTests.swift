//
//  LoomKitCustomTrustProviderTests.swift
//  Loom
//
//  Created by Codex on 4/16/26.
//

@testable import Loom
@testable import LoomKit
import Foundation
import Testing

@Suite("LoomKit Custom Trust Provider")
struct LoomKitCustomTrustProviderTests {
    @MainActor
    @Test("Container preserves an app-provided trust provider")
    func containerPreservesCustomTrustProvider() async throws {
        let provider = PreviewSessionTrustProvider(
            sessionID: "preview-session",
            expectedRole: "companion"
        )

        let container = try LoomContainer(
            for: LoomContainerConfiguration(
                serviceName: "Preview Host",
                trustProvider: provider
            )
        )

        let storedProvider = try #require(container.configuration.trustProvider)
        let outcome = await storedProvider.evaluateTrustOutcome(
            for: makePeer(
                sessionID: "preview-session",
                role: "companion",
                authenticated: true
            )
        )
        #expect(outcome.decision == .trusted)
    }

    @MainActor
    @Test("Session-token trust accepts only authenticated matching preview peers")
    func sessionTokenTrustAcceptsOnlyMatchingPreviewPeers() async {
        let provider = PreviewSessionTrustProvider(
            sessionID: "preview-session",
            expectedRole: "companion"
        )

        let accepted = await provider.evaluateTrustOutcome(
            for: makePeer(
                sessionID: "preview-session",
                role: "companion",
                authenticated: true
            )
        )
        let wrongSession = await provider.evaluateTrustOutcome(
            for: makePeer(
                sessionID: "other-session",
                role: "companion",
                authenticated: true
            )
        )
        let wrongRole = await provider.evaluateTrustOutcome(
            for: makePeer(
                sessionID: "preview-session",
                role: "host",
                authenticated: true
            )
        )
        let unauthenticated = await provider.evaluateTrustOutcome(
            for: makePeer(
                sessionID: "preview-session",
                role: "companion",
                authenticated: false
            )
        )

        #expect(accepted.decision == .trusted)
        #expect(wrongSession.decision == .denied)
        #expect(wrongRole.decision == .denied)
        #expect(unauthenticated.decision == .denied)
    }

    @Test("Fallback connected peer preserves session hello advertisement metadata")
    func fallbackConnectedPeerPreservesSessionHelloAdvertisementMetadata() {
        let deviceID = UUID()
        let advertisement = LoomPeerAdvertisement(
            deviceID: deviceID,
            identityKeyID: "identity-key",
            deviceType: .iPhone,
            modelIdentifier: "iPhone17,1",
            iconName: "iphone",
            machineFamily: "iPhone",
            hostName: "preview.local",
            directTransports: [
                LoomDirectTransportAdvertisement(transportKind: .tcp, port: 53007)
            ],
            metadata: [
                "vinci.app": "vinci",
                "vinci.sync.kind": "simulator-preview",
                "vinci.preview.session": "preview-session",
                "vinci.preview.role": "companion"
            ]
        )
        let context = LoomAuthenticatedSessionContext(
            peerIdentity: LoomPeerIdentity(
                deviceID: deviceID,
                name: "Vinci Companion",
                deviceType: .iPhone,
                iCloudUserID: nil,
                identityKeyID: "identity-key",
                identityPublicKey: Data("key".utf8),
                isIdentityAuthenticated: true,
                advertisementMetadata: advertisement.metadata,
                endpoint: "127.0.0.1"
            ),
            peerAdvertisement: advertisement,
            trustEvaluation: LoomTrustEvaluation(decision: .trusted, shouldShowAutoTrustNotice: false),
            transportKind: .tcp,
            negotiatedFeatures: LoomSessionHelloRequest.defaultFeatures
        )

        let snapshot = LoomStore.fallbackPeerSnapshot(
            from: context,
            signalingSessionID: nil
        )

        #expect(snapshot.id == deviceID)
        #expect(snapshot.name == "Vinci Companion")
        #expect(snapshot.advertisement.metadata["vinci.preview.session"] == "preview-session")
        #expect(snapshot.advertisement.metadata["vinci.preview.role"] == "companion")
        #expect(snapshot.advertisement.directTransports.map(\.port) == [53007])
        #expect(snapshot.advertisement.identityKeyID == "identity-key")
        #expect(snapshot.advertisement.modelIdentifier == "iPhone17,1")
    }

    private func makePeer(
        sessionID: String,
        role: String,
        authenticated: Bool
    ) -> LoomPeerIdentity {
        LoomPeerIdentity(
            deviceID: UUID(),
            name: "Preview Peer",
            deviceType: .iPhone,
            iCloudUserID: nil,
            identityKeyID: authenticated ? "key" : nil,
            identityPublicKey: authenticated ? Data("key".utf8) : nil,
            isIdentityAuthenticated: authenticated,
            advertisementMetadata: [
                "vinci.app": "vinci",
                "vinci.sync.kind": "simulator-preview",
                "vinci.preview.session": sessionID,
                "vinci.preview.role": role
            ],
            endpoint: "127.0.0.1"
        )
    }
}

@MainActor
private final class PreviewSessionTrustProvider: LoomTrustProvider {
    private let sessionID: String
    private let expectedRole: String

    init(sessionID: String, expectedRole: String) {
        self.sessionID = sessionID
        self.expectedRole = expectedRole
    }

    func evaluateTrust(for peer: LoomPeerIdentity) async -> LoomTrustDecision {
        await evaluateTrustOutcome(for: peer).decision
    }

    func evaluateTrustOutcome(for peer: LoomPeerIdentity) async -> LoomTrustEvaluation {
        guard peer.isIdentityAuthenticated,
              peer.advertisementMetadata["vinci.app"] == "vinci",
              peer.advertisementMetadata["vinci.sync.kind"] == "simulator-preview",
              peer.advertisementMetadata["vinci.preview.session"] == sessionID,
              peer.advertisementMetadata["vinci.preview.role"] == expectedRole else {
            return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
        }

        return LoomTrustEvaluation(decision: .trusted, shouldShowAutoTrustNotice: false)
    }

    func grantTrust(to peer: LoomPeerIdentity) async throws {}
    func revokeTrust(for deviceID: UUID) async throws {}
}
