//
//  LoomPeerCapabilities.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/13/26.
//

import Foundation

/// Connectivity capabilities currently published for a Loom peer.
public struct LoomPeerConnectivityCapabilities: Hashable, Sendable, Codable {
    /// Whether the peer currently publishes one or more direct local-network transports.
    public let supportsNearbyDirectConnections: Bool
    /// Whether the peer currently publishes remote signaling-backed reachability.
    public let supportsRemoteSignalingReachability: Bool

    public init(
        supportsNearbyDirectConnections: Bool = false,
        supportsRemoteSignalingReachability: Bool = false
    ) {
        self.supportsNearbyDirectConnections = supportsNearbyDirectConnections
        self.supportsRemoteSignalingReachability = supportsRemoteSignalingReachability
    }

    public static let none = LoomPeerConnectivityCapabilities()
}

/// Recovery capabilities currently published for a Loom peer.
public struct LoomPeerBootstrapCapabilities: Hashable, Sendable, Codable {
    /// Whether the peer publishes Wake-on-LAN metadata.
    public let supportsWakeOnLAN: Bool
    /// Whether the peer publishes SSH bootstrap unlock metadata.
    public let supportsSSHUnlock: Bool
    /// Whether the peer publishes prelogin control-daemon metadata.
    public let supportsPreloginControl: Bool

    public init(
        supportsWakeOnLAN: Bool = false,
        supportsSSHUnlock: Bool = false,
        supportsPreloginControl: Bool = false
    ) {
        self.supportsWakeOnLAN = supportsWakeOnLAN
        self.supportsSSHUnlock = supportsSSHUnlock
        self.supportsPreloginControl = supportsPreloginControl
    }

    public static let none = LoomPeerBootstrapCapabilities()
}

/// Typed capability snapshot derived from a peer's current publication state.
public struct LoomPeerCapabilities: Hashable, Sendable, Codable {
    public let connectivity: LoomPeerConnectivityCapabilities
    public let bootstrap: LoomPeerBootstrapCapabilities

    public init(
        connectivity: LoomPeerConnectivityCapabilities = .none,
        bootstrap: LoomPeerBootstrapCapabilities = .none
    ) {
        self.connectivity = connectivity
        self.bootstrap = bootstrap
    }

    public init(
        advertisement: LoomPeerAdvertisement,
        remoteAccessEnabled: Bool,
        signalingSessionID: String?,
        bootstrapMetadata: LoomBootstrapMetadata?
    ) {
        let bootstrapEnabled = bootstrapMetadata?.enabled == true
        self.init(
            connectivity: LoomPeerConnectivityCapabilities(
                supportsNearbyDirectConnections: advertisement.directTransports.isEmpty == false,
                supportsRemoteSignalingReachability: remoteAccessEnabled && signalingSessionID?.isEmpty == false
            ),
            bootstrap: LoomPeerBootstrapCapabilities(
                supportsWakeOnLAN: bootstrapEnabled && bootstrapMetadata?.wakeOnLAN != nil,
                supportsSSHUnlock: bootstrapEnabled && bootstrapMetadata?.sshPort != nil,
                supportsPreloginControl: bootstrapEnabled
                    && bootstrapMetadata?.supportsPreloginDaemon == true
                    && bootstrapMetadata?.controlPort != nil
            )
        )
    }

    public static let none = LoomPeerCapabilities()
}
