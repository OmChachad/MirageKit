//
//  MirageEncoderOverrides+IntelClient.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 7/9/26.
//

import Foundation

public extension MirageEncoderOverrides {
    /// Encoder settings tuned for an Intel Mac client on macOS 13 acting as a
    /// high-resolution wired display for an Apple Silicon host over Thunderbolt.
    ///
    /// - HEVC 8-bit (`.standard`): every macOS 13-capable Intel Mac decodes
    ///   HEVC Main in hardware, while 10-bit and ProRes 4444 streams can fall
    ///   back to software decode and stall high resolutions.
    /// - A fixed manual bitrate: Thunderbolt bandwidth is not the bottleneck,
    ///   so picture quality stays pinned rather than negotiated.
    /// - Lowest-latency presentation: the wired link keeps arrival cadence
    ///   clean, and immediate presentation avoids tick-phase judder between
    ///   the host and client display clocks.
    /// - Runtime quality adjustment disabled: transient Intel decode stalls
    ///   must not trigger host-side P-frame skipping or bitrate/quality decay.
    ///   The steady state for a dedicated monitor is constant quality.
    ///
    /// Pass explicit `maxEncodedWidth`/`maxEncodedHeight` to cap the encoded
    /// surface (for example 4096x2304 on a 5K display) when the client GPU
    /// cannot sustain native-resolution decode at the target frame rate.
    static func intelDisplayClient(
        maxEncodedWidth: Int? = nil,
        maxEncodedHeight: Int? = nil
    ) -> MirageEncoderOverrides {
        MirageEncoderOverrides(
            codec: .hevc,
            colorDepth: .standard,
            enteredBitrate: 80_000_000,
            bitrate: 80_000_000,
            latencyMode: .lowestLatency,
            allowRuntimeQualityAdjustment: false,
            allowEncoderCatchUpQualityAdjustment: false,
            bitrateAdaptationCeiling: 120_000_000,
            encoderMaxWidth: maxEncodedWidth,
            encoderMaxHeight: maxEncodedHeight
        )
    }
}
