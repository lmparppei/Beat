//
//  TemplateView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 2.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

public class BeatTemplateDataSource:NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
	public var templates = BeatTemplates.shared()

	// Set this in IB to adjust which family of templates we are showing
	@IBInspectable var family:String = "Templates"
		
	public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item != nil { return 0 }
		return templates.forFamily(self.family).count
	}
	
	public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return templates.forFamily(self.family)[index] as Any
	}
	
	public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { return false }
	
	public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TemplateView"), owner: self) as! BeatTemplateCell
		guard let template = item as? BeatTemplateFile else {
			return nil
		}
		view.load(template: template)
		
		return view
	}
	
	public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		// Load the selected template
		guard let template = item as? BeatTemplateFile,
			  let url = template.url
		else { return false }

		do {
			let string = try String(contentsOf: url)
			let appDelegate = NSApp.delegate as? BeatAppDelegate
			appDelegate?.newDocument(withContents: string)
		} catch {
			print("Error loading template")
		}
		
		return false
	}
}

public class BeatTemplateCell:NSTableCellView {
	public var template:BeatTemplateFile?
	@IBOutlet var subtitle:NSTextField?
	@IBOutlet var image:NSImageView?
	
	override public func awakeFromNib() {
		self.window?.acceptsMouseMovedEvents = true

		let trackingArea:NSTrackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
		self.addTrackingArea(trackingArea)
		
		self.wantsLayer = true
		self.layer?.cornerRadius = 5.0
	}
	
	public func load(template:BeatTemplateFile) {
		self.textField?.stringValue = template.title
		self.subtitle?.stringValue = template.description
		
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
	
	override public func mouseEntered(with event: NSEvent) {
		if #available(macOS 10.14, *) {
			self.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
		}
		super.mouseEntered(with: event)
	}
	override public func mouseExited(with event: NSEvent) {
		self.layer?.backgroundColor = NSColor.clear.cgColor
		super.mouseExited(with: event)
	}
}
