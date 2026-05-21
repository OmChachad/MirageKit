//
//  DesktopResizeCoordinator.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 4/13/26.
//

import Combine
import CoreGraphics
import Foundation
import MirageKit

@MainActor
final class DesktopResizeCoordinator: ObservableObject {
    enum DispatchPolicy: Equatable {
        case startup
        case immediate
        case settledWindowMetrics
    }

    struct RequestGeometry: Equatable {
        let logicalResolution: CGSize
        let displayScaleFactor: CGFloat
        let requestedStreamScale: CGFloat
        let encoderMaxWidth: Int?
        let encoderMaxHeight: Int?

        func isEffectivelySameStreamGeometry(as other: RequestGeometry) -> Bool {
            guard Self.approximatelyEqual(logicalResolution.width, other.logicalResolution.width),
                  Self.approximatelyEqual(logicalResolution.height, other.logicalResolution.height),
                  Self.approximatelyEqual(displayScaleFactor, other.displayScaleFactor),
                  Self.approximatelyEqual(requestedStreamScale, other.requestedStreamScale) else {
                return false
            }

            let currentGeometry = resolvedGeometry
            let otherGeometry = other.resolvedGeometry
            return Self.pixelSizesEqual(currentGeometry.displayPixelSize, otherGeometry.displayPixelSize) &&
                Self.pixelSizesEqual(currentGeometry.encodedPixelSize, otherGeometry.encodedPixelSize)
        }

        private var resolvedGeometry: MirageStreamGeometry {
            MirageStreamGeometry.resolve(
                logicalSize: logicalResolution,
                displayScaleFactor: displayScaleFactor,
                requestedStreamScale: requestedStreamScale,
                encoderMaxWidth: encoderMaxWidth,
                encoderMaxHeight: encoderMaxHeight
            )
        }

        var displayPixelSize: CGSize {
            resolvedGeometry.displayPixelSize
        }

        private static func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
            abs(lhs - rhs) <= 0.001
        }

        private static func pixelSizesEqual(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
            abs(lhs.width - rhs.width) <= 1 &&
                abs(lhs.height - rhs.height) <= 1
        }

        func isEffectivelySameAcceptedStreamGeometry(
            logicalResolution acceptedLogicalResolution: CGSize,
            displayPixelSize acceptedDisplayPixelSize: CGSize
        ) -> Bool {
            guard Self.approximatelyEqual(logicalResolution.width, acceptedLogicalResolution.width),
                  Self.approximatelyEqual(logicalResolution.height, acceptedLogicalResolution.height) else {
                return false
            }

            return Self.pixelSizesEqual(resolvedGeometry.displayPixelSize, acceptedDisplayPixelSize)
        }

        func displayPixelsMatchAccepted(_ acceptedDisplayPixelSize: CGSize) -> Bool {
            Self.pixelSizesEqual(resolvedGeometry.displayPixelSize, acceptedDisplayPixelSize)
        }

        func isImmediateStartupDowngrade(
            of acceptedTarget: RequestGeometry,
            acceptedDisplayPixelSize: CGSize
        ) -> Bool {
            guard Self.approximatelyEqual(logicalResolution.width, acceptedTarget.logicalResolution.width),
                  Self.approximatelyEqual(logicalResolution.height, acceptedTarget.logicalResolution.height),
                  displayPixelSize.width < acceptedDisplayPixelSize.width - 1 ||
                    displayPixelSize.height < acceptedDisplayPixelSize.height - 1 else {
                return false
            }
            return acceptedTarget.displayPixelsMatchAccepted(acceptedDisplayPixelSize)
        }
    }

    struct ActiveTransition: Equatable {
        let streamID: StreamID
        let transitionID: UUID
        let target: RequestGeometry
    }

    @Published var resizeLifecycleState: DesktopResizeLifecycleState = .active
    @Published var isResizing = false
    @Published var maskActive = false
    @Published var latestContainerDisplaySize: CGSize = .zero
    @Published var latestDrawableViewSize: CGSize = .zero
    @Published var latestRequestedTarget: RequestGeometry?
    @Published var latestRequestedDispatchPolicy: DispatchPolicy?
    @Published var queuedTarget: RequestGeometry?
    @Published var queuedDispatchPolicy: DispatchPolicy?
    @Published var lastSentTarget: RequestGeometry?
    @Published var activeTransition: ActiveTransition?
    var displayResolutionTask: Task<Void, Never>?
    var resizeHoldoffTask: Task<Void, Never>?
    var presentationMaskTimeoutTask: Task<Void, Never>?

    func beginTransition(streamID: StreamID, transitionID: UUID, target: RequestGeometry) {
        activeTransition = ActiveTransition(streamID: streamID, transitionID: transitionID, target: target)
        lastSentTarget = target
        queuedTarget = nil
        queuedDispatchPolicy = nil
        latestRequestedTarget = target
        latestRequestedDispatchPolicy = nil
        isResizing = true
        maskActive = true
    }

    func queueLatestTarget(
        _ target: RequestGeometry,
        dispatchPolicy: DispatchPolicy = .settledWindowMetrics,
        activatePresentationMask: Bool = true
    ) {
        latestRequestedTarget = target
        latestRequestedDispatchPolicy = dispatchPolicy
        queuedTarget = target
        queuedDispatchPolicy = dispatchPolicy
        if activatePresentationMask {
            isResizing = true
            maskActive = true
        }
    }

    func clearQueuedResizeRequest() {
        latestRequestedTarget = nil
        latestRequestedDispatchPolicy = nil
        queuedTarget = nil
        queuedDispatchPolicy = nil
        if activeTransition == nil {
            clearLocalPresentationState()
        }
    }

    func acceptTransition(streamID: StreamID, transitionID: UUID?) -> Bool {
        transitionID != nil &&
            activeTransition?.streamID == streamID &&
            activeTransition?.transitionID == transitionID
    }

    func finishTransition() {
        activeTransition = nil
        if queuedTarget == nil {
            isResizing = false
            maskActive = false
        } else {
            isResizing = true
            maskActive = true
        }
    }

    func clearQueuedTargetsMatchingAcceptedStreamGeometry(
        logicalResolution acceptedLogicalResolution: CGSize,
        displayPixelSize acceptedDisplayPixelSize: CGSize
    ) {
        if queuedTarget?.isEffectivelySameAcceptedStreamGeometry(
            logicalResolution: acceptedLogicalResolution,
            displayPixelSize: acceptedDisplayPixelSize
        ) == true {
            queuedTarget = nil
            queuedDispatchPolicy = nil
        }

        if latestRequestedTarget?.isEffectivelySameAcceptedStreamGeometry(
            logicalResolution: acceptedLogicalResolution,
            displayPixelSize: acceptedDisplayPixelSize
        ) == true {
            latestRequestedTarget = nil
            latestRequestedDispatchPolicy = nil
        }

        if activeTransition == nil, queuedTarget == nil {
            clearLocalPresentationState()
        }
    }

    func clearQueuedTargetsMatchingAcceptedDisplayPixels(
        _ acceptedDisplayPixelSize: CGSize
    ) {
        if queuedTarget?.displayPixelsMatchAccepted(acceptedDisplayPixelSize) == true {
            queuedTarget = nil
            queuedDispatchPolicy = nil
        }

        if latestRequestedTarget?.displayPixelsMatchAccepted(acceptedDisplayPixelSize) == true {
            latestRequestedTarget = nil
            latestRequestedDispatchPolicy = nil
        }

        if activeTransition == nil, queuedTarget == nil {
            clearLocalPresentationState()
        }
    }

    func clearLocalPresentationState() {
        isResizing = false
        maskActive = false
        presentationMaskTimeoutTask?.cancel()
        presentationMaskTimeoutTask = nil
    }

    func cancelPendingTasks() {
        displayResolutionTask?.cancel()
        displayResolutionTask = nil
        resizeHoldoffTask?.cancel()
        resizeHoldoffTask = nil
        presentationMaskTimeoutTask?.cancel()
        presentationMaskTimeoutTask = nil
    }

    func cancelPendingResizeDispatch() {
        displayResolutionTask?.cancel()
        displayResolutionTask = nil
        if activeTransition == nil {
            clearLocalPresentationState()
        }
    }

    func clearAllState(
        preserveLifecycleState: Bool = false,
        preserveLastSentTarget: Bool = false
    ) {
        let lifecycleState = resizeLifecycleState
        let lastSentTargetSnapshot = lastSentTarget
        cancelPendingTasks()
        resizeLifecycleState = preserveLifecycleState ? lifecycleState : .active
        clearLocalPresentationState()
        latestContainerDisplaySize = .zero
        latestDrawableViewSize = .zero
        latestRequestedTarget = nil
        latestRequestedDispatchPolicy = nil
        queuedTarget = nil
        queuedDispatchPolicy = nil
        lastSentTarget = preserveLastSentTarget ? lastSentTargetSnapshot : nil
        activeTransition = nil
    }
}
