//
//  LoomAuthenticatedSession+MirageMediaProfile.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 5/21/26.
//

import Loom

#if os(macOS)
extension LoomAuthenticatedSession {
    func mirageMediaSendProfile() async -> LoomQueuedUnreliableSendProfile {
        .interactiveMedia
    }
}
#endif
