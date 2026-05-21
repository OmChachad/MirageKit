//
//  LoomSharedHostConfiguration.swift
//  LoomHost
//
//  Created by Ethan Lipnik on 3/10/26.
//

import Foundation

/// Opt-in configuration for App Group-scoped shared-host mode on macOS.
public struct LoomSharedHostConfiguration: Sendable, Hashable {
    /// App Group identifier used to scope the shared Unix-domain socket and leader election lock.
    public let appGroupIdentifier: String
    /// App identity contributed by the current process to the host catalog.
    public let app: LoomHostAppDescriptor
    /// Socket basename used inside the shared App Group container.
    public let socketName: String

    package let directoryURLOverride: URL?

    public init(
        appGroupIdentifier: String,
        app: LoomHostAppDescriptor,
        socketName: String = "loom.host.v1"
    ) {
        self.appGroupIdentifier = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.app = app
        let trimmedSocketName = socketName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.socketName = trimmedSocketName.isEmpty ? "loom.host.v1" : trimmedSocketName
        directoryURLOverride = nil
    }

    package init(
        appGroupIdentifier: String,
        app: LoomHostAppDescriptor,
        socketName: String = "loom.host.v1",
        directoryURLOverride: URL?
    ) {
        self.appGroupIdentifier = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.app = app
        let trimmedSocketName = socketName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.socketName = trimmedSocketName.isEmpty ? "loom.host.v1" : trimmedSocketName
        self.directoryURLOverride = directoryURLOverride
    }
}
