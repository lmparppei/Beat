//
//  BeatClippingView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

class BeatClippingView:NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate, BeatEditorView {
	@IBOutlet var enclosingTabView:NSTabViewItem?
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	
	var timer:Timer = Timer()
	
	var clippings:BeatSnippets?

	override func awakeFromNib() {
		self.delegate = self
		self.dataSource = self
		self.editorDelegate?.register(self)
	}
	
	func reload() {
		if clippings == nil, let editor = editorDelegate {
			clippings = BeatSnippets(editor: editor)
		}
		
		print("Data source", self.dataSource)
		print("Delegate", self.delegate)
		
		super.reloadData()
	}
	
	func visible() -> Bool {
		return true
	}
	
	func reloadInBackground() {
		timer.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
			self.reload()
		})
	}
	
	
	// MARK: - Outline view data source
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
		return false
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return false
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		guard let clippings else { return 0 }
		
		return item == nil ? clippings.library().count : 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		print("Child ", index)
		if let clippings = clippings?.library() {
			return clippings[index]
		} else {
			return "Faulty item"
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		return nil
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ClippingCell"), owner: nil) as? BeatClippingCellView
		if let clipping = item as? BeatSnippet {
			view?.textView?.string = clipping.text
		}
		
		return view
	}
}

class BeatClippingCellView:NSTableCellView {
	@IBOutlet var textView:NSTextView?
}
