//
//  TemplateView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 2.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

struct BeatTemplateFile {
	var filename:String
	var title:String
	var description:String
	var icon:String?
}

class BeatTemplateDataSource:NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
	
	/*
	var templates = [
		"Tutorials": [
			BeatTemplateFile(filename: "Tutorial.fountain", display: "Tutorial", description: "Start here if you are new to Beat!", icon: "map"),
			BeatTemplateFile(filename: "Tutorial.fountain", display: "Outlining", description: "Get started with advanced outlining", icon: "list.and.film")
			],
		"Templates": [
			BeatTemplateFile(filename: "Tutorial.fountain", display: "One-Page Synopsis", description: "Write a compact one-page synopsis"),
			BeatTemplateFile(filename: "Tutorial.fountain", display: "Three-Act Outline", description: "Get started with a three-act feature film outline"),
			BeatTemplateFile(filename: "Tutorial.fountain", display: "Comic Book", description: "Simple template for comic book script"),
		]
	]
	 */
	
	var templates:[String:[BeatTemplateFile]] = [:]

	@IBInspectable var family:String = "Templates"
	
	override func awakeFromNib() {
		guard let url = Bundle.main.url(forResource: "Templates And Tutorials", withExtension: "plist") else { return }
		let data = try! Data(contentsOf: url)
		
		guard let plist = try! PropertyListSerialization.propertyList(from: data, format: nil) as? [String:[[String:String]]] else { return }
		for key in plist.keys {
			guard let templates = plist[key] else { continue }

			if self.templates[key] == nil {
				self.templates[key] = []
			}
			
			for template in templates {
				let t = BeatTemplateFile(filename: template["filename"] ?? "", title: template["title"] ?? "", description: template["description"] ?? "", icon: template["icon"] ?? "")
				self.templates[key]?.append(t)
			}
		}
		
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item != nil { return 0 }
		
		return templates[family]?.count ?? 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return templates[family]?[index] as Any
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { return false }
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TemplateView"), owner: self) as! BeatTemplateCell
		guard let template = item as? BeatTemplateFile else {
			return nil
		}
		view.load(template: template)
		
		return view
	}
	
}

class BeatTemplateCell:NSTableCellView {
	var template:BeatTemplateFile?
	@IBOutlet var subtitle:NSTextField?
	@IBOutlet var image:NSImageView?
	
	override func awakeFromNib() {
		self.window?.acceptsMouseMovedEvents = true

		let trackingArea:NSTrackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
		self.addTrackingArea(trackingArea)
		
		self.wantsLayer = true
		self.layer?.cornerRadius = 5.0
	}
	
	func load(template:BeatTemplateFile) {
		self.textField?.stringValue = BeatLocalization.localizedString(forKey: template.title)
		self.subtitle?.stringValue = BeatLocalization.localizedString(forKey: template.description)
		
		if (template.icon?.count ?? 0 > 0) {
			var icon = NSImage(named: template.icon!)
			if (icon == nil) {
				if #available(macOS 11.0, *) {
					// We don't need accessibility description here, because the button already has one
					icon = NSImage(systemSymbolName: template.icon!, accessibilityDescription: "")
				}
			}
			
			
			if (icon != nil) { image?.image = icon }
		}
	}
	
	override func mouseEntered(with event: NSEvent) {
		if #available(macOS 10.14, *) {
			self.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
		}
		super.mouseEntered(with: event)
	}
	override func mouseExited(with event: NSEvent) {
		self.layer?.backgroundColor = NSColor.clear.cgColor
		super.mouseExited(with: event)
	}
}
