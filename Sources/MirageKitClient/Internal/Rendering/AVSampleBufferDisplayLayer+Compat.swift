//
//  AVSampleBufferDisplayLayer+Compat.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 7/9/26.
//

import AVFoundation
import CoreMedia

/// Compatibility surface over `AVSampleBufferDisplayLayer` playback control.
///
/// macOS 14 moved enqueue/flush/status onto `sampleBufferRenderer`, while
/// macOS 13 only exposes the equivalent layer-level API. These helpers pick
/// the right path at runtime so presenter code stays uniform across releases.
extension AVSampleBufferDisplayLayer {
    var mirageIsReadyForMoreMediaData: Bool {
        if #available(macOS 14.0, *) {
            return sampleBufferRenderer.isReadyForMoreMediaData
        }
        return isReadyForMoreMediaData
    }

    var mirageStatusIsFailed: Bool {
        if #available(macOS 14.0, *) {
            return sampleBufferRenderer.status == .failed
        }
        return status == .failed
    }

    var mirageRendererError: Error? {
        if #available(macOS 14.0, *) {
            return sampleBufferRenderer.error
        }
        return error
    }

    func mirageEnqueue(_ sampleBuffer: CMSampleBuffer) {
        if #available(macOS 14.0, *) {
            sampleBufferRenderer.enqueue(sampleBuffer)
        } else {
            enqueue(sampleBuffer)
        }
    }

    func mirageFlush(removingDisplayedImage: Bool) {
        if #available(macOS 14.0, *) {
            sampleBufferRenderer.flush(removingDisplayedImage: removingDisplayedImage, completionHandler: nil)
        } else if removingDisplayedImage {
            flushAndRemoveImage()
        } else {
            flush()
        }
    }
}
