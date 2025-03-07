//
//  BXColor+Perception.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.2.2025.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif


public extension BXColor {
    @objc var isDarkAsBackground: Bool {
        // macOS and iOS have different nullability for CIColor (wtf)
        #if os(macOS)
        guard let ciColor = CIColor(color: self) else { return false }
        #else
        let ciColor = CIColor(color: self)
        #endif
        
        let luminance = (0.299 * ciColor.red) + (0.587 * ciColor.green) + (0.114 * ciColor.blue)
        return luminance < 0.5
    }
}

