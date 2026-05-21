//
//  LoomHostAppDescriptor.swift
//  LoomHost
//
//  Created by Ethan Lipnik on 3/10/26.
//

import Foundation
import Loom

/// App identity contributed to a shared Loom host catalog.
public struct LoomHostAppDescriptor: Codable, Hashable, Sendable, Identifiable {
    /// Stable app identifier advertised to remote peers.
    public let appID: String
    /// Human-readable app name projected into synthesized peer rows.
    public let displayName: String
    /// App-scoped metadata merged into projected peer advertisements.
    public let metadata: [String: String]
    /// App-specific feature flags advertised through the host catalog.
    public let supportedFeatures: [String]

    public var id: String { appID }

    public init(
        appID: String,
        displayName: String,
        metadata: [String: String] = [:],
        supportedFeatures: [String] = []
    ) {
        let normalizedEntry = LoomHostCatalogEntry(
            appID: appID,
            displayName: displayName,
            metadata: metadata,
            supportedFeatures: supportedFeatures
        )
        self.appID = normalizedEntry.appID
        self.displayName = normalizedEntry.displayName
        self.metadata = normalizedEntry.metadata
        self.supportedFeatures = normalizedEntry.supportedFeatures
    }

    package var catalogEntry: LoomHostCatalogEntry {
        LoomHostCatalogEntry(
            appID: appID,
            displayName: displayName,
            metadata: metadata,
            supportedFeatures: supportedFeatures
        )
    }
}
