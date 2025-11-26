//
//  BeatCLI+Fonts.swift
//  Beat CLI
//
//  Created by Lauri-Matti Parppei on 26.11.2025.
//

import Foundation
import CoreText

extension BeatCLI {
    /// We need to register all found fonts because a CLI app won't work as a bundle.
    static func registerFonts() {
        var urls:[URL] = []
        
        Bundle.allFrameworks.forEach { bundle in
            if let fonts = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
                urls.append(contentsOf: fonts)
            }
        }
        
        for url in urls {
            BeatCLI.registerFont(fontURL: url)
        }
    }
    
    static func registerFont(fontURL:URL) {
        var error: Unmanaged<CFError>?
        
        if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            //print("Font registered:", fontURL.lastPathComponent)
        } else {
            print("Failed to register font:", error?.takeRetainedValue() ?? "unknown error" as Any)
        }
    }
}
