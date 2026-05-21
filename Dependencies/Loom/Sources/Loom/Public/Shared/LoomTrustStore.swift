//
//  LoomTrustStore.swift
//  Loom
//
//  Created by Ethan Lipnik on 1/21/26.
//

import Foundation
import Combine

/// Trust-store validation errors.
public enum LoomTrustStoreError: LocalizedError, Sendable, Equatable {
    case missingAuthenticatedIdentity
    case invalidIdentityKey

    public var errorDescription: String? {
        switch self {
        case .missingAuthenticatedIdentity:
            "Trust persistence requires an authenticated Loom identity key."
        case .invalidIdentityKey:
            "The peer identity key does not match its advertised key identifier."
        }
    }
}

/// Trusted device record used by Loom trust store.
public struct LoomTrustedDevice: Identifiable, Codable, Equatable {
    public let id: UUID
    public let identityKeyID: String
    public let identityPublicKey: Data
    public let name: String
    public let deviceType: DeviceType
    public let trustedAt: Date

    /// Creates a persisted trusted-device entry.
    ///
    /// - Parameters:
    ///   - id: Device identifier used during handshake.
    ///   - identityKeyID: Authenticated Loom identity key identifier.
    ///   - identityPublicKey: Authenticated Loom identity public key bytes.
    ///   - name: Display name shown in trust UI.
    ///   - deviceType: Platform type.
    ///   - trustedAt: Time the trust decision was granted.
    public init(
        id: UUID,
        identityKeyID: String,
        identityPublicKey: Data,
        name: String,
        deviceType: DeviceType,
        trustedAt: Date
    ) {
        self.id = id
        self.identityKeyID = identityKeyID
        self.identityPublicKey = identityPublicKey
        self.name = name
        self.deviceType = deviceType
        self.trustedAt = trustedAt
    }

    /// Creates a persisted trust entry from an authenticated peer identity.
    public init(peerIdentity: LoomPeerIdentity, trustedAt: Date) throws {
        guard peerIdentity.isIdentityAuthenticated,
              let identityKeyID = peerIdentity.identityKeyID,
              let identityPublicKey = peerIdentity.identityPublicKey else {
            throw LoomTrustStoreError.missingAuthenticatedIdentity
        }
        guard LoomIdentityManager.keyID(for: identityPublicKey) == identityKeyID else {
            throw LoomTrustStoreError.invalidIdentityKey
        }
        self.init(
            id: peerIdentity.deviceID,
            identityKeyID: identityKeyID,
            identityPublicKey: identityPublicKey,
            name: peerIdentity.name,
            deviceType: peerIdentity.deviceType,
            trustedAt: trustedAt
        )
    }

    /// Returns whether this record matches the exact authenticated peer identity.
    public func matches(_ peerIdentity: LoomPeerIdentity) -> Bool {
        guard peerIdentity.isIdentityAuthenticated,
              let peerIdentityKeyID = peerIdentity.identityKeyID,
              let peerIdentityPublicKey = peerIdentity.identityPublicKey else {
            return false
        }
        return id == peerIdentity.deviceID
            && identityKeyID == peerIdentityKeyID
            && identityPublicKey == peerIdentityPublicKey
    }
}

/// Stores trusted devices with persistence to UserDefaults.
@MainActor
/// UserDefaults-backed trust persistence for manually trusted devices.
///
/// This type stores local trust grants and is commonly combined with a custom
/// ``LoomTrustProvider`` implementation for auto-trust policies.
public final class LoomTrustStore: ObservableObject {
    private struct PersistedTrustState: Codable {
        static let currentVersion = 2

        let version: Int
        let trustedDevices: [LoomTrustedDevice]
    }

    /// Trusted devices (persisted to UserDefaults).
    public private(set) var trustedDevices: [LoomTrustedDevice] = []

    /// Flag to prevent saving during load.
    private var isLoading = false

    /// UserDefaults key for trusted devices.
    private let trustedDevicesKey: String
    /// UserDefaults store used for persistence.
    private let userDefaults: UserDefaults

    /// Creates a trust store with a configurable storage key.
    /// - Parameters:
    ///   - storageKey: UserDefaults key used for persistence.
    ///   - suiteName: Optional app-group suite used for shared trust persistence.
    public init(
        storageKey: String = "LoomTrustedDevices",
        suiteName: String? = nil
    ) {
        trustedDevicesKey = storageKey
        userDefaults = Self.userDefaults(suiteName: suiteName)
        loadTrustedDevices()
    }

    // MARK: - Persistence

    /// Load trusted devices from storage.
    public func loadTrustedDevices() {
        guard let data = userDefaults.data(forKey: trustedDevicesKey) else { return }
        do {
            // Avoid writing back while decoding persisted state.
            isLoading = true
            let decoded = try JSONDecoder().decode(PersistedTrustState.self, from: data)
            guard decoded.version == PersistedTrustState.currentVersion else {
                trustedDevices = []
                userDefaults.removeObject(forKey: trustedDevicesKey)
                isLoading = false
                LoomLogger.trust("Discarded unsupported trust-store version \(decoded.version).")
                return
            }
            trustedDevices = Self.deduplicated(decoded.trustedDevices)
            isLoading = false
            LoomLogger.trust("Loaded \(trustedDevices.count) trusted devices")
        } catch {
            trustedDevices = []
            userDefaults.removeObject(forKey: trustedDevicesKey)
            isLoading = false
            LoomLogger.error(.trust, error: error, message: "Failed to load trusted devices: ")
        }
    }

    private func saveTrustedDevices() {
        guard !isLoading else { return }
        do {
            let state = PersistedTrustState(
                version: PersistedTrustState.currentVersion,
                trustedDevices: Self.deduplicated(trustedDevices)
            )
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: trustedDevicesKey)
            LoomLogger.trust("Saved \(trustedDevices.count) trusted devices")
        } catch {
            LoomLogger.error(.trust, error: error, message: "Failed to save trusted devices: ")
        }
    }

    // MARK: - Trust Operations

    /// Returns whether the provided device ID is trusted.
    /// - Parameter deviceID: The device identifier to check.
    public func isTrusted(deviceID: UUID) -> Bool {
        trustedDevices.contains { $0.id == deviceID }
    }

    /// Returns whether the provided authenticated peer identity exactly matches a trusted record.
    public func isTrusted(peerIdentity: LoomPeerIdentity) -> Bool {
        trustedDevices.contains { $0.matches(peerIdentity) }
    }

    /// Add a trusted device and persist it.
    /// - Parameter device: Trusted device to add.
    public func addTrustedDevice(_ device: LoomTrustedDevice) {
        if let index = trustedDevices.firstIndex(where: { $0.id == device.id }) {
            trustedDevices[index] = device
        } else {
            trustedDevices.append(device)
        }
        saveTrustedDevices()
    }

    /// Remove a trusted device and persist the update.
    /// - Parameter device: Trusted device to revoke.
    public func revokeTrust(for device: LoomTrustedDevice) {
        trustedDevices.removeAll { $0.id == device.id }
        saveTrustedDevices()
    }

    /// Remove a trusted device by identifier and persist the update.
    public func revokeTrust(for deviceID: UUID) {
        trustedDevices.removeAll { $0.id == deviceID }
        saveTrustedDevices()
    }

    private static func deduplicated(_ devices: [LoomTrustedDevice]) -> [LoomTrustedDevice] {
        var deduplicatedDevices: [LoomTrustedDevice] = []
        for device in devices {
            if let index = deduplicatedDevices.firstIndex(where: { $0.id == device.id }) {
                deduplicatedDevices[index] = device
            } else {
                deduplicatedDevices.append(device)
            }
        }
        return deduplicatedDevices
    }

    private static func userDefaults(suiteName: String?) -> UserDefaults {
        guard let suiteName = suiteName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !suiteName.isEmpty,
              let userDefaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        return userDefaults
    }
}
