//
//  RoundedLabel.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.1.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

class RoundedLabel:NSTextField {
	var bgColor = NSColor.white.withAlphaComponent(0.05).cgColor
	var item:BeatOutlineItemData
	weak var tableCell:BeatOutlineViewCell?
	
	init(item:BeatOutlineItemData, tableCell:BeatOutlineViewCell) {
		self.item = item
		self.tableCell = tableCell
		super.init(frame: .zero)
		
		let area = NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self)
		self.addTrackingArea(area)
				
		attributedStringValue = item.text
		
		isEditable = false
		isSelectable = false
		isBordered = false
		drawsBackground = false
		
		lineBreakMode = .byWordWrapping
		usesSingleLineMode = false
		
		cell?.wraps = true
		cell?.isScrollable = false
		
		wantsLayer = true
		layer?.cornerRadius = 8  // Rounded edges
		layer?.masksToBounds = true
		
		font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
		textColor = .white
		
		translatesAutoresizingMaskIntoConstraints = false
		
		setContentHuggingPriority(.required, for: .vertical)
		setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var intrinsicContentSize: NSSize {
		let size = super.intrinsicContentSize
		return NSSize(width: size.width, height: size.height)
	}
	
	public override func updateTrackingAreas() {
		super.updateTrackingAreas()
		if let trackingArea = self.trackingAreas.first {
			self.removeTrackingArea(trackingArea)
		}
		
		self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited], owner: self))
	}
	
	override func mouseEntered(with event: NSEvent) {
		self.layer?.backgroundColor = bgColor
	}
	override func mouseExited(with event: NSEvent) {
		self.layer?.backgroundColor = nil
	}
	
	override func mouseDown(with event: NSEvent) {
		var focus = false
		let editor = self.tableCell?.editorDelegate
		
		if let line = item.line {
			editor?.selectedRange = NSMakeRange(line.position, 0)
			editor?.scroll(to: line.range(), callback: {})
			focus = true
		} else if item.range.location != 0 && item.range.location != NSNotFound {
			editor?.selectedRange = item.range
			focus = true
		}
		
		if focus {
			editor?.focusEditor?()
		}
	}
}
