//
//  LoomCloudKitTrustProvider.swift
//  Loom
//
//  Created by Ethan Lipnik on 1/28/26.
//
//  iCloud-based trust provider for automatic device approval.
//

import Foundation
import Loom

/// Auto-trust policy used by CloudKit-backed Loom trust providers.
public enum LoomCloudKitTrustMode: Sendable {
    case manualOnly
    case sameAccountAutoTrust
}

/// iCloud-based trust provider that auto-approves devices on the same iCloud account.
///
/// This provider implements a layered trust evaluation:
///
/// 1. If ``requireApprovalForAllConnections`` is enabled → `.requiresApproval`
/// 2. If device is in the local trust store → `.trusted`
/// 3. If peer has no iCloud identity → `.requiresApproval`
/// 4. If CloudKit is unavailable → `.unavailable`
/// 5. If peer is on same iCloud account → `.trusted`
/// 6. Otherwise → `.requiresApproval`
///
/// ## Usage
///
/// ```swift
/// let cloudKitManager = LoomCloudKitManager(
///     containerIdentifier: "iCloud.com.yourcompany.YourApp"
/// )
/// let trustProvider = LoomCloudKitTrustProvider(
///     cloudKitManager: cloudKitManager,
///     localTrustStore: trustStore
/// )
/// hostService.trustProvider = trustProvider
/// ```
@MainActor
public final class LoomCloudKitTrustProvider: LoomTrustProvider {
    // MARK: - Properties

    /// CloudKit manager for user identity and published-peer verification.
    private let cloudKitManager: LoomCloudKitManager

    /// Local trust store fallback for devices without iCloud.
    private let localTrustStore: LoomTrustStore

    /// CloudKit-backed trust mode for the current runtime.
    public let trustMode: LoomCloudKitTrustMode

    /// Whether to require approval for all connections regardless of iCloud status.
    ///
    /// When enabled, even devices on the same iCloud account will require manual approval.
    /// Use this for high-security scenarios.
    public var requireApprovalForAllConnections: Bool = false

    // MARK: - Initialization

    /// Creates a CloudKit-based trust provider.
    ///
    /// - Parameters:
    ///   - cloudKitManager: The CloudKit manager for identity checking.
    ///   - localTrustStore: Local trust store for manually approved devices.
    ///   - trustMode: CloudKit-backed trust behavior layered above the local trust store.
    public init(
        cloudKitManager: LoomCloudKitManager,
        localTrustStore: LoomTrustStore,
        trustMode: LoomCloudKitTrustMode = .sameAccountAutoTrust
    ) {
        self.cloudKitManager = cloudKitManager
        self.localTrustStore = localTrustStore
        self.trustMode = trustMode
    }

    // MARK: - LoomTrustProvider

    public nonisolated func evaluateTrust(for peer: LoomPeerIdentity) async -> LoomTrustDecision {
        await evaluateTrustOutcomeOnMain(for: peer).decision
    }

    public nonisolated func evaluateTrustOutcome(for peer: LoomPeerIdentity) async -> LoomTrustEvaluation {
        await evaluateTrustOutcomeOnMain(for: peer)
    }

    @MainActor
    private func evaluateTrustOutcomeOnMain(for peer: LoomPeerIdentity) async -> LoomTrustEvaluation {
        // Check settings override first
        if requireApprovalForAllConnections {
            LoomLogger.trust("Trust evaluation: approval required by settings for \(peer.name)")
            return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
        }

        guard peer.isIdentityAuthenticated else {
            LoomLogger.trust("Trust evaluation: denied unauthenticated identity for \(peer.name)")
            return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
        }
        guard let peerIdentityKeyID = peer.identityKeyID,
              let peerIdentityPublicKey = peer.identityPublicKey else {
            LoomLogger.trust("Trust evaluation: denied missing authenticated identity for \(peer.name)")
            return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
        }
        if LoomIdentityManager.keyID(for: peerIdentityPublicKey) != peerIdentityKeyID {
            LoomLogger.trust("Trust evaluation: denied mismatched key ID for \(peer.name)")
            return LoomTrustEvaluation(decision: .denied, shouldShowAutoTrustNotice: false)
        }

        // Check if locally trusted (overrides everything)
        if localTrustStore.isTrusted(peerIdentity: peer) {
            LoomLogger.trust("Trust evaluation: device \(peer.name) is locally trusted")
            return LoomTrustEvaluation(decision: .trusted, shouldShowAutoTrustNotice: false)
        }

        // No iCloud identity means we can't auto-trust
        guard let peerUserID = peer.iCloudUserID else {
            LoomLogger.trust("Trust evaluation: no iCloud identity for \(peer.name)")
            return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
        }

        if trustMode == .manualOnly {
            LoomLogger.trust("Trust evaluation: manual-only mode for \(peer.name)")
            return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
        }

        // Check if CloudKit is available
        guard cloudKitManager.isAvailable else {
            LoomLogger.trust("Trust evaluation: CloudKit unavailable, falling back to approval")
            return LoomTrustEvaluation(
                decision: .unavailable("iCloud not available"),
                shouldShowAutoTrustNotice: false
            )
        }

        // Check if same iCloud account
        if let myUserID = cloudKitManager.currentUserRecordID, peerUserID == myUserID {
            let identityTrusted = await cloudKitManager.isPublishedPeerIdentityTrusted(
                deviceID: peer.deviceID,
                keyID: peerIdentityKeyID,
                publicKey: peerIdentityPublicKey
            )
            if identityTrusted {
                LoomLogger.trust("Trust evaluation: same-account published identity trusted for \(peer.name)")
                return LoomTrustEvaluation(decision: .trusted, shouldShowAutoTrustNotice: true)
            }
            LoomLogger.trust("Trust evaluation: same-account identity missing trusted public key for \(peer.name)")
            return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
        }

        // Unknown user - require approval
        LoomLogger.trust("Trust evaluation: unknown iCloud user, requiring approval for \(peer.name)")
        return LoomTrustEvaluation(decision: .requiresApproval, shouldShowAutoTrustNotice: false)
    }

    public nonisolated func grantTrust(to peer: LoomPeerIdentity) async throws {
        let device = try LoomTrustedDevice(peerIdentity: peer, trustedAt: Date())
        await MainActor.run {
            // Add to local trust store
            localTrustStore.addTrustedDevice(device)
            LoomLogger.trust("Granted trust to \(peer.name)")
        }
    }

    public nonisolated func revokeTrust(for deviceID: UUID) async throws {
        await MainActor.run {
            if let device = localTrustStore.trustedDevices.first(where: { $0.id == deviceID }) {
                localTrustStore.revokeTrust(for: device)
                LoomLogger.trust("Revoked trust for device \(deviceID)")
            }
        }
    }
}
