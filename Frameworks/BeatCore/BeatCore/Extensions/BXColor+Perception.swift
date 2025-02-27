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
        if let ciColor = CIColor(color: self) { // Convert to CIColor for RGBA components
            let luminance = (0.299 * ciColor.red) + (0.587 * ciColor.green) + (0.114 * ciColor.blue)
            return luminance < 0.5
        }
        return true
    }    
}

