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
    @objc public var defaultEditorStyles:BeatStylesheet { return self.styles(name: "Screenplay", delegate: nil, forEditor: true) }
    
    /// Default line height
    @objc class var lineHeight:CGFloat { return 12.0 }
    
    /// Available stylesheets
    var _stylesheets:[String:URL]?
    /// Currently loaded styles
    private var _loadedStyles:[String:BeatStylesheet] = [:]
    private var _documentStyles:[UUID:[String:BeatStylesheet]] = [:]
        
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
    
    @objc public func reset() {
        _stylesheets = [:]
    }
        
    @objc public func styles(name:String? = nil, delegate:BeatDocumentDelegate? = nil, forEditor:Bool = false) -> BeatStylesheet {
        let styleName = name == nil ? "" : name!
        let suffix = forEditor ? "-editor" : ""
        let defaultStyle = BeatStyles.defaultStyleName + suffix
        
        // Make sure the name isn't just an empty string
        var name = (styleName.count > 0) ? (styleName + suffix) : defaultStyle
                
#if os(iOS)
        // Adjust style for iPhone (if needed)
        if forEditor {
            if UIDevice.current.userInterfaceIdiom == .phone && styleName == "Screenplay" {
                name += "-iOS"
            }
        }
#endif
        
        let uuid:UUID? = delegate?.uuid()
        
        if let loadedStyle = _loadedStyles[name], uuid == nil {
            return loadedStyle
        } else if let uuid, let documentStyle = _documentStyles[uuid]?[name] {
            return documentStyle
        }
        
        // Get stylesheet. If it's not available, we NEED TO HAVE a file called Screenplay-editor.beatCSS, otherwise the app will crash.
        var url:URL? = stylesheets[name]
        
        // If no URL is available, first check user folder.
        // We NEED TO HAVE a file called Screenplay.beatCSS in the bundle, otherwise the app will crash.
        if url == nil, let userStyle = userStylesheet(name: name) {
            url = userStyle
        } else if url == nil {
            url = stylesheets[defaultStyle]!
        }
        
        let stylesheet = BeatStylesheet(url: url!, name: name, documentSettings: delegate?.documentSettings)
        
        if let uuid {
            if _documentStyles[uuid] == nil { _documentStyles[uuid] = [:] }
            _documentStyles[uuid]?[name] = stylesheet
        } else {
            _loadedStyles[name] = stylesheet
        }
         
        return stylesheet
    }
    
    @objc public func closeDocument(delegate:BeatDocumentDelegate) {
        _documentStyles.removeValue(forKey: delegate.uuid())
    }
    
    
    // MARK: User stylesheet support
    
    /// Returns the user stylesheet folder
    var userStylesheetURL:URL {
        get { return BeatPaths.appDataPath("Styles") }
    }
    
    /// Returns the **URL** for a stylesheet with given name (excluding `-editor` and extension)
    func userStylesheet(name:String) -> URL? {
        let url = BeatPaths.appDataPath("Styles").appendingPathComponent(name + ".beatCSS")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    /// A list of all available user stylesheet NAMES
    @objc public func availableUserStylesheets() -> [String] {
        var styles:[String] = []
        
        if let files = try? FileManager.default.contentsOfDirectory(at: self.userStylesheetURL, includingPropertiesForKeys: nil) {
            for url in files as [URL] {
                let file = url.lastPathComponent as NSString
                if file.hasSuffix("beatCSS"), !file.contains("-editor") {
                    styles.append(file.deletingPathExtension as String)
                }
            }
        }
        
        return styles
    }
}
