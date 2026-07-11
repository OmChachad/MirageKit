//
//  LoomCloudKitPeerInfo.swift
//  Loom
//
//  Created by Ethan Lipnik on 1/28/26.
//
//  Peer information retrieved from CloudKit.
//

import Foundation
import Loom

public struct LoomCloudKitOverlayHint: Codable, Hashable, Sendable {
    public let host: String
    public let probePort: UInt16?

    public init(host: String, probePort: UInt16? = nil) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.probePort = probePort
    }
}

/// Represents a peer stored in CloudKit.
public struct LoomCloudKitPeerInfo: Identifiable, Hashable, Sendable {
    public let id: LoomPeerID
    public let name: String
    public let deviceType: DeviceType
    public let advertisement: LoomPeerAdvertisement
    public let lastSeen: Date
    public let recordID: String
    public let identityPublicKey: Data?
    public let remoteAccessEnabled: Bool
    public let signalingSessionID: String?
    public let bootstrapMetadata: LoomBootstrapMetadata?
    public let overlayHints: [LoomCloudKitOverlayHint]

    /// Typed capability view derived from the peer's current publication state.
    public var capabilities: LoomPeerCapabilities {
        LoomPeerCapabilities(
            advertisement: advertisement,
            remoteAccessEnabled: remoteAccessEnabled,
            signalingSessionID: signalingSessionID,
            bootstrapMetadata: bootstrapMetadata
        )
    }

    public var deviceID: UUID {
        id.deviceID
    }

    public var appID: String? {
        id.appID
    }

    public init(
        id: LoomPeerID,
        name: String,
        deviceType: DeviceType,
        advertisement: LoomPeerAdvertisement,
        lastSeen: Date,
        recordID: String,
        identityPublicKey: Data? = nil,
        remoteAccessEnabled: Bool = false,
        signalingSessionID: String? = nil,
        bootstrapMetadata: LoomBootstrapMetadata? = nil,
        overlayHints: [LoomCloudKitOverlayHint] = []
    ) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.advertisement = advertisement
        self.lastSeen = lastSeen
        self.recordID = recordID
        self.identityPublicKey = identityPublicKey
        self.remoteAccessEnabled = remoteAccessEnabled
        self.signalingSessionID = signalingSessionID
        self.bootstrapMetadata = bootstrapMetadata
        self.overlayHints = overlayHints
    }

    public init(
        id: UUID,
        appID: String? = nil,
        name: String,
        deviceType: DeviceType,
        advertisement: LoomPeerAdvertisement,
        lastSeen: Date,
        recordID: String,
        identityPublicKey: Data? = nil,
        remoteAccessEnabled: Bool = false,
        signalingSessionID: String? = nil,
        bootstrapMetadata: LoomBootstrapMetadata? = nil,
        overlayHints: [LoomCloudKitOverlayHint] = []
    ) {
        self.init(
            id: LoomPeerID(deviceID: id, appID: appID),
            name: name,
            deviceType: deviceType,
            advertisement: advertisement,
            lastSeen: lastSeen,
            recordID: recordID,
            identityPublicKey: identityPublicKey,
            remoteAccessEnabled: remoteAccessEnabled,
            signalingSessionID: signalingSessionID,
            bootstrapMetadata: bootstrapMetadata,
            overlayHints: overlayHints
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: LoomCloudKitPeerInfo, rhs: LoomCloudKitPeerInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CloudKit Record Keys

public extension LoomCloudKitPeerInfo {
    enum RecordKey: String {
        case deviceID
        case name
        case deviceType
        case advertisementBlob
        case identityPublicKey
        case remoteAccessEnabled
        case signalingSessionID = "relaySessionID"
        case bootstrapMetadataBlob
        case overlayHintsBlob
        case lastSeen
        case createdAt
    }
}
