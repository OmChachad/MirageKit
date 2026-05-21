//
//  LoomPeerID.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/10/26.
//

import Foundation

/// Stable logical peer identifier combining a host device and optional app identity.
public struct LoomPeerID: Codable, Hashable, Sendable {
    public let deviceID: UUID
    public let appID: String?

    public init(deviceID: UUID, appID: String? = nil) {
        self.deviceID = deviceID

        let trimmedAppID = appID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedAppID, !trimmedAppID.isEmpty {
            self.appID = trimmedAppID
        } else {
            self.appID = nil
        }
    }

    /// Lowercased stable string form used for sorting, storage, and diagnostics.
    public var rawValue: String {
        if let appID {
            return "\(deviceID.uuidString.lowercased())#\(appID)"
        }
        return deviceID.uuidString.lowercased()
    }

    /// Convenience alias matching `UUID`'s common sorting/display surface.
    public var uuidString: String {
        rawValue
    }
}

public extension LoomPeerID {
    static func == (lhs: LoomPeerID, rhs: UUID) -> Bool {
        lhs.deviceID == rhs && lhs.appID == nil
    }

    static func == (lhs: UUID, rhs: LoomPeerID) -> Bool {
        rhs == lhs
    }
}
