//
//  BeatEditorPopoverController.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 10.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc public enum BeatEditorPopoverMode:Int {
	case none = 0
	case autocompletion = 1
	case forceElement = 2
	case addNewTag = 3
	case selectTagDefinition = 4
	case other = 5
}

fileprivate let popoverWidth = 300.0
fileprivate let maxResults = 12

@objc public protocol BeatEditorPopoverDelegate {
	var partialText:String? { get }
}

@objcMembers
class BeatEditorPopoverController:NSObject, NSTableViewDataSource, NSTableViewDelegate {
	/// Delegate will determine what to do when picking the items
	weak var delegate:BeatEditorPopoverDelegate?
	/// The owner text view
	weak var textView:NSTextView?
		
	/// The mode will reset every time the popover closes
	//var mode:BeatEditorPopoverMode = .none
	/// Items currently displayed.`Any` is misleading here, it should be either `NSString` or `NSAttributedString`.
	public var items:[Any] = []
	
	var popover:NSPopover = NSPopover()
	var tableView:NSTableView = NSTableView()
	
	var callback:((_ string:String, _ row:Int) -> Bool)?
	var doNotClose = false
	
	init(delegate:BeatEditorPopoverDelegate) {
		super.init()
		
		self.delegate = delegate
		setupPopovers()
	}
	
	var isShown:Bool {
		return self.popover.isShown
	}
	
	func setupPopovers() {
		self.textView = self.delegate as? NSTextView
		
		// Make a table view with 1 column and enclosing scroll view. It doesn't
		// matter what the frames are here because they are set when the popover
		// is displayed
		
		tableView = NSTableView(frame: .zero)
		
		tableView.selectionHighlightStyle = .regular
		tableView.backgroundColor = .clear
		tableView.rowSizeStyle = .small
		tableView.intercellSpacing = CGSizeMake(20.0, 3.0)
		tableView.headerView = nil
		tableView.refusesFirstResponder = true
		tableView.target = self
		tableView.doubleAction = #selector(pickPopoverItem)
		
		tableView.dataSource = self
		tableView.delegate = self
		
		if #available(macOS 11.0, *) {
			tableView.style = .fullWidth
		}
		
		// Create column
		let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("popoverTextColumn"))
		column.isEditable = false
		column.width = popoverWidth
		
		tableView.addTableColumn(column)
		
		// Enclosing scroll view
		let scrollView = NSScrollView(frame: .zero)
		scrollView.drawsBackground = false
		scrollView.documentView = tableView
		scrollView.hasVerticalScroller = false
		
		// Content view
		let view = NSView(frame: .zero)
		view.addSubview(scrollView)
		
		// View controller
		let viewController = NSViewController()
		viewController.view = view
		
		// Setup popover
		self.popover.appearance = NSAppearance(named: .vibrantDark)
		self.popover.animates = false
		self.popover.contentViewController = viewController
	}
	
	/// Displays the popover menu in given range. If the callback returns `true` the default behavior of enter key will be prevented.
	func display(range:NSRange, items:[Any], callback:@escaping (_ string:String, _ row:Int) -> Bool) {
		self.close() // First always close the possible existing view
				
		guard let textView = self.textView,
			  let window = textView.window,
			  items.count > 0
		else { return }
		
		self.callback = callback
		//self.mode = mode
		self.items = items
		
		// Reload data and select first item by default
		self.reloadData()
		selectRow(index: 0)
		
		// Adjust range when needed
		var safeRange = range
		if NSMaxRange(range) > textView.string.count {
			safeRange.length = 0
		}
		
		var rect = textView.firstRect(forCharacterRange: NSMakeRange(safeRange.location, 1), actualRange: nil)
		rect = window.convertFromScreen(rect)
		rect = textView.convert(rect, from: nil)
		rect.size.width = rect.size.width / 2;
		
		// We'll force a width of 5 for empty ranges
		if range.length == 0 { rect.size.width = 5.0 }
		
		self.popover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
		
		// Keep the text view focused
		window.makeFirstResponder(textView)
	}
	
	func close() {
		self.popover.close()
	}

	
	// MARK: - Table view delegate
	
	func reloadData() {
		self.tableView.reloadData()
		
		// Make the frame for the popover. We want it to shrink with a small number
		// of items to autocomplete but never grow above a certain limit when there
		// are a lot of items.
		let numberOfRows = min(self.tableView.numberOfRows, maxResults)
		let height = (tableView.rowHeight + tableView.intercellSpacing.height) * CGFloat(numberOfRows)
		
		let frame = CGRectMake(0.0, 0.0, popoverWidth, height)
		tableView.enclosingScrollView?.frame = frame
		popover.contentSize = NSMakeSize(frame.width, frame.height)
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return items.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("MyView"), owner: self.textView) as? NSTableCellView ?? NSTableCellView()
		
		let partialText = self.delegate?.partialText ?? ""
		
		if cellView.textField == nil {
			let textField = NSTextField(frame: NSZeroRect)
			textField.isBezeled = false
			textField.drawsBackground = false
			textField.isEditable = false
			textField.isSelectable = false
			
			cellView.addSubview(textField)
			cellView.textField = textField
			
			cellView.identifier = NSUserInterfaceItemIdentifier("BeatPopoverItemView")
		}
		
		var result: NSMutableAttributedString
				
		// The popover items can be either plain text or attributed text
		if let label = self.items[row] as? NSAttributedString {
			result = NSMutableAttributedString(attributedString: label)
			result.addAttribute(NSAttributedString.Key.font, value: BeatFontManager.shared.defaultFonts.regular, range: NSRange(location: 0, length: result.length))
		} else if let label = self.items[row] as? String {
			result = NSMutableAttributedString(string: label, attributes: [NSAttributedString.Key.font: BeatFontManager.shared.defaultFonts.regular, NSAttributedString.Key.foregroundColor: NSColor.white])
		} else {
			return cellView
		}
		
		// Highlight the already typed part
		if let range = result.string.range(of: partialText, options: [.anchored, .caseInsensitive]) {
			result.addAttribute(NSAttributedString.Key.font, value: BeatFontManager.shared.defaultFonts.bold, range: NSRange(range, in: result.string))
		}
		
		cellView.textField?.attributedStringValue = result
		
		return cellView
	}
	
	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		return BeatEditorPopoverTableRowView()
	}
	
	func pickPopoverItem() -> Bool {
		let string:String
		let item = self.items[self.tableView.selectedRow]

		if let text = item as? String {
			string = text
		} else if let text = item as? NSAttributedString {
			string = text.string
		} else {
			string = ""
		}
		
		// Close popover and reset "do not close" flag
		if (!doNotClose) { self.close() }
		doNotClose = false
		
		// Ask the delegate whether we should prevent default or not.
		let preventDefault = self.callback?(string, tableView.selectedRow) ?? true
		return preventDefault
	}
	
	
	// MARK: - Handle editor key presses
	
	@objc func keyPressed(keyCode:UInt16) -> Bool {
		var preventDefault = false
		
		// Specific handlers for popover state
		if (keyCode == 125) {
			// Down key
			moveDown(); preventDefault = true
		} else if (keyCode == 126) {
			// Up key
			moveUp(); preventDefault = true
		} else if (keyCode == 48) {
			// Tab
			preventDefault = pickPopoverItem()
		} else if (keyCode == 36) {
			// Return
			preventDefault = pickPopoverItem()
		}
				
		return preventDefault
	}
	
	
	// MARK: - Navigate the table view
	
	func selectRow(index:Int) {
		self.tableView.selectRowIndexes([index], byExtendingSelection: false)
		self.tableView.scrollRowToVisible(index)
	}
	
	func moveUp() {
		var row = self.tableView.selectedRow
		if row - 1 < 0 { row = 1 }
				
		selectRow(index: row-1)
	}
	
	func moveDown() {
		var row = self.tableView.selectedRow
		if row + 1 > self.tableView.numberOfRows { row = -1 }
		
		selectRow(index: row+1)
	}
	
}

class BeatEditorPopoverTableRowView:NSTableRowView {
	override func drawSelection(in dirtyRect: NSRect) {
		guard self.selectionHighlightStyle != .none else { return }
		
		let selectionRect = NSInsetRect(self.bounds, 0.5, 0.5)
		
		NSColor.selectedMenuItemColor.setStroke()
		NSColor.selectedMenuItemColor.setFill()
		
		let path = NSBezierPath.init(roundedRect: selectionRect, xRadius: 0.0, yRadius: 0.0)
		path.fill()
		path.stroke()
	}
	
	override var interiorBackgroundStyle: NSView.BackgroundStyle {
		if self.isSelected { return .dark }
		else { return .light }
	}
}

class BeatEditorPopoverCellView:NSTableCellView {
	
}
