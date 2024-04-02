//
//  BeatFindPanel.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 4.2.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

@objcMembers
class BeatFindPanel:NSWindowController, NSTextFinderBarContainer {
	var findBarView: NSView?
	
	var isFindBarVisible: Bool = true
	
	func findBarViewDidChangeHeight() {
		//
	}
	
	func contentView() -> NSView? {
		return self.textView
	}
	
	weak var textView:BeatTextView?

	@IBOutlet weak var _searchField:NSTextField?
	@IBOutlet weak var findView:NSView?
	
	class func create(textView: BeatTextView) -> BeatFindPanel {
		let findPanel = BeatFindPanel(window: nil)
		
		findPanel.textView = textView
		textView.textFinder.findBarContainer = findPanel
		
		return findPanel
	}
	
	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var windowNibName: String! {
		return "BeatFindPanel"
	}
	
	@IBAction func search(_ sender:Any?) {
		let pBoard = NSPasteboard(name: .find)
		pBoard.declareTypes([.string, .textFinderOptions], owner: nil)
		pBoard.setString(_searchField?.stringValue ?? "", forType: .string)
		//[NSNumber numberWithBool:YES], NSTextFinderCaseInsensitiveKey, [NSNumber numberWithInteger:NSTextFinderMatchingTypeContains], NSTextFinderMatchingTypeKey, nil
		let options:[AnyHashable:Any] = [
			NSPasteboard.PasteboardType.TextFinderOptionKey.textFinderCaseInsensitiveKey: true,
			NSPasteboard.PasteboardType.TextFinderOptionKey.textFinderMatchingTypeKey: NSTextFinder.MatchingType.contains.rawValue
		]
		pBoard.setPropertyList(options, forType: .textFinderOptions)
		
		self.textView?.textFinder.cancelFindIndicator()
		self.textView?.textFinder.performAction(.setSearchString)
		self.textView?.textFinder.performAction(.showFindInterface)
		self.textView?.textFinder.performAction(.nextMatch)
	}
}
