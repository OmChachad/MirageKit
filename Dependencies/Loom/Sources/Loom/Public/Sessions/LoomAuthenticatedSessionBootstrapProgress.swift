//
//  LoomAuthenticatedSessionBootstrapProgress.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/31/26.
//

import Foundation

/// Fine-grained authenticated-session bootstrap phases emitted before the session becomes ready.
public enum LoomAuthenticatedSessionBootstrapPhase: String, Sendable, Codable, Equatable {
    case idle
    case transportStarting
    case transportReady
    case localHelloSent
    case remoteHelloReceived
    case trustPendingApproval
    case ready
}

/// Bootstrap progress for an authenticated session.
///
/// `failureReason` is non-`nil` only when bootstrap terminated while the session
/// was still in `phase`.
public struct LoomAuthenticatedSessionBootstrapProgress: Sendable, Codable, Equatable {
    public let phase: LoomAuthenticatedSessionBootstrapPhase
    public let failureReason: String?

    public init(
        phase: LoomAuthenticatedSessionBootstrapPhase,
        failureReason: String? = nil
    ) {
        self.phase = phase
        self.failureReason = failureReason
    }

    public var isFailure: Bool {
        failureReason != nil
    }
}
