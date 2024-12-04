//
//  BeatFileExportManager.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//


import Foundation
import BeatCore

fileprivate var exportModules = [BeatRTFExport.self, BeatFDXExport.self, OutlineExtractor.self]

struct BeatFileExportHandlerInfo {
	var format:String
	var fileTypes:[String]
	var supportedStyles:[String]
	var handler:((_ delegate:BeatEditorDelegate) -> Any?)
}

@objc public class BeatFileExportManager:NSObject {
	@objc public static let shared = BeatFileExportManager()
	var registeredHandlers:[BeatFileExportHandlerInfo] = []
	
	override public init() {
		super.init()
		
		// Register all available export modules here
		BeatFDXExport.register(self)
        BeatRTFExport.register(self)
		OutlineExtractor.register(self)
        
        #if os(macOS)
        BeatDocxExport.register(self)
        #endif
	}
		
	/// Registers the given handler, called by export modules
	@objc public func registerHandler(for format:String, fileTypes:[String], supportedStyles:[String], handler:@escaping ((_ delegate:BeatEditorDelegate) -> Any?)) {
		let handler = BeatFileExportHandlerInfo(format: format, fileTypes: fileTypes, supportedStyles: supportedStyles, handler: handler)
		registeredHandlers.append(handler)
	}
	
	/// Returns the export handler for given format type
	func handlerForFormat(_ format:String) -> BeatFileExportHandlerInfo? {
		for handler in registeredHandlers {
			if handler.format == format {
				return handler
			}
		}
		
		return nil
	}
	
	/// Check if the handler for given format is actually supported by this style
	@objc public func formatSupportedByStyle(format:String, style:String) -> Bool {
		guard let handler = handlerForFormat(format) else { print("    .... no handler"); return false }
		return handler.supportedStyles.contains(style)
	}

	
	/// Shows save panel and exports the file.
    /// - note This method is a mess. Maybe migrate completely to the way iOS handles this: exporter module stores a temporary URL and if it's available, a save panel is shown.
    /// - returns URL to temporary
	@objc public func export(delegate:BeatEditorDelegate, format:String) -> URL? {
		guard let exporter = handlerForFormat(format) else {
			print("No handler for this format")
			return nil
		}
		
#if os(macOS)
		let savePanel = NSSavePanel()
		
		savePanel.allowedFileTypes = exporter.fileTypes
		savePanel.nameFieldStringValue = delegate.fileNameString() ?? ""
		
        var resultURL:URL?
        
		savePanel.beginSheetModal(for: delegate.documentWindow) { response in
			guard response == .OK,
				  let url = savePanel.url
			else { return }
			
			if let data = exporter.handler(delegate) {
				resultURL = self.handleData(data, url: url)
			}
		}
        
        return resultURL
#else
        if let data = exporter.handler(delegate) {
            let url = BeatPaths.urlForTemporaryFile(name: delegate.fileNameString(), pathExtension: exporter.fileTypes.first ?? "")
            return self.handleData(data, url: url)
        }
        
        return nil
#endif
	}
    
    		
	func handleData(_ value:Any, url:URL) -> URL? {
		if let data = value as? NSData {
			// This is data
			data.write(to: url, atomically: true)
		} else if let string = value as? String {
			// String
			do {
				try string.write(to: url, atomically: true, encoding: .utf8)
                return url
			} catch {
				print("Could not save:", error)
			}
		} else {
			// Lets just take it in as Swift data
			if let data = value as? Data {
				do {
					try data.write(to: url, options: .atomic)
                    return url
				} catch {
					print("ERROR", error)
				}
			}
		}
        
        return nil
	}
}
