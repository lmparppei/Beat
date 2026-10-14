//
//  NSView+Layout.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 16.8.2026.
//

import Foundation

#if os(macOS)
extension NSView {
    func setNeedsDisplay() {
        self.needsDisplay = true
    }
    func setNeedsLayout() {
        self.needsLayout = true
    }
}
#endif
