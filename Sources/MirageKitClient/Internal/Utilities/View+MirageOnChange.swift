//
//  View+MirageOnChange.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 7/9/26.
//

import SwiftUI

extension View {
    /// Zero-parameter `onChange(of:_:)` compatibility for macOS 13, which only
    /// offers the single-value `onChange(of:perform:)` form.
    @ViewBuilder
    func mirageOnChange<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value) { action() }
        } else {
            onChange(of: value) { _ in action() }
        }
    }
}
