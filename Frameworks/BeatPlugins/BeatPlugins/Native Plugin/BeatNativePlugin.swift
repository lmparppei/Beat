//
//  BeatNativePlugin.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 6.11.2024.
//

/**

 Simple, bare-bones definition for a native plugin type. Allows `dylib` plugins which work natively as part of the app, bound to a document.
 Development requires the full source code of Beat to import the required frameworks, but grants access to change basically *anything* in Beat.
 
 */
@objc public enum BeatNativePluginType: Int {
    /// Basic plugin for a single document
    case tool
    /// Plugin which works outside document scope (but can access documents)
    case standalone
    /// A plugin which is always there in the background and loaded for every single document
    case omnipresent
    /// Import plugin, has to implement `importedString`
    case documentImport
    /// Export plugin, has to implement `exportedData`
    case documentExport
}

@objc public protocol BeatNativePlugin {
    @objc var pluginName:String { get }
    @objc var minimumVersion:String { get }
    
    /// Initialization. `editor` is the current document, if applicable.
    init(editor:BeatPluginDelegate?)
    /// Called to terminate the plugin. Remember to deallocate and deregister anything you added.
    @objc func end()
    
    @objc optional func selectionDidChange(_ range:NSRange)
    @objc optional func textDidChange(_ range:NSRange)
    @objc optional func previewDidFinish()
    @objc optional func outlineDidChange(_ changes:OutlineChanges)
    
    @objc optional func exportedData(_ data:Data) -> Data?
    @objc optional func importedString(_ string:String) -> String?
}

