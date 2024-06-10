//
//  BeatTagView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.6.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objcMembers
class BeatTagEditor:NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
	
	weak var delegate:BeatEditorDelegate?
	weak var tagging:BeatTagging? { return delegate?.tagging }
	weak var editorView:BeatTagEditorView?
	
	var tagData:[String:[TagDefinition]] = [:]
	
	@IBOutlet weak var tagList:NSOutlineView?
		
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.tagList?.dataSource = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	func reload() {
		tagData = self.tagging?.sortedTags() ?? [:]
		self.tagList?.reloadData()
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		
		if segue.identifier == "TagView", let vc = segue.destinationController as? BeatTagEditorView {
			editorView = vc
		}
	}
	
	
	// MARK: Left-side outline view
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		// Don't allow selecting tag types
		if outlineView.parent(forItem: item) == nil { return false }

		if let tag = item as? TagDefinition {
			editorView?.delegate = self.delegate
			editorView?.reload(tag: tag)
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
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TagCell"), owner: self) as? NSTableCellView
		
		if let tagName = item as? String {
			// This is a tag name
			let label = BeatTagging.styledTag(for: tagName) ?? NSAttributedString()
			view?.textField?.attributedStringValue = label
		} else if let tag = item as? TagDefinition {
			// It's a tag definition
			view?.textField?.stringValue = tag.name
		}
		
		return view
	}
}

/// The actual editor view for each tag
class BeatTagEditorView:NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	var delegate:BeatEditorDelegate?
	var tagging:BeatTagging? { return delegate?.tagging }
	
	@IBOutlet weak var tagName:NSTextField?
	@IBOutlet weak var tagType:NSTextField?
	@IBOutlet weak var sceneList:NSOutlineView?
	@IBOutlet weak var renameButton:NSButton?
	
	@IBOutlet weak var containerView:NSView?
	
	weak var tag:TagDefinition?
	var scenes:[OutlineScene] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.containerView?.isHidden = true
		self.sceneList?.delegate = self
		self.sceneList?.dataSource = self
	}
		
	func reload(tag:TagDefinition?) {
		self.tagName?.isEditable = false
		self.renameButton?.isEnabled = false
		
		if let tag {
			self.containerView?.isHidden = false
			
			self.tag = tag
			self.tagName?.stringValue = tag.name
			self.tagType?.attributedStringValue = BeatTagging.styledTag(for: tag.typeAsString()) ?? NSAttributedString()
			
			// You can't rename characters
			if tag.type != .CharacterTag { renameButton?.isEnabled = true }
		} else {
			// Empty
			self.containerView?.isHidden = true
		}
		
		// Gather scenes with tags
		scenes = self.tagging?.scenes(for: tag) ?? []
		
		self.sceneList?.reloadData()
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		return (item == nil) ? scenes.count : 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return self.scenes[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SceneCell"), owner: self) as? NSTableCellView
		
		if let scene = item as? OutlineScene, let delegate = self.delegate {
			let outlineItem = OutlineViewItem.withScene(scene, currentScene: delegate.currentScene ?? OutlineScene(), sceneNumber: true, synopsis: true, notes: true, markers: true, isDark: delegate.isDark())
			view?.textField?.attributedStringValue = outlineItem
		}
		
		return view
	}
	
	// MARK: - Actions
	
	@IBAction func rename(_ sender:Any?) {
		self.tagName?.isEditable = true
		self.tagName?.becomeFirstResponder()
	}

	@IBAction func renameCommit(_ sender:NSTextField) {
		self.tagName?.isEditable = false
		self.tagName?.window?.makeFirstResponder(nil)
	}
	
}


class BeatTagNameField:NSTextField {
	var originalText = ""
	override var isEditable: Bool {
		didSet {
			if (isEditable) { originalText = self.stringValue }
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		if self.isEditable {
			self.window?.makeFirstResponder(nil)
			
			self.isEditable = false
			self.stringValue = originalText
		}
	}
	
	
}

