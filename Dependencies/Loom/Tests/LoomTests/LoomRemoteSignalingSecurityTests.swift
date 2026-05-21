//
//  LoomRemoteSignalingSecurityTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 2/23/26.
//
//  Security validation coverage for remote signaling configuration.
//

@testable import Loom
import Foundation
import Testing

@Suite("Remote Signaling Security")
struct LoomRemoteSignalingSecurityTests {
    @Test("Remote signaling auth HTTP failures are marked permanent")
    func remoteSignalingAuthHTTPFailuresArePermanent() {
        let unauthorized = LoomRemoteSignalingError.http(
            statusCode: 401,
            errorCode: "auth_failed",
            detail: "signature_verification_failed"
        )
        let forbidden = LoomRemoteSignalingError.http(
            statusCode: 403,
            errorCode: "auth_failed",
            detail: nil
        )

        #expect(unauthorized.isAuthenticationFailure)
        #expect(forbidden.isAuthenticationFailure)
        #expect(unauthorized.isPermanentConfigurationFailure)
        #expect(forbidden.isPermanentConfigurationFailure)
    }

    @Test("Remote signaling non-auth HTTP failures are not marked permanent")
    func remoteSignalingNonAuthHTTPFailuresAreNotPermanent() {
        let rateLimited = LoomRemoteSignalingError.http(
            statusCode: 429,
            errorCode: "rate_limited",
            detail: nil
        )

        #expect(rateLimited.isAuthenticationFailure == false)
        #expect(rateLimited.isPermanentConfigurationFailure == false)
    }

    @Test("Invalid signaling configuration is permanent")
    func invalidSignalingConfigurationIsPermanent() {
        let error = LoomRemoteSignalingError.invalidConfiguration
        #expect(error.isAuthenticationFailure == false)
        #expect(error.isPermanentConfigurationFailure)
    }

    @MainActor
    @Test("Remote signaling rejects non-HTTPS base URL")
    func remoteSignalingRejectsNonHTTPSBaseURL() async {
        let configuration = LoomRemoteSignalingConfiguration(
            baseURL: URL(string: "http://example.com")!,
            appAuthentication: LoomRemoteSignalingAppAuthentication(
                appID: "test-app",
                sharedSecret: "test-secret"
            )
        )
        let client = LoomRemoteSignalingClient(configuration: configuration)

        do {
            try await client.joinSession(sessionID: "session-1")
            Issue.record("Expected invalidConfiguration for non-HTTPS signaling URL.")
        } catch let error as LoomRemoteSignalingError {
            switch error {
            case .invalidConfiguration:
                break
            default:
                Issue.record("Expected invalidConfiguration, got \(error.localizedDescription).")
            }
        } catch {
            Issue.record("Expected LoomRemoteSignalingError, got \(error.localizedDescription).")
        }
    }
}
