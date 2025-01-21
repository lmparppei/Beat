//
//  BeatTextView extensions.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 5.2.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

fileprivate let INTERCELL_SPACING: CGFloat = 5.0
fileprivate let POPOVER_WIDTH: CGFloat = 200.0
fileprivate let POPOVER_PADDING: CGFloat = 10.0
fileprivate let POPOVER_APPEARANCE = NSAppearance.Name.aqua

public extension BeatTextView {
	@objc func setupPopovers() {
		// Create NSTableView
		let tableView = NSTableView(frame: NSZeroRect)
		tableView.selectionHighlightStyle = .regular
		tableView.backgroundColor = NSColor.clear
		tableView.rowSizeStyle = .small
		tableView.intercellSpacing = NSSize(width: INTERCELL_SPACING, height: INTERCELL_SPACING)
		tableView.headerView = nil
		tableView.refusesFirstResponder = true
		tableView.target = self
		tableView.doubleAction = #selector(clickPopupItem)

		tableView.dataSource = self
		tableView.delegate = self

		// Avoid the "modern" padding on Big Sur
		if #available(macOS 11.0, *) {
			tableView.style = .fullWidth
		}

		// Create column
		let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
		column.isEditable = false
		column.width = POPOVER_WIDTH - 2 * POPOVER_PADDING

		tableView.addTableColumn(column)

		self.autocompleteTableView = tableView

		// Create the enclosing scroll view
		let tableScrollView = NSScrollView(frame: NSZeroRect)
		tableScrollView.drawsBackground = false
		tableScrollView.documentView = tableView
		tableScrollView.hasVerticalScroller = true

		let contentView = NSView(frame: NSZeroRect)
		contentView.addSubview(tableScrollView)

		let contentViewController = NSViewController()
		contentViewController.view = contentView

		// Autocomplete popover
		self.autocompletePopover = NSPopover()
		self.autocompletePopover.appearance = NSAppearance(named: POPOVER_APPEARANCE)

		self.autocompletePopover.animates = false
		self.autocompletePopover.contentViewController = contentViewController
	}
	
	@objc func clickPopupItem(_ sender:Any?) {
		if popupMode == .Autocomplete {
			self.insertAutocompletion()
		} else if popupMode == .Tagging {
			//
		} else {
			closePopovers()
		}
//		if (_popupMode == Autocomplete)	[self insert:sender];
//		if (_popupMode == Tagging) [self setTag:sender];
//		else [self closePopovers];
		
	}
	
	@objc func insertAutocompletion() {
		let selectedRow = self.autocompleteTableView.selectedRow
		guard let currentLine = self.editorDelegate.currentLine, self.popupMode == .Autocomplete, selectedRow >= 0, selectedRow < self.matches.count else {
			// Not an applicable index
			self.autocompletePopover.close()
			return
		}
				
		let string = self.matches[selectedRow] as? String ?? ""
		var beginningOfWord = NSNotFound
		
		let locationInString = self.selectedRange.location - currentLine.position;
		beginningOfWord = self.selectedRange.location - locationInString;
			
		let range = NSMakeRange(beginningOfWord, self.substring.length);
		
		if (self.shouldChangeText(in: range, replacementString: string)) {
			self.replaceCharacters(in: range, with: string)
			self.didChangeText()
			self.isAutomaticTextCompletionEnabled = false
		}

		self.autocompletePopover.close()
	}
}

