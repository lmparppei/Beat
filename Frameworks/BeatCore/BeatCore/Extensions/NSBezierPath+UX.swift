//
//  NSBezierPath+UX.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 19.11.2023.
//

import Foundation

@objc public extension NSBezierPath {
    @objc func test() {
        print("OK")
    }
    
#if os(macOS)
    @objc func addLineToPoint (_ point:CGPoint) {
        self.line(to: point)
    }
#endif
}
