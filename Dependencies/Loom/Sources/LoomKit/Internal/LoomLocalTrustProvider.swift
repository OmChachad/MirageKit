//
//  LoomLocalTrustProvider.swift
//  LoomKit
//
//  Created by Ethan Lipnik on 3/10/26.
//

import Foundation
import Loom

@MainActor
final class LoomLocalTrustProvider: LoomTrustProvider {
    private let trustStore: LoomTrustStore

    init(trustStore: LoomTrustStore) {
        self.trustStore = trustStore
    }

    nonisolated func evaluateTrust(for peer: LoomPeerIdentity) async -> LoomTrustDecision {
        await evaluateTrustOutcome(for: peer).decision
    }

    nonisolated func evaluateTrustOutcome(for peer: LoomPeerIdentity) async -> LoomTrustEvaluation {
        await MainActor.run {
            guard peer.isIdentityAuthenticated else {
                return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
            }
            guard let identityKeyID = peer.identityKeyID,
                  let identityPublicKey = peer.identityPublicKey else {
                return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
            }
            if LoomIdentityManager.keyID(for: identityPublicKey) != identityKeyID {
                return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
            }
            if trustStore.isTrusted(peerIdentity: peer) {
                return LoomTrustEvaluation(decision: .trusted, shouldShowAutoTrustNotice: false)
            }
            return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
        }
    }

    nonisolated func grantTrust(to peer: LoomPeerIdentity) async throws {
        let trustedDevice = try LoomTrustedDevice(peerIdentity: peer, trustedAt: Date())
        await MainActor.run {
            trustStore.addTrustedDevice(trustedDevice)
        }
    }

    nonisolated func revokeTrust(for deviceID: UUID) async throws {
        await MainActor.run {
            trustStore.revokeTrust(for: deviceID)
        }
    }
}
