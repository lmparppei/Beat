//
//  BeatCompatibility.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 19.8.2024.
//

import Foundation

#if os(macOS)
typealias BXFont = NSFont
typealias BXColor = NSColor
typealias BXImage = NSImage
#else
typealias BXFont = UIFont
typealias BXColor = UIColor
typealias BXColor = UIImage
#endif
