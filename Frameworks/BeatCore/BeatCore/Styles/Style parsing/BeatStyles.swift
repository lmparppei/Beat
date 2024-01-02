//
//  BeatStyles.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//
/**
 
 This class provides the stylesheets to both renderer (macOS) and editor (macOS/iOS).
 
 */

import Foundation

struct BeatStylesheetInfo {
    var name:String = ""
    var URL:URL?
    var editorURL:URL?
}

public class BeatStyles:NSObject {
    @objc static public let shared = BeatStyles()
    @objc static public var defaultStyleName = "Screenplay"
    
    /// Default styles for exporting
    @objc public var defaultStyles:BeatStylesheet { return self.styles() }
    /// Default styles for editor
    @objc public var defaultEditorStyles:BeatStylesheet { return self.editorStyles() }
    
    /// Default line height
    @objc class var lineHeight:CGFloat { return 12.0 }
    
    /// Available stylesheets
    var _stylesheets:[String:URL]?
    /// Currently loaded styles
    private var _loadedStyles:[String:BeatStylesheet] = [:]

    /// Returns stylesheet dictionary with `name: url`
    var stylesheets:[String:URL] {
        // Return cached sheet names
        if _stylesheets != nil { return _stylesheets! }
        
        // Let's gather all beatCSS files from inside the bundle
        var stylesheets:[String:URL] = [:]

        let urls:[URL] = Bundle.init(for: type(of: self)).urls(forResourcesWithExtension: "beatCSS", subdirectory: nil) ?? []
        
        for url in urls {
            let name = url.lastPathComponent.replacingOccurrences(of: ".beatCSS", with: "")
            stylesheets[name] = url
        }
        
        _stylesheets = stylesheets
        return stylesheets
    }
    
    /// Returns NON-LOCALIZED stylesheet names
    var stylesheetNames:[String] {
        let keys:[String] = stylesheets.keys.map({ $0 })
        return keys
    }
    
    /// Returns the styles for given name
    @objc public func styles(for name:String = BeatStyles.defaultStyleName) -> BeatStylesheet {
        // This style is already loaded
        if _loadedStyles[name] != nil { return _loadedStyles[name]! }
        
        // Get stylesheet. If it's not available, we NEED TO HAVE a file called Screenplay.beatCSS, otherwise the app will crash.
        let url = stylesheets[name] ?? stylesheets[BeatStyles.defaultStyleName]!
        let stylesheet = BeatStylesheet(url: url)
        _loadedStyles[name] = stylesheet
        
        return stylesheet
    }
    
    @objc public func editorStyles(for styleName:String = "") -> BeatStylesheet {
        var defaultStyle = (BeatStyles.defaultStyleName + "-editor")
#if os(iOS)
        // Default styles for iOS
        if UIDevice.current.userInterfaceIdiom == .phone { defaultStyle += "-iOS" }
#endif
        
        // Make sure the name isn't just an empty string
        var name = (styleName.count > 0) ? (styleName + "-editor") : defaultStyle
        
        
        if _loadedStyles[name] != nil {
            return _loadedStyles[name]!
        }
        
        // Get stylesheet. If it's not available, we NEED TO HAVE a file called Screenplay-editor.beatCSS, otherwise the app will crash.
        let url = stylesheets[name] ?? stylesheets[defaultStyle]!
        let stylesheet = BeatStylesheet(url: url)
        _loadedStyles[name] = stylesheet
        
        return stylesheet
    }
}
