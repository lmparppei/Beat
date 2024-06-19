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
class BeatTagEditor:NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate {
	
	class func openTagEditor(delegate:BeatEditorDelegate) {
		let storyboard = NSStoryboard(name: "BeatTagEditor", bundle: .main)
		let wc:NSWindowController? = storyboard.instantiateController(withIdentifier: "TagEditorWindow") as? NSWindowController
		
		wc?.window?.parent = delegate.documentWindow
		wc?.window?.level = .floating
		
		let vc = wc?.contentViewController as? BeatTagEditor
		vc?.delegate = delegate
		
		wc?.showWindow(wc?.window)
		vc?.reload()
	}
	
	weak var delegate:BeatEditorDelegate? {
		/// When delegate is set, we'll register the change listener
		didSet {
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
	
	func windowWillClose(_ notification: Notification) {
		self.delegate?.removeChangeListeners(for: self)
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
		}
	}
	
	
	// MARK: - Left-side outline data source and delegate
	
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
	@IBOutlet weak var deleteButton:NSButton?
	
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
		// First reset controls
		self.tagName?.isEditable = false
		self.renameButton?.isEnabled = false
		self.deleteButton?.isEnabled = false
		
		if let tag {
			self.containerView?.isHidden = false
			
			self.tag = tag
			self.tagName?.stringValue = tag.name
			self.tagType?.attributedStringValue = BeatTagging.styledTag(for: tag.typeAsString()) ?? NSAttributedString()
			
			// You can't rename characters
			if tag.type != .CharacterTag {
				renameButton?.isEnabled = true
				deleteButton?.isEnabled = true
			}
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
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		if let scene = item as? OutlineScene {
			delegate?.scroll(to: scene.line)
		}
		
		return true
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

