//
//  BeatTagEditorView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

/// The actual editor view for each tag
class BeatTagEditorView:NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	var delegate:BeatEditorDelegate?
	var tagging:BeatTagging? { return delegate?.tagging }
	
	@IBOutlet weak var tagName:BeatTagNameField?
	@IBOutlet weak var tagType:NSTextField?
	@IBOutlet weak var sceneList:NSOutlineView?
	@IBOutlet weak var renameButton:NSButton?
	@IBOutlet weak var deleteButton:NSButton?
	
	@IBOutlet weak var containerView:NSView?
	
	weak var host:BeatTagEditor?
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
			delegate?.scroll(to: NSMakeRange(scene.line.position, 0), callback: {})
			//delegate?.scroll(to: scene.line)
		}
		
		return true
	}
	
	// MARK: - Actions
	
	@IBAction func rename(_ sender:Any?) {
		self.tagName?.isEditable = true
		self.tagName?.becomeFirstResponder()
	}

	/// Called on pressing enter in tag name field
	@IBAction func renameCommit(_ sender:BeatTagNameField) {
		// Something went wrong
		guard let tagName else { return }

		if tagName.stringValue.count > 0 {
			self.tag?.name = tagName.stringValue
			self.host?.reload()
		} else {
			// Empty value
			self.tagName?.stringValue = self.tagName?.originalText ?? ""
		}
		
		tagName.isEditable = false
		tagName.window?.makeFirstResponder(nil)
	}
	
}
