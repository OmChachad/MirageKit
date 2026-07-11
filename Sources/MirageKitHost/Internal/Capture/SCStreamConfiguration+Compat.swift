//
//  SCStreamConfiguration+Compat.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 7/9/26.
//

#if os(macOS)
import ScreenCaptureKit

extension SCStreamConfiguration {
    /// Requests best-quality capture resolution on macOS 14+. Earlier releases
    /// lack `captureResolution` and always capture at the explicit dimensions,
    /// which only matters for compile-time support: hosts run newer releases.
    func mirageSetBestCaptureResolution() {
        if #available(macOS 14.0, *) {
            captureResolution = .best
        }
    }
}
#endif
