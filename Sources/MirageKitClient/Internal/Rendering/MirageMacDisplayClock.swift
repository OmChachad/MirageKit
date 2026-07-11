//
//  MirageMacDisplayClock.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 5/5/26.
//
//  CVDisplayLink adapter for macOS sample-buffer presentation pacing.
//

#if os(macOS)
import AppKit
import Foundation
import MirageKit
import QuartzCore

@MainActor
final class MirageMacDisplayClock: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    /// Stored as AnyObject so the class stays available on macOS 13; always a CADisplayLink.
    private nonisolated(unsafe) var displayLink: AnyObject?
    /// CVDisplayLink pacing path used on macOS 13, where `CADisplayLink` is unavailable.
    private nonisolated(unsafe) var legacyDisplayLink: CVDisplayLink?
    private nonisolated(unsafe) var targetFPS: Int = 60
    private nonisolated(unsafe) var lastEmittedTickTime: CFTimeInterval = 0
    private nonisolated(unsafe) var tickHandler: (@Sendable (CFTimeInterval) -> Void)?

    /// Tears down the display link without requiring the main actor so the clock can be released
    /// safely on any executor; the teardown only touches lock-guarded state and the thread-safe
    /// `CADisplayLink.invalidate()` / `CVDisplayLinkStop`.
    nonisolated deinit {
        let link: AnyObject?
        let legacyLink: CVDisplayLink?
        lock.lock()
        link = displayLink
        displayLink = nil
        legacyLink = legacyDisplayLink
        legacyDisplayLink = nil
        tickHandler = nil
        lastEmittedTickTime = 0
        lock.unlock()
        if #available(macOS 14.0, *) {
            (link as? CADisplayLink)?.invalidate()
        }
        if let legacyLink {
            CVDisplayLinkStop(legacyLink)
        }
    }

    func start(
        in view: NSView,
        targetFPS: Int,
        tickHandler: @escaping @Sendable (CFTimeInterval) -> Void
    ) {
        let normalizedTargetFPS = MirageStreamCadenceTarget.normalizedFPS(targetFPS)
        lock.lock()
        let alreadyRunning: Bool
        do {
            defer { lock.unlock() }
            self.targetFPS = normalizedTargetFPS
            self.tickHandler = tickHandler
            alreadyRunning = displayLink != nil || legacyDisplayLink != nil
        }

        guard !alreadyRunning else { return }

        guard #available(macOS 14.0, *) else {
            startLegacyDisplayLink(for: view)
            return
        }

        let createdLink = view.displayLink(target: self, selector: #selector(displayLinkDidTick(_:)))
        createdLink.preferredFrameRateRange = Self.frameRateRange(for: normalizedTargetFPS)
        createdLink.add(to: .main, forMode: .common)

        lock.lock()
        do {
            defer { lock.unlock() }
            displayLink = createdLink
            lastEmittedTickTime = 0
        }
    }

    /// Starts a CVDisplayLink bound to the view's current display. Ticks arrive on the
    /// CVDisplayLink thread; `emitTick` already throttles under the lock, and the consumer
    /// trampolines back to the main actor.
    private func startLegacyDisplayLink(for view: NSView) {
        var createdLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&createdLink)
        guard let createdLink else {
            MirageLogger.error(.renderer, "Failed to create CVDisplayLink for presentation pacing")
            return
        }
        if let screenNumber = view.window?.screen?
            .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            CVDisplayLinkSetCurrentCGDisplay(createdLink, CGDirectDisplayID(screenNumber.uint32Value))
        }
        CVDisplayLinkSetOutputHandler(createdLink) { [weak self] _, inNow, _, _, _ in
            // Gate on the vsync-periodic callback timestamp rather than the
            // wall-clock delivery time: callback delivery jitter otherwise
            // makes the emit gate swallow real vsyncs and drop presented frames.
            let hostFrequency = CVGetHostClockFrequency()
            let now = hostFrequency > 0
                ? Double(inNow.pointee.hostTime) / hostFrequency
                : CACurrentMediaTime()
            self?.emitTick(now: now)
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(createdLink)

        lock.lock()
        do {
            defer { lock.unlock() }
            legacyDisplayLink = createdLink
            lastEmittedTickTime = 0
        }
    }

    func updateTargetFPS(_ fps: Int) {
        let normalizedTargetFPS = MirageStreamCadenceTarget.normalizedFPS(fps)
        let link: AnyObject?
        lock.lock()
        targetFPS = normalizedTargetFPS
        link = displayLink
        lock.unlock()
        if #available(macOS 14.0, *) {
            (link as? CADisplayLink)?.preferredFrameRateRange = Self.frameRateRange(for: normalizedTargetFPS)
        }
        // The CVDisplayLink path runs at the display refresh rate and relies on
        // emitTick throttling to honor the target FPS.
    }

    func stop() {
        let link: AnyObject?
        let legacyLink: CVDisplayLink?
        lock.lock()
        link = displayLink
        displayLink = nil
        legacyLink = legacyDisplayLink
        legacyDisplayLink = nil
        tickHandler = nil
        lastEmittedTickTime = 0
        lock.unlock()

        if #available(macOS 14.0, *) {
            (link as? CADisplayLink)?.invalidate()
        }
        if let legacyLink {
            CVDisplayLinkStop(legacyLink)
        }
    }

    nonisolated static func shouldEmitTick(
        lastEmittedTickTime: CFTimeInterval,
        now: CFTimeInterval,
        targetFPS: Int
    ) -> Bool {
        guard lastEmittedTickTime > 0 else { return true }
        let interval = 1.0 / Double(MirageStreamCadenceTarget.normalizedFPS(targetFPS))
        return now - lastEmittedTickTime >= interval * 0.90
    }

    nonisolated static func shouldRestartDisplayLink(
        currentDisplayID: CGDirectDisplayID?,
        newDisplayID: CGDirectDisplayID?
    ) -> Bool {
        currentDisplayID != newDisplayID
    }

    nonisolated private static func frameRateRange(for targetFPS: Int) -> CAFrameRateRange {
        let preferred = Float(MirageStreamCadenceTarget.normalizedFPS(targetFPS))
        return CAFrameRateRange(minimum: preferred, maximum: preferred, preferred: preferred)
    }

    @available(macOS 14.0, *)
    @objc private func displayLinkDidTick(_ displayLink: CADisplayLink) {
        emitTick(now: displayLink.timestamp)
    }

    /// Emits a throttled tick. Safe to call from any thread; state is lock-guarded.
    nonisolated private func emitTick(now: CFTimeInterval) {
        let handler: (@Sendable (CFTimeInterval) -> Void)?

        lock.lock()
        do {
            defer { lock.unlock() }
            guard Self.shouldEmitTick(
                lastEmittedTickTime: lastEmittedTickTime,
                now: now,
                targetFPS: targetFPS
            ) else {
                handler = nil
                return
            }
            lastEmittedTickTime = now
            handler = tickHandler
        }

        handler?(now)
    }
}

final class MirageMacDisplayTickRelay: @unchecked Sendable {
    typealias EnqueueDelivery = @Sendable (@escaping @MainActor () -> Void) -> Void

    private let lock = NSLock()
    private let enqueueDelivery: EnqueueDelivery
    private let deliver: @MainActor (CFTimeInterval) -> Void
    private var latestReferenceTime: CFTimeInterval?
    private var deliveryPending = false
    private var coalescedCallbackCount: UInt64 = 0

    init(
        enqueueDelivery: @escaping EnqueueDelivery = { action in
            Task { @MainActor in
                action()
            }
        },
        deliver: @escaping @MainActor (CFTimeInterval) -> Void
    ) {
        self.enqueueDelivery = enqueueDelivery
        self.deliver = deliver
    }

    func receive(referenceTime: CFTimeInterval) {
        let shouldSchedule: Bool
        lock.lock()
        latestReferenceTime = referenceTime
        shouldSchedule = !deliveryPending
        if shouldSchedule {
            deliveryPending = true
        } else {
            coalescedCallbackCount &+= 1
        }
        lock.unlock()

        guard shouldSchedule else { return }
        enqueueDelivery { [weak self] in
            self?.deliverLatest()
        }
    }

    func cancel() {
        lock.lock()
        latestReferenceTime = nil
        deliveryPending = false
        lock.unlock()
    }

    func coalescedCallbackCountSnapshot() -> UInt64 {
        lock.lock()
        let count = coalescedCallbackCount
        lock.unlock()
        return count
    }

    @MainActor
    private func deliverLatest() {
        let referenceTime: CFTimeInterval?
        lock.lock()
        referenceTime = latestReferenceTime
        latestReferenceTime = nil
        deliveryPending = false
        lock.unlock()

        guard let referenceTime else { return }
        deliver(referenceTime)
    }
}
#endif
