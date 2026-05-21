//
//  LoomSharedDeviceIDTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/13/26.
//

@testable import Loom
import Foundation
import Testing

@Suite("Loom Shared Device ID", .serialized)
struct LoomSharedDeviceIDTests {
    @Test("Shared device ID ignores deprecated per-target keys")
    func sharedDeviceIDIgnoresDeprecatedPerTargetKeys() {
        let suiteName = "com.ethanlipnik.loom.tests.shared-device-id.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }

        defaults.removePersistentDomain(forName: suiteName)
        for deprecatedKey in LoomSharedDeviceID.deprecatedKeys {
            defaults.removeObject(forKey: deprecatedKey)
            UserDefaults.standard.removeObject(forKey: deprecatedKey)
        }

        let deprecatedDeviceID = UUID()
        UserDefaults.standard.set(
            deprecatedDeviceID.uuidString,
            forKey: LoomSharedDeviceID.deprecatedKeys[0]
        )

        let resolvedDeviceID = LoomSharedDeviceID.getOrCreate(suiteName: suiteName)

        #expect(resolvedDeviceID != deprecatedDeviceID)
        #expect(defaults.string(forKey: LoomSharedDeviceID.key) == resolvedDeviceID.uuidString)
        #expect(UserDefaults.standard.string(forKey: LoomSharedDeviceID.deprecatedKeys[0]) == nil)
    }
}
