//
//  NSBezierPath+UX.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 19.11.2023.
//

import Foundation

#if os(macOS)

@objc public extension NSBezierPath {
    /** iOS compatibility alias for to `lineToPoint` */
    @objc func addLineToPoint (_ point:CGPoint) {
        self.line(to: point)
    }
}

#endif

