//
//  BeatFileExportManager.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

fileprivate var exportModules = [BeatRTFExport.self]

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
	
	/// Shows save panel and exports the file
	@objc public func export(delegate:BeatEditorDelegate, format:String) {
		guard let exporter = handlerForFormat(format) else {
			print("No handler for this format")
			return
		}
		
		let savePanel = NSSavePanel()
		
		savePanel.allowedFileTypes = exporter.fileTypes
		savePanel.nameFieldStringValue = delegate.fileNameString() ?? ""
		
		savePanel.beginSheetModal(for: delegate.documentWindow) { response in
			guard response == .OK,
				  let url = savePanel.url
			else { return }
			
			if let data = exporter.handler(delegate) {
				self.handleData(data, url: url)
			}
		}
	}
		
	func handleData(_ value:Any, url:URL) {
		if let data = value as? NSData {
			// This is data
			data.write(to: url, atomically: true)
		} else if let string = value as? String {
			// String
			do {
				try string.write(to: url, atomically: true, encoding: .utf8)
			} catch {
				print("Could not save:", error)
			}
		} else {
			// Lets just take it in as Swift data
			if let data = value as? Data {
				do {
					try data.write(to: url, options: .atomic)
				} catch {
					print("ERROR", error)
				}
			}
		}
	}
}

extension BeatFileExportManager {
	
}
class BeatFileExportMenuItem:NSMenuItem {
	@IBInspectable var format:String = ""
	
	override init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
		super.init(title: string, action: #selector(export), keyEquivalent: "")
		self.target = BeatFileExportManager.shared
	}
	
	required init(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	@objc public func export() {
		
	}
}
