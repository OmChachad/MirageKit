//
//  LoomSharedDeviceID.swift
//  Loom
//
//  Created by Ethan Lipnik on 2/28/26.
//
//  Shared App Group-backed device identifier used by Loom-powered apps.
//

import Foundation

/// Provides a stable device identifier shared between cooperating Loom apps.
///
/// Uses App Groups to share a single UUID between multiple app targets so a
/// product can filter out its own device from discovered peers.
public enum LoomSharedDeviceID {
    /// UserDefaults key for the shared device ID.
    public static let key = "com.loom.shared.deviceID"
    /// Deprecated per-target keys removed as part of the shared-ID cutover.
    static let deprecatedKeys = [
        "com.loom.client.deviceID",
        "com.loom.cloudkit.deviceID",
    ]

    /// Returns the shared device ID, creating one if needed.
    ///
    /// Priority:
    /// 1. Existing ID in shared App Group suite
    /// 2. Create new ID
    public static func getOrCreate(
        suiteName: String? = nil,
        key: String = LoomSharedDeviceID.key
    ) -> UUID {
        let sharedDefaults = userDefaults(suiteName: suiteName)
        let resolvedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.key : key
        removeDeprecatedValues(from: sharedDefaults)

        if let stored = sharedDefaults.string(forKey: resolvedKey),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }

        let newID = UUID()
        sharedDefaults.set(newID.uuidString, forKey: resolvedKey)
        return newID
    }

    private static func removeDeprecatedValues(from sharedDefaults: UserDefaults) {
        for deprecatedKey in deprecatedKeys {
            sharedDefaults.removeObject(forKey: deprecatedKey)
            if sharedDefaults !== UserDefaults.standard {
                UserDefaults.standard.removeObject(forKey: deprecatedKey)
            }
        }
    }

    private static func userDefaults(suiteName: String?) -> UserDefaults {
        guard let suiteName = suiteName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !suiteName.isEmpty,
              let sharedDefaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }

        return sharedDefaults
    }
}
