//
//  BeatPlugin+Clipboard.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 6.5.2026.
//

import Foundation
import UXKit
import JavaScriptCore

@objc public protocol BeatPluginPasteboardExports:JSExport {
    func writeToPasteboard(_ string:String)
    func readFromPasteboard() -> String?
}

@objc extension BeatPlugin: BeatPluginPasteboardExports {
    
    @objc public func writeToPasteboard(_ string:String) {
        #if os(macOS)
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
    
    @objc public func readFromPasteboard() -> String? {
        #if os(macOS)
        return UXPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
    
}
