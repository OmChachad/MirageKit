//
//  LoomShell.swift
//  LoomShell
//
//  Created by Ethan Lipnik on 3/9/26.
//

@_exported import Foundation
@_exported import Loom

/// Outcome selected by shell transport fallback policy.
public enum LoomShellResolvedTransport: Sendable, Equatable {
    case loomNative
    case openSSH(endpoint: LoomBootstrapEndpoint)
}

/// Outcome of a single shell transport attempt.
public enum LoomShellConnectionAttemptOutcome: Sendable, Equatable {
    case succeeded
    case failed(String)
    case skipped(String)
}

/// Concrete Loom-native path that was attempted before optional SSH fallback.
public struct LoomShellDirectPath: Sendable, Equatable {
    public let source: LoomConnectionTargetSource
    public let transportKind: LoomTransportKind
    public let endpointDescription: String

    public init(
        source: LoomConnectionTargetSource,
        transportKind: LoomTransportKind,
        endpointDescription: String
    ) {
        self.source = source
        self.transportKind = transportKind
        self.endpointDescription = endpointDescription
    }
}

/// Human-readable record of a single connection attempt.
public struct LoomShellConnectionAttempt: Sendable, Equatable {
    public let transport: LoomShellResolvedTransport
    public let directPath: LoomShellDirectPath?
    public let outcome: LoomShellConnectionAttemptOutcome

    public init(
        transport: LoomShellResolvedTransport,
        directPath: LoomShellDirectPath?,
        outcome: LoomShellConnectionAttemptOutcome
    ) {
        self.transport = transport
        self.directPath = directPath
        self.outcome = outcome
    }
}

/// Full shell transport attempt report surfaced to app code for diagnostics and UI.
public struct LoomShellConnectionReport: Sendable, Equatable {
    public let attempts: [LoomShellConnectionAttempt]
    public let selectedTransport: LoomShellResolvedTransport?

    public init(
        attempts: [LoomShellConnectionAttempt],
        selectedTransport: LoomShellResolvedTransport?
    ) {
        self.attempts = attempts
        self.selectedTransport = selectedTransport
    }
}

/// Failure wrapper that preserves the full shell transport report.
public struct LoomShellConnectionFailure: LocalizedError, Sendable, Equatable {
    public let report: LoomShellConnectionReport
    public let underlyingMessage: String

    public init(report: LoomShellConnectionReport, underlyingMessage: String) {
        self.report = report
        self.underlyingMessage = underlyingMessage
    }

    public var errorDescription: String? {
        underlyingMessage
    }
}

/// Ordered fallback policy for apps that support both Loom-native and OpenSSH shell transports.
public struct LoomShellConnectionPlan: Sendable, Equatable {
    public let primary: LoomShellResolvedTransport
    public let fallbacks: [LoomShellResolvedTransport]

    public init(primary: LoomShellResolvedTransport, fallbacks: [LoomShellResolvedTransport]) {
        self.primary = primary
        self.fallbacks = fallbacks
    }

    public var orderedTransports: [LoomShellResolvedTransport] {
        [primary] + fallbacks
    }
}

/// Shared interactive shell contract used by both Loom-native and OpenSSH-backed sessions.
public protocol LoomShellInteractiveSession: Sendable {
    var events: AsyncStream<LoomShellEvent> { get }

    func sendStdin(_ data: Data) async throws
    func resize(_ event: LoomShellResizeEvent) async throws
    func close() async
}

/// SSH authentication methods offered to fallback OpenSSH transports.
public enum LoomShellSSHAuthenticationMethod: Sendable, Equatable {
    case password(String)
    case privateKey(LoomShellSSHPrivateKey)
}

/// App-owned private key material used for SSH public-key authentication.
public enum LoomShellSSHPrivateKey: Sendable, Equatable {
    case ed25519(rawRepresentation: Data)
    case p256(rawRepresentation: Data)
    case p384(rawRepresentation: Data)
    case p521(rawRepresentation: Data)
}

/// SSH authentication material accepted by ``LoomOpenSSHSession`` and ``LoomShellConnector``.
public struct LoomShellSSHAuthentication: Sendable, Equatable {
    public let username: String
    public let methods: [LoomShellSSHAuthenticationMethod]

    public init(username: String, methods: [LoomShellSSHAuthenticationMethod]) {
        self.username = username
        self.methods = methods
    }

    public static func password(username: String, password: String) -> LoomShellSSHAuthentication {
        LoomShellSSHAuthentication(
            username: username,
            methods: [.password(password)]
        )
    }

    public static func privateKey(
        username: String,
        key: LoomShellSSHPrivateKey
    ) -> LoomShellSSHAuthentication {
        LoomShellSSHAuthentication(
            username: username,
            methods: [.privateKey(key)]
        )
    }

    public func appendingMethod(
        _ method: LoomShellSSHAuthenticationMethod
    ) -> LoomShellSSHAuthentication {
        LoomShellSSHAuthentication(
            username: username,
            methods: methods + [method]
        )
    }
}

/// Authorization prompt payload surfaced before LoomShell makes a session usable.
public struct LoomShellAuthorizationRequest: Sendable {
    public let transport: LoomShellResolvedTransport
    public let peerIdentity: LoomPeerIdentity?
    public let trustEvaluation: LoomTrustEvaluation?
    public let sshServerTrust: LoomSSHServerTrustConfiguration?
    public let canPersistTrust: Bool

    public init(
        transport: LoomShellResolvedTransport,
        peerIdentity: LoomPeerIdentity?,
        trustEvaluation: LoomTrustEvaluation?,
        sshServerTrust: LoomSSHServerTrustConfiguration?,
        canPersistTrust: Bool
    ) {
        self.transport = transport
        self.peerIdentity = peerIdentity
        self.trustEvaluation = trustEvaluation
        self.sshServerTrust = sshServerTrust
        self.canPersistTrust = canPersistTrust
    }
}

/// Result returned by a shell-authorization handler.
public enum LoomShellAuthorizationDecision: Sendable, Equatable {
    case allowOnce
    case allowAndTrust
    case deny(String)
}

/// Blocking authorization callback invoked before a shell session becomes usable.
public typealias LoomShellAuthorizationHandler = @Sendable (
    LoomShellAuthorizationRequest
) async -> LoomShellAuthorizationDecision

/// App-visible shell connection failure.
public enum LoomShellError: LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case missingSSHAuthentication
    case invalidSSHAuthentication
    case missingSSHServerTrustConfiguration
    case invalidSSHServerTrustConfiguration(String)
    case invalidSSHPrivateKey(String)
    case authorizationRequired(String)
    case authorizationRejected(String)
    case authorizationPersistenceUnavailable(String)
    case remoteFailure(String)
    case protocolViolation(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(detail):
            "Shell configuration is invalid: \(detail)"
        case .missingSSHAuthentication:
            "Emergency SSH requires authentication material."
        case .invalidSSHAuthentication:
            "Emergency SSH requires at least one valid authentication method."
        case .missingSSHServerTrustConfiguration:
            "Emergency SSH requires an explicit host-certificate trust configuration."
        case let .invalidSSHServerTrustConfiguration(detail):
            "Emergency SSH trust configuration is invalid: \(detail)"
        case let .invalidSSHPrivateKey(detail):
            "OpenSSH private key is invalid: \(detail)"
        case let .authorizationRequired(detail):
            "Shell authorization is required: \(detail)"
        case let .authorizationRejected(detail):
            "Shell authorization was rejected: \(detail)"
        case let .authorizationPersistenceUnavailable(detail):
            "Shell trust could not be persisted: \(detail)"
        case let .remoteFailure(detail):
            "Remote shell failed: \(detail)"
        case let .protocolViolation(detail):
            "Shell protocol error: \(detail)"
        case let .unsupported(detail):
            "Shell transport is unsupported: \(detail)"
        }
    }
}

/// Successful shell connection result returned by the connector.
public struct LoomShellConnectionResult: Sendable {
    public let transport: LoomShellResolvedTransport
    public let session: any LoomShellInteractiveSession
    public let authenticatedSessionContext: LoomAuthenticatedSessionContext?
    public let report: LoomShellConnectionReport

    public init(
        transport: LoomShellResolvedTransport,
        session: any LoomShellInteractiveSession,
        authenticatedSessionContext: LoomAuthenticatedSessionContext? = nil,
        report: LoomShellConnectionReport
    ) {
        self.transport = transport
        self.session = session
        self.authenticatedSessionContext = authenticatedSessionContext
        self.report = report
    }
}

/// Resolves app-visible fallback order between Loom-native and OpenSSH shell sessions.
public enum LoomShellConnectionPlanner {
    public static func plan(
        peerCapabilities: LoomShellPeerCapabilities? = nil,
        bootstrapMetadata: LoomBootstrapMetadata?,
        preferLoomNative: Bool = true,
        allowEmergencySSH: Bool = false,
        sshServerTrust: LoomSSHServerTrustConfiguration? = nil
    ) -> LoomShellConnectionPlan {
        let sshFallbacks = resolvedSSHFallbacks(
            from: bootstrapMetadata,
            peerCapabilities: peerCapabilities,
            allowEmergencySSH: allowEmergencySSH,
            sshServerTrust: sshServerTrust
        )
        if peerCapabilities?.supportsLoomNativeShell == false {
            let primary = sshFallbacks.first ?? .loomNative
            return LoomShellConnectionPlan(
                primary: primary,
                fallbacks: Array(sshFallbacks.dropFirst())
            )
        }
        if preferLoomNative {
            return LoomShellConnectionPlan(primary: .loomNative, fallbacks: sshFallbacks)
        }
        let primary = sshFallbacks.first ?? .loomNative
        let remainder = sshFallbacks.dropFirst()
        var fallbacks = Array(remainder)
        if primary != .loomNative {
            fallbacks.append(.loomNative)
        }
        return LoomShellConnectionPlan(primary: primary, fallbacks: fallbacks)
    }

    private static func resolvedSSHFallbacks(
        from bootstrapMetadata: LoomBootstrapMetadata?,
        peerCapabilities: LoomShellPeerCapabilities?,
        allowEmergencySSH: Bool,
        sshServerTrust: LoomSSHServerTrustConfiguration?
    ) -> [LoomShellResolvedTransport] {
        guard allowEmergencySSH,
              sshServerTrust != nil,
              peerCapabilities?.supportsOpenSSHFallback != false else {
            return []
        }
        guard let bootstrapMetadata,
              bootstrapMetadata.enabled else {
            return []
        }

        let endpoints = LoomBootstrapEndpointResolver.resolve(bootstrapMetadata.endpoints)
        return endpoints.map { endpoint in
            let port = bootstrapMetadata.sshPort ?? endpoint.port
            return .openSSH(
                endpoint: LoomBootstrapEndpoint(
                    host: endpoint.host,
                    port: port,
                    source: endpoint.source
                )
            )
        }
    }
}

/// High-level connector that prefers Loom-native shell sessions and falls back to OpenSSH when enabled.
@MainActor
public final class LoomShellConnector {
    private weak var node: LoomNode?
    private let connectionCoordinator: LoomConnectionCoordinator

    public init(node: LoomNode, signalingClient: LoomRemoteSignalingClient? = nil) {
        self.node = node
        connectionCoordinator = LoomConnectionCoordinator(node: node, signalingClient: signalingClient)
    }

    public func connect(
        hello: LoomSessionHelloRequest,
        request: LoomShellSessionRequest,
        localPeer: LoomPeer? = nil,
        signalingSessionID: String? = nil,
        peerCapabilities: LoomShellPeerCapabilities? = nil,
        bootstrapMetadata: LoomBootstrapMetadata? = nil,
        sshAuthentication: LoomShellSSHAuthentication? = nil,
        preferLoomNative: Bool = true,
        allowEmergencySSH: Bool = false,
        sshServerTrust: LoomSSHServerTrustConfiguration? = nil,
        authorizationHandler: LoomShellAuthorizationHandler? = nil,
        timeout: Duration = .seconds(10)
    ) async throws -> LoomShellConnectionResult {
        try await connect(
            using: LoomShellConnectionPlanner.plan(
                peerCapabilities: peerCapabilities,
                bootstrapMetadata: bootstrapMetadata,
                preferLoomNative: preferLoomNative,
                allowEmergencySSH: allowEmergencySSH,
                sshServerTrust: sshServerTrust
            ),
            hello: hello,
            request: request,
            localPeer: localPeer,
            signalingSessionID: signalingSessionID,
            peerCapabilities: peerCapabilities,
            bootstrapMetadata: bootstrapMetadata,
            sshAuthentication: sshAuthentication,
            sshServerTrust: sshServerTrust,
            authorizationHandler: authorizationHandler,
            timeout: timeout
        )
    }

    public func connect(
        to peer: LoomShellDiscoveredPeer,
        identity: LoomShellIdentity,
        request: LoomShellSessionRequest,
        signalingSessionID: String? = nil,
        sshAuthentication: LoomShellSSHAuthentication? = nil,
        preferLoomNative: Bool = true,
        allowEmergencySSH: Bool = false,
        sshServerTrust: LoomSSHServerTrustConfiguration? = nil,
        authorizationHandler: LoomShellAuthorizationHandler? = nil,
        timeout: Duration = .seconds(10)
    ) async throws -> LoomShellConnectionResult {
        let hello = try identity.makeHelloRequest()
        return try await connect(
            hello: hello,
            request: request,
            localPeer: peer.peer,
            signalingSessionID: signalingSessionID,
            peerCapabilities: peer.capabilities,
            bootstrapMetadata: peer.bootstrapMetadata,
            sshAuthentication: sshAuthentication,
            preferLoomNative: preferLoomNative,
            allowEmergencySSH: allowEmergencySSH,
            sshServerTrust: sshServerTrust,
            authorizationHandler: authorizationHandler,
            timeout: timeout
        )
    }

    private func connect(
        using plan: LoomShellConnectionPlan,
        hello: LoomSessionHelloRequest,
        request: LoomShellSessionRequest,
        localPeer: LoomPeer?,
        signalingSessionID: String?,
        peerCapabilities: LoomShellPeerCapabilities?,
        bootstrapMetadata: LoomBootstrapMetadata?,
        sshAuthentication: LoomShellSSHAuthentication?,
        sshServerTrust: LoomSSHServerTrustConfiguration?,
        authorizationHandler: LoomShellAuthorizationHandler?,
        timeout: Duration
    ) async throws -> LoomShellConnectionResult {
        var attempts: [LoomShellConnectionAttempt] = []
        var lastError: Error?
        for transport in plan.orderedTransports {
            do {
                switch transport {
                case .loomNative:
                    if peerCapabilities?.supportsLoomNativeShell == false {
                        attempts.append(
                            LoomShellConnectionAttempt(
                                transport: .loomNative,
                                directPath: nil,
                                outcome: .skipped("Peer does not advertise Loom-native shell support.")
                            )
                        )
                        continue
                    }

                    let nativePlan = try await connectionCoordinator.makePlan(
                        localPeer: localPeer,
                        signalingSessionID: signalingSessionID
                    )
                    if nativePlan.targets.isEmpty {
                        attempts.append(
                            LoomShellConnectionAttempt(
                                transport: .loomNative,
                                directPath: nil,
                                outcome: .failed("No direct Loom transport candidates were available.")
                            )
                        )
                        lastError = LoomError.sessionNotFound
                        continue
                    }

                    for target in nativePlan.targets {
                        let directPath = LoomShellDirectPath(
                            source: target.source,
                            transportKind: target.transportKind,
                            endpointDescription: target.endpoint.debugDescription
                        )
                        do {
                            let authenticatedSession = try await connectionCoordinator.connect(
                                to: target,
                                hello: hello
                            )
                            do {
                                let sessionContext = try await authorizeLoomNativeSession(
                                    authenticatedSession,
                                    authorizationHandler: authorizationHandler
                                )
                                let shellSession = try await LoomNativeShellSession.open(
                                    over: authenticatedSession,
                                    request: request
                                )
                                attempts.append(
                                    LoomShellConnectionAttempt(
                                        transport: .loomNative,
                                        directPath: directPath,
                                        outcome: .succeeded
                                    )
                                )
                                let report = LoomShellConnectionReport(
                                    attempts: attempts,
                                    selectedTransport: .loomNative
                                )
                                return LoomShellConnectionResult(
                                    transport: .loomNative,
                                    session: shellSession,
                                    authenticatedSessionContext: sessionContext,
                                    report: report
                                )
                            } catch {
                                await authenticatedSession.cancel()
                                throw error
                            }
                        } catch {
                            attempts.append(
                                LoomShellConnectionAttempt(
                                    transport: .loomNative,
                                    directPath: directPath,
                                    outcome: .failed(error.localizedDescription)
                                )
                            )
                            lastError = error
                        }
                    }
                case let .openSSH(endpoint):
                    guard let sshAuthentication else {
                        let error = LoomShellError.missingSSHAuthentication
                        attempts.append(
                            LoomShellConnectionAttempt(
                                transport: transport,
                                directPath: nil,
                                outcome: .skipped(error.localizedDescription)
                            )
                        )
                        lastError = error
                        continue
                    }
                    let validatedAuthentication = try validateSSHAuthentication(sshAuthentication)
                    guard let sshServerTrust else {
                        let error = LoomShellError.missingSSHServerTrustConfiguration
                        attempts.append(
                            LoomShellConnectionAttempt(
                                transport: transport,
                                directPath: nil,
                                outcome: .skipped(error.localizedDescription)
                            )
                        )
                        lastError = error
                        continue
                    }
                    let preparedConnection = try await LoomOpenSSHSession.prepareConnection(
                        endpoint: endpoint,
                        authentication: validatedAuthentication,
                        serverTrust: sshServerTrust,
                        timeout: timeout
                    )
                    do {
                        try await authorizeEmergencySSH(
                            transport: transport,
                            serverTrust: sshServerTrust,
                            authorizationHandler: authorizationHandler
                        )
                        let shellSession = try await preparedConnection.openShell(request: request)
                        attempts.append(
                            LoomShellConnectionAttempt(
                                transport: transport,
                                directPath: nil,
                                outcome: .succeeded
                            )
                        )
                        let report = LoomShellConnectionReport(
                            attempts: attempts,
                            selectedTransport: transport
                        )
                        return LoomShellConnectionResult(
                            transport: transport,
                            session: shellSession,
                            authenticatedSessionContext: nil,
                            report: report
                        )
                    } catch {
                        await preparedConnection.close()
                        throw error
                    }
                }
            } catch {
                attempts.append(
                    LoomShellConnectionAttempt(
                        transport: transport,
                        directPath: nil,
                        outcome: .failed(error.localizedDescription)
                    )
                )
                lastError = error
            }
        }

        let report = LoomShellConnectionReport(
            attempts: attempts,
            selectedTransport: nil
        )
        let message = (lastError ?? LoomError.sessionNotFound).localizedDescription
        throw LoomShellConnectionFailure(report: report, underlyingMessage: message)
    }

    private func validateSSHAuthentication(
        _ authentication: LoomShellSSHAuthentication
    ) throws -> LoomShellSSHAuthentication {
        let username = authentication.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            throw LoomShellError.invalidSSHAuthentication
        }
        guard !authentication.methods.isEmpty else {
            throw LoomShellError.invalidSSHAuthentication
        }
        return LoomShellSSHAuthentication(
            username: username,
            methods: authentication.methods
        )
    }

    private func authorizeLoomNativeSession(
        _ authenticatedSession: LoomAuthenticatedSession,
        authorizationHandler: LoomShellAuthorizationHandler?
    ) async throws -> LoomAuthenticatedSessionContext {
        guard let sessionContext = await authenticatedSession.context else {
            throw LoomShellError.protocolViolation("Authenticated Loom session is missing its context.")
        }
        switch sessionContext.trustEvaluation.decision {
        case .trusted:
            return sessionContext
        case .denied:
            throw LoomShellError.authorizationRejected(
                "The Loom trust provider denied the shell session."
            )
        case .requiresApproval, .unavailable(_):
            guard let authorizationHandler else {
                throw LoomShellError.authorizationRequired(
                    "Loom-native shell requires an explicit authorization handler."
                )
            }
            let canPersistTrust = node?.trustProvider != nil
            let request = LoomShellAuthorizationRequest(
                transport: .loomNative,
                peerIdentity: sessionContext.peerIdentity,
                trustEvaluation: sessionContext.trustEvaluation,
                sshServerTrust: nil,
                canPersistTrust: canPersistTrust
            )
            let decision = await authorizationHandler(request)
            try await handleAuthorizationDecision(
                decision,
                peerIdentity: sessionContext.peerIdentity,
                canPersistTrust: canPersistTrust
            )
            return sessionContext
        }
    }

    private func authorizeEmergencySSH(
        transport: LoomShellResolvedTransport,
        serverTrust: LoomSSHServerTrustConfiguration,
        authorizationHandler: LoomShellAuthorizationHandler?
    ) async throws {
        guard let authorizationHandler else {
            throw LoomShellError.authorizationRequired(
                "Emergency SSH requires an explicit authorization handler."
            )
        }
        let request = LoomShellAuthorizationRequest(
            transport: transport,
            peerIdentity: nil,
            trustEvaluation: nil,
            sshServerTrust: serverTrust,
            canPersistTrust: false
        )
        let decision = await authorizationHandler(request)
        switch decision {
        case .allowOnce:
            return
        case .allowAndTrust:
            throw LoomShellError.authorizationPersistenceUnavailable(
                "LoomShell does not persist emergency SSH approvals."
            )
        case let .deny(reason):
            throw LoomShellError.authorizationRejected(reason)
        }
    }

    private func handleAuthorizationDecision(
        _ decision: LoomShellAuthorizationDecision,
        peerIdentity: LoomPeerIdentity,
        canPersistTrust: Bool
    ) async throws {
        switch decision {
        case .allowOnce:
            return
        case .allowAndTrust:
            guard canPersistTrust, let trustProvider = node?.trustProvider else {
                throw LoomShellError.authorizationPersistenceUnavailable(
                    "No Loom trust provider is configured for persistent shell trust."
                )
            }
            try await trustProvider.grantTrust(to: peerIdentity)
        case let .deny(reason):
            throw LoomShellError.authorizationRejected(reason)
        }
    }
}
