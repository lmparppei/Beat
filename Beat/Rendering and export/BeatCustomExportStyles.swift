//
//  BeatCustomExportStyles.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 
 This acts as an interface between BeatPrint and custom styles in BeatExportSettings.
 Custom styles are files named something.beatStyle and they automatically show up in the
 print dialog when present in the app container.
 
 
 */

import Cocoa

protocol BeatExportStyleCellDelegate:NSObject {
	func loadPreview()
}

class BeatCustomExportStyles: NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate, BeatExportStyleCellDelegate {
	
	var styleURLS:[URL]?
	@IBOutlet weak var printDialog:BeatPrintDialog?
	
	class func styles () -> Array<URL> {
		// Find style files both in user directory and inside the app container
		
		let suffix = ".beatStyle"
		let innerStyles = Bundle.main.urls(forResourcesWithExtension: suffix, subdirectory: nil)
		
		let externalPath = BeatAppDelegate.appDataPath("Styles")
		var outerStyles:[String] = []
		
		var styles:[URL] = []
		
		do {
			outerStyles = try FileManager.default.contentsOfDirectory(atPath: externalPath?.path ?? "")
		} catch {
			NSLog("ALERT: Styles directory could not be found")
		}
				
		for filename in outerStyles {
			if filename.count < "beatStyle".count { continue }
			if !filename.hasSuffix("beatStyle") { continue }
			
			
			let url = URL(fileURLWithPath: externalPath!.path + "/" + filename)
			if FileManager.default.fileExists(atPath: url.path) && url.isFileURL {
				styles.append(url)
			}
		}
		
		styles.append(contentsOf: innerStyles!)
		
		return styles
	}
	
	override func awakeFromNib() {
		self.delegate = self
		self.dataSource = self
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if (item == nil) {
			styleURLS = BeatCustomExportStyles.styles()
			return styleURLS!.count
		} else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return false
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if (styleURLS == nil) {
			styleURLS = BeatCustomExportStyles.styles()
		}
		
		return styleURLS![index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		return nil
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CustomStyleCell"), owner: nil) as! BeatExportStyleCell
		let url = item as! URL
		let filename = (url.lastPathComponent as NSString).deletingPathExtension
		view.delegate = self
		
		view.textField?.stringValue = filename
		view.url = url
		
		return view
	}
	
	@objc func customCSS() -> String {
		var maxNumber = self.styleURLS!.count - 1
		if maxNumber < 0 {
			maxNumber = 0
		}
		
		var urls:[URL] = []
		
		for i in 0...self.numberOfRows - 1 {
			let view = self.view(atColumn: 0, row: i, makeIfNecessary: false)
			let styleView = view as? BeatExportStyleCell
			
			if styleView != nil {
				if styleView?.checkbox?.state == .on {
					urls.append(styleView!.url!)
				}
			}
		}
		
		return cssFromURLS(styleURLs: urls)
	}
	
	func cssFromURLS(styleURLs: [URL]) -> String {
		var css = ""
		
		for styleURL in styleURLs {
			do {
				let cssString = try String(contentsOf: styleURL)
				css += cssString + "\n\n"
			}
			catch {
				NSLog("ERROR: Could not load css: " + styleURL.lastPathComponent)
			}
		}
		
		return css
	}
	
	func loadPreview() {
		printDialog?.loadPreview()
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
		return false
	}
	
}

class BeatExportStyleCell:NSTableCellView {
	@IBOutlet var checkbox:NSButton?
	var url:URL?
	weak var delegate:BeatExportStyleCellDelegate?
	
	@IBAction func loadPreview (sender: Any?) {
		self.delegate?.loadPreview()
	}
}
/*
 
 valtakadulla
 mä istuin penkille
 ja itkin
 
 */
