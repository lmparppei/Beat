//
//  DiffViewerTextView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore
import AppKit

// MARK: - Supporting Classes

class DiffViewerTextView: NSTextView {
	weak var editor: BeatEditorDelegate?
	var magnification = 1.3
	var scaled = false
	
	var contextMenu:NSMenu?
	
	override var frame: NSRect {
		didSet {
			updateTextLayout()
		}
	}
	
	func setup(editorDelegate: BeatEditorDelegate) {
		editor = editorDelegate
		
		textContainer?.widthTracksTextView = false
		textContainer?.lineFragmentPadding = BeatTextView.linePadding()
		
		updateTextLayout()
		
		if !scaled {
			scaleUnitSquare(to: CGSize(width: magnification, height: magnification))
			scaled = true
		}
	}
	
	private func updateTextLayout() {
		guard let editor = editor else { return }
		
		let scrollWidth = enclosingScrollView?.frame.size.width ?? 0.0
		let documentWidth = editor.documentWidth
		
		let insetWidth = (scrollWidth / 2 - documentWidth * magnification / 2) / magnification
		
		textContainerInset = CGSize(width: insetWidth, height: 10.0)
		textContainer?.containerSize = CGSize(width: documentWidth, height: .greatestFiniteMagnitude)
	}
	
	override func menu(for event: NSEvent) -> NSMenu? {
		if event.type == .rightMouseDown {
			let menu = super.menu(for: event)
			
			menu?.addItem(.separator())
			
			let prevItem = NSMenuItem(title: "Previous Change", action: #selector(previousRevision), keyEquivalent: "\u{001e}")
			prevItem.keyEquivalentModifierMask.insert(.control)
			let nextItem = NSMenuItem(title: "Next Change", action: #selector(nextRevision), keyEquivalent: "\u{001f}")
			nextItem.keyEquivalentModifierMask.insert(.control)
			
			menu?.addItem(prevItem)
			menu?.addItem(nextItem)
			
			return menu
		}
		
		return super.menu(for: event)
	}
	
	@IBAction func previousRevision(_ sender:Any?) {
		guard let textStorage else { return }
		
		let loc = self.selectedRange().location
		let range = NSMakeRange(0, loc)
		
		textStorage.enumerateAttribute(BeatVersionControl.diffAttributeKey, in: range, options: .reverse) { value, range, stop in
			guard value != nil else { return }
			
			stop.pointee = true
			self.setSelectedRange(range)
			self.scrollRangeToVisible(range)
		}
	}
	
	@IBAction func nextRevision(_ sender:Any?) {
		guard let textStorage else { return }
		
		let loc = NSMaxRange(self.selectedRange())
		let range = NSMakeRange(loc, self.text.count - loc)
		
		textStorage.enumerateAttribute(BeatVersionControl.diffAttributeKey, in: range) { value, range, stop in
			guard value != nil else { return }
			
			stop.pointee = true
			self.setSelectedRange(range)
			self.scrollRangeToVisible(range)
		}
	}
	
}
