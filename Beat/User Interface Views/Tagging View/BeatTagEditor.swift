//
//  BeatTagEditor.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objcMembers
class BeatTagEditor:NSViewController, BeatTagManagerView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate {
	weak var delegate:BeatEditorDelegate? {
		didSet {
			/// When delegate is set, we'll register the change listener
			delegate?.addChangeListener({ [weak self] _ in self?.reload() }, owner: self)
		}
	}
	
	weak var tagging:BeatTagging? { return delegate?.tagging }
	weak var editorView:BeatTagEditorView?
	
	var tagData:[String:[TagDefinition]] = [:]
	
	@IBOutlet weak var tagList:NSOutlineView?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		// Setup
		self.view.window?.delegate = self
		self.tagList?.dataSource = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(tagsDidChange), name: NSNotification.Name(BeatTagging.notificationName()), object: nil)
	}
	
	// Reload tags when they were modified in editor
	@objc func tagsDidChange(_ notification:NSNotification?) {
		if let doc = notification?.object as? BeatEditorDelegate, doc.uuid() == self.delegate?.uuid() {
			self.reload()
		}
	}
	
	func windowWillClose(_ notification: Notification) {
		NotificationCenter.default.removeObserver(self)
		self.delegate?.removeChangeListeners(for: self)
		
		// Sorry for this hack
		if let doc = self.delegate?.document() as? Document { doc.tagManager = nil }
	}

	func reload() {
		tagData = self.tagging?.sortedTags() ?? [:]
		
		// Remember the selection and previously open sections
		var previouslySelected = -1
		var expanded:[Int] = []
		
		if let tagList, let selected = self.tagList?.selectedRow, selected != NSNotFound {
			previouslySelected = selected
			
			for i in 0..<tagList.numberOfRows {
				let item = tagList.item(atRow: i)
				if tagList.numberOfChildren(ofItem: item) > 0, tagList.isItemExpanded(item) {
					expanded.append(i)
				}
			}
		}
		
		self.tagList?.reloadData()
		
		// Expand sections again
		for i in expanded {
			let item = tagList?.item(atRow: i)
			self.tagList?.expandItem(item)
		}
		
		// Select the previously selected item again
		if self.tagList?.numberOfRows ?? 0 > previouslySelected {
			self.tagList?.selectRowIndexes([previouslySelected], byExtendingSelection: false)
		}
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		
		if segue.identifier == "TagView", let vc = segue.destinationController as? BeatTagEditorView {
			editorView = vc
			vc.host = self
		}
	}
	
	
	// MARK: - Left-side outline data source and delegate
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		if outlineView.parent(forItem: item) != nil, let tag = item as? TagDefinition {
			// Open an editor view for single tag types
			editorView?.delegate = self.delegate
			editorView?.reload(tag: tag)
		} else if outlineView.parent(forItem: item) == nil {
			// Expand selected tag types
			outlineView.expandItem(item)
		}
		
		return true
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil { return BeatTagging.categories().count }

		if let tags = tagData[item as? String ?? ""] { return tags.count }
		else { return 0 }
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil { return BeatTagging.categories()[index] }
		
		let key = item as? String ?? ""
		if let tags = tagData[key] { return tags[index] }
		
		assertionFailure()
		return ""
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return outlineView.numberOfChildren(ofItem: item) > 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		var view:NSTableCellView?
		

		if let tagName = item as? String {
			// This is a tag name
			view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CategoryCell"), owner: self) as? NSTableCellView
			view?.textField?.stringValue = BeatTagging.localizedTagName(forKey: tagName)
			
			let type = BeatTagging.tag(for: tagName)
			let color = BeatTagging.color(for: type)
			
			let image = BeatTagManager.tagIcon(type: type)
			view?.imageView?.image = image
			if #available(macOS 10.14, *) {
				view?.imageView?.contentTintColor = color
			}
						
		} else if let tag = item as? TagDefinition {
			// It's a tag definition
			view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TagCell"), owner: self) as? NSTableCellView
			view?.textField?.stringValue = tag.name
		}
		
		return view
	}
}
