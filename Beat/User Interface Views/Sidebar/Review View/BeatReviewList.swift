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
	var keywords:[String] = []
}

class BeatReviewCellView:NSTableCellView {
	@IBOutlet var snippet:NSTextField?
}

enum BeatReviewListMode {
	case list
	case keywords
}

class BeatReviewList:NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate, BeatEditorView {
	// @property (nonatomic, weak) IBOutlet NSTabView *masterTabView;
	@IBOutlet var enclosingTabView:NSTabViewItem?
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	var string:NSAttributedString?
	var reviewList:NSMutableArray = NSMutableArray()
	var reviewTree:[String:[ReviewListItem]] = [:]
	var timer:Timer = Timer()
	
	var loaded = false
	
	var viewMode:BeatReviewListMode = .list
	
	@IBOutlet var placeholderView:NSView?
	
	var awoken = false
	
	override func awakeFromNib() {
		super.awakeFromNib()
		guard !awoken else { return }
		
		self.delegate = self
		self.dataSource = self
		
		self.editorDelegate?.register(self)
		awoken = true
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
	
	@IBAction func toggleViewMode(_ sender: Any) {
		if let sender = sender as? NSSegmentedControl {
			viewMode = (sender.selectedSegment == 0) ? .list : .keywords
			reload()
		}
	}
	
	func fetchReviews() {
		reviewList.removeAllObjects()
		reviewTree = [:]
		
		guard let string = self.editorDelegate?.attributedString() else { print("Warning: No string for fetching reviews"); return }
		self.string = string
		
		string.enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, string.length), using: { value, range, stop in
			let review:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
			let clampedRange = range.clamped(to: string.length)
			
			if (!review.emptyReview && clampedRange.length > 0) {
				let str = string.attributedSubstring(from: clampedRange)
				let content = review.string
				
				let listItem:ReviewListItem = ReviewListItem(content: content, snippet: str.string, range: clampedRange, keywords: review.keywords)
				reviewList.add(listItem)
			}
		})
		
		if self.viewMode == .keywords {
			updateKeywordTree()
		}
	}
	
	func updateKeywordTree() {
		for item in reviewList {
			if let review = item as? ReviewListItem {
				let keywords = review.keywords

				if keywords.count > 0 {
					keywords.forEach { keyword in
						var items:[ReviewListItem] = (reviewTree[keyword] != nil) ? reviewTree[keyword]! : []
						items.append(review)
						reviewTree[keyword] = items
					}
				} else {
					var list = (reviewTree["_"] != nil) ? reviewTree["_"]! : []
					list.append(review)
					reviewTree["_"] = list
				}
			}
		}
	}
	
	func reload() {
		guard let _ = self.editorDelegate?.attributedString().copy() as? NSAttributedString else { return }
		
		let bounds = self.enclosingScrollView?.contentView.bounds
		
		var collapsedSections:IndexSet = []
		if viewMode == .keywords {
			for i in 0..<self.numberOfChildren(ofItem: nil) {
				guard let item = self.item(atRow: i) else { continue }
				if !self.isItemExpanded(item) {
					collapsedSections.insert(i)
				}
			}
		}
		
		DispatchQueue.global().async { [weak self] in
			self?.fetchReviews()
			
			DispatchQueue.main.sync { [weak self] in
				guard let self else { return }
				self.reloadData()
				
				if (self.reviewList.count > 0) {
					self.placeholderView?.isHidden = true
				} else {
					self.placeholderView?.isHidden = false
				}
				
				if let restoredBounds = bounds {
					self.enclosingScrollView?.contentView.bounds = restoredBounds
				}
				
				// Restore collapsed items
				if viewMode == .keywords {
					for i in 0..<self.numberOfChildren(ofItem: nil) {
						if !collapsedSections.contains(i), let child = self.child(i, ofItem: nil) {
							let row = self.row(forItem: child)
							if let item = self.item(atRow: row) {
								self.expandItem(item)
							}
						}
					}
				}
			}
		}
	}
	
	func visible() -> Bool {
		return (enclosingTabView?.tabView?.selectedTabViewItem == enclosingTabView && self.editorDelegate?.sidebarVisible() ?? false)
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if let _ = item as? String {
			return true
		} else {
			return false
		}
	}
		
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if viewMode == .list {
			if item == nil {
				return reviewList.count
			} else {
				return 0
			}
		} else {
			if item == nil {
				return reviewTree.keys.count
			} else {
				if let keyword = item as? String, let items = reviewTree[keyword] {
					return items.count
				}
			}
		}
		
		return 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if viewMode == .list {
			// Just return the index on the review list
			return reviewList[index]
		} else {
			// We need to return either the review OR the main keyword name from the tree
			if item != nil, let keyword = item as? String {
				return reviewTree[keyword]![index]
			} else {
				return reviewTree.keys.sorted()[index]
			}
		}
	}
	
	/*
	override func item(atRow row: Int) -> Any? {
		if viewMode == .list {
			return reviewList[row]
		} else {
			print("   ITEM at ", row)
			let keys = reviewTree.keys.sorted()
			return keys[row]
		}
	}
	 */
		
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		return nil
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		var view:NSTableCellView
		
		if let review = item as? ReviewListItem {
			view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ReviewCell"), owner: nil) as! BeatReviewCellView
			view.textField?.stringValue = review.content
		} else if let keyword = item as? String {
			view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ReviewKeywordCell"), owner: nil) as! BeatReviewCellView
			view.textField?.stringValue = keyword == "_" ? BeatLocalization.localizedString(forKey: "review.keyword.none") : ("#"+keyword)

		} else {
			view = self.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ReviewCell"), owner: nil) as! BeatReviewCellView
		}
		
		return view
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		guard let review = item as? ReviewListItem else {
			return false
		}
		
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
	
	func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
		if let _ = item as? String {
			return 26
		}
		
		return outlineView.rowHeight
	}
}
