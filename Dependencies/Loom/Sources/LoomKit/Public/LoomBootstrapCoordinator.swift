//
//  LoomBootstrapCoordinator.swift
//  LoomKit
//
//  Created by Ethan Lipnik on 3/13/26.
//

import Foundation
import Loom

/// Optional peer-recovery surface layered above a LoomKit runtime.
public actor LoomBootstrapCoordinator {
    private let store: LoomStore

    init(store: LoomStore) {
        self.store = store
    }

    /// Sends Wake-on-LAN packets using the selected peer's published recovery metadata.
    public func wake(_ peer: LoomPeerSnapshot) async throws {
        guard peer.capabilities.bootstrap.supportsWakeOnLAN else {
            throw LoomKitError(message: "The selected peer does not publish Wake-on-LAN recovery.")
        }
        try await store.wake(peer)
    }

    /// Requests an SSH-based recovery unlock flow for the selected peer.
    public func requestUnlock(
        _ peer: LoomPeerSnapshot,
        username: String,
        password: String,
        sshServerTrust: LoomSSHServerTrustConfiguration
    ) async throws -> LoomBootstrapControlResult {
        guard peer.capabilities.bootstrap.supportsSSHUnlock else {
            throw LoomKitError(message: "The selected peer does not publish SSH recovery.")
        }
        return try await store.requestUnlock(
            peer,
            username: username,
            password: password,
            sshServerTrust: sshServerTrust
        )
    }
}
