//
//  LoomOrderedAsyncSubmitter.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/30/26.
//

import Foundation

package final class LoomOrderedAsyncSubmitter: @unchecked Sendable {
    private struct PendingOperation {
        let operation: (@escaping @Sendable () -> Void) -> Void
        let onDropped: @Sendable () -> Void
    }

    private let stateLock = NSLock()
    private var pendingOperations: [PendingOperation] = []
    private var isProcessing = false
    private var isClosed = false

    package init() {}

    package func enqueue(
        operation: @escaping (@escaping @Sendable () -> Void) -> Void,
        onDropped: @escaping @Sendable () -> Void
    ) {
        stateLock.lock()
        if isClosed {
            stateLock.unlock()
            onDropped()
            return
        }
        pendingOperations.append(PendingOperation(operation: operation, onDropped: onDropped))
        let nextOperation: PendingOperation?
        if isProcessing {
            nextOperation = nil
        } else {
            isProcessing = true
            nextOperation = pendingOperations.removeFirst()
        }
        stateLock.unlock()

        guard let nextOperation else { return }
        run(nextOperation)
    }

    package func close() {
        stateLock.lock()
        guard !isClosed else {
            stateLock.unlock()
            return
        }
        isClosed = true
        let droppedOperations = pendingOperations
        pendingOperations.removeAll(keepingCapacity: false)
        stateLock.unlock()
        droppedOperations.forEach { $0.onDropped() }
    }

    private func run(_ operation: PendingOperation) {
        operation.operation { [weak self] in
            self?.completeOperation()
        }
    }

    private func completeOperation() {
        stateLock.lock()
        let nextOperation: PendingOperation?
        if pendingOperations.isEmpty {
            isProcessing = false
            nextOperation = nil
        } else {
            nextOperation = pendingOperations.removeFirst()
        }
        stateLock.unlock()
        guard let nextOperation else { return }
        run(nextOperation)
    }
}
