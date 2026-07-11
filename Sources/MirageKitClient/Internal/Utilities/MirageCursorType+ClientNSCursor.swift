//
//  MirageCursorType+ClientNSCursor.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 7/9/26.
//

#if os(macOS)
import AppKit
import MirageKit

extension MirageCursorType {
    /// NSCursor used for client-side presentation.
    ///
    /// Diagonal frame-resize cursors only exist publicly on macOS 15, so on
    /// earlier releases the client falls back to its bundled cursor images
    /// (the same assets iOS/visionOS clients render) with matching hotspots.
    var clientNSCursor: NSCursor {
        if #available(macOS 15.0, *) {
            return nsCursor
        }
        switch self {
        case .resizeNorthEast, .resizeNorthWest, .resizeSouthEast, .resizeSouthWest, .resizeNESW, .resizeNWSE:
            guard let image = Bundle.module.image(forResource: cursorImageName) else {
                return nsCursor
            }
            return NSCursor(
                image: image,
                hotSpot: NSPoint(x: cursorHotspot.x, y: cursorHotspot.y)
            )
        default:
            return nsCursor
        }
    }
}
#endif
