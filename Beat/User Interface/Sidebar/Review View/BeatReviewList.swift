//
//  BeatReviewList.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Lists review items in the sidebar. Acts as view, delegate and data source.
 The view conforms to BeatEditorView protocol, so it reloads itself in background
 whenever the text has been changed OR when the tab is selected.
 
 */

import Cocoa
import BeatCore

struct ReviewListItem {
	var content = ""
	var snippet = ""
	var range:NSRange = NSMakeRange(0, 0)
}

class BeatReviewCellView:NSTableCellView {
	@IBOutlet var snippet:NSTextField?
}

class BeatReviewList:NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate, BeatEditorView {
	// @property (nonatomic, weak) IBOutlet NSTabView *masterTabView;
	@IBOutlet var enclosingTabView:NSTabViewItem?
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	var string:NSAttributedString?
	var reviewList:NSMutableArray = NSMutableArray()
	var timer:Timer = Timer()
	
	@IBOutlet var placeholderView:NSView?
	
	override func awakeFromNib() {
		self.delegate = self
		self.dataSource = self
		
		self.editorDelegate?.register(self)
		
		reload()
	}
	
	func reloadInBackground() {
		timer.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
			self.reload()
		})
	}
	
	override func drawGrid(inClipRect clipRect: NSRect) {
		if reviewList.count > 0 {
			super.drawGrid(inClipRect: clipRect)
		}
	}
	
	func fetchReviews() {
		reviewList.removeAllObjects()
		
		string?.enumerateAttribute(NSAttributedString.Key(rawValue: "BeatReview"), in: NSMakeRange(0, string?.length ?? 0), using: { value, range, stop in
			let review:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
			
			if (!review.emptyReview) {
				let str = string?.attributedSubstring(from: range)
				let content = review.string
				
				let listItem:ReviewListItem = ReviewListItem(content: content! as String, snippet: str?.string ?? "", range: range)
				reviewList.add(listItem)
			}
		})
	}
	
	func reload() {
		string = (self.editorDelegate?.attributedString().copy() as! NSAttributedString)
		let bounds = self.enclosingScrollView?.contentView.bounds
		
		DispatchQueue.global().async { [weak self] in
			self?.fetchReviews()
			DispatchQueue.main.sync { [weak self] in
				self?.reloadData()
				
				if (self?.reviewList.count ?? 0 > 0) {
					self?.placeholderView?.isHidden = true
				} else {
					self?.placeholderView?.isHidden = false
				}
				
				self?.enclosingScrollView?.contentView.bounds = bounds!
			}
		}
	}
	
	func visible() -> Bool {
		if enclosingTabView?.tabView?.selectedTabViewItem == enclosingTabView {
			return true
		} else {
			return false
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return false
	}
		
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return reviewList.count
		}
		else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return reviewList[index]
	}
	override func item(atRow row: Int) -> Any? {
		return reviewList[row]
	}
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		return nil
	}
	/*
	override func view(atColumn column: Int, row: Int, makeIfNecessary: Bool) -> NSView? {
		let item:ReviewListItem = outlineView(self, objectValueFor: <#T##NSTableColumn?#>, byItem: <#T##Any?#>)
		
		let view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ReviewCell"), owner: nil) as! NSTableCellView
		view.textField?.stringValue =
		
		return view
	}
	 */
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ReviewCell"), owner: nil) as! BeatReviewCellView
		
		let review = item as! ReviewListItem
		view.textField?.stringValue = review.content
		
		return view
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		let review = item as! ReviewListItem
		
		editorDelegate?.scroll(to: review.range, callback: {
			self.editorDelegate?.selectedRange = NSMakeRange(review.range.location, 0)
			self.editorDelegate?.focusEditor?()
		});
		
		return true
	}
	
	override func becomeFirstResponder() -> Bool {
		editorDelegate?.focusEditor?()
		return false
	}
}
