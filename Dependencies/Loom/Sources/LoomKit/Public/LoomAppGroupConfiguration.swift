//
//  LoomAppGroupConfiguration.swift
//  LoomKit
//
//  Created by Ethan Lipnik on 3/13/26.
//

import Foundation
import Loom

/// App identity contributed by the current process when multiple macOS apps share one Loom runtime.
public struct LoomAppGroupAppDescriptor: Codable, Hashable, Sendable, Identifiable {
    /// Stable app identifier advertised to remote peers.
    public let appID: String
    /// Human-readable app name projected into synthesized peer rows.
    public let displayName: String
    /// App-scoped metadata merged into projected peer advertisements.
    public let metadata: [String: String]
    /// App-specific feature flags advertised through the shared runtime catalog.
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
}

/// Opt-in configuration for App Group-scoped shared-runtime mode on macOS.
public struct LoomAppGroupConfiguration: Sendable, Hashable {
    /// App Group identifier used to scope the shared Unix-domain socket and leader election lock.
    public let appGroupIdentifier: String
    /// App identity contributed by the current process to the shared runtime catalog.
    public let app: LoomAppGroupAppDescriptor
    /// Socket basename used inside the shared App Group container.
    public let socketName: String

    public init(
        appGroupIdentifier: String,
        app: LoomAppGroupAppDescriptor,
        socketName: String = "loom.host.v1"
    ) {
        self.appGroupIdentifier = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.app = app
        let trimmedSocketName = socketName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.socketName = trimmedSocketName.isEmpty ? "loom.host.v1" : trimmedSocketName
    }
}
