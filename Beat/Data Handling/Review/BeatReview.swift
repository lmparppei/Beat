//
//  BeatReview.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Review system + items + editor/display window classes.
 
 This is also me learning some Swift, which is not going too well.
 Dread lightly.
 
 */

import Cocoa

class BeatReview: NSObject {
	let popover:NSPopover
	let editorView:BeatReviewEditor
	let delegate:BeatEditorDelegate
	var currentRange:NSRange = NSMakeRange(0, 0)
	var item:BeatReviewItem?
	
	@objc class func reviewColor() -> NSColor {
		return NSColor.init(red: 255.0 / 255.0, green: 229.0 / 255.0, blue: 117.0 / 255, alpha: 1.0)
	}
	
	@objc init(editorDelegate:BeatEditorDelegate) {
		popover = NSPopover()
		editorView = BeatReviewEditor()
		popover.contentViewController = editorView
		delegate = editorDelegate

		if #available(macOS 10.14, *) {
			popover.appearance = NSAppearance(named: .aqua)
		}
		
		super.init()
	}
	
	@objc func rangesForSaving(string:NSAttributedString) -> NSArray {
		let ranges:NSMutableArray = NSMutableArray()
		var prevRange:NSRange = NSMakeRange(NSNotFound, 0)
		var prevString:NSString = ""
		
		string.enumerateAttribute(NSAttributedString.Key(rawValue: "BeatReview"), in: NSMakeRange(0, string.length)) { value, range, stop in
			let item:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")

			if (NSMaxRange(prevRange) + 1 == range.location && item.string.isEqual(to: prevString)) {
				print("We should fix this attribute...")
			}
						
			ranges.add([
				"range": range,
				"string": item.string ?? ""
			])
			
			if (!item.emptyReview) {
				prevRange = range
				prevString = item.string
			}
		}
		
		return ranges
	}
	
	@objc func setupReviews(ranges:NSArray) {
		for item in ranges {
			let review = item as? Dictionary ?? [:]
			
			// Guard for nil values, we don't need empty review items
			if (review["range"] == nil || review["string"] == nil) {
				continue
			}
			
			let reviewItem = BeatReviewItem(reviewString: review["string"] as? NSString ?? "")
			let rangeArray:Array<Int> = review["range"] as! Array
			let range = NSMakeRange(rangeArray[0], rangeArray[1])
			
			delegate.textView.textStorage?.addAttribute(NSAttributedString.Key(rawValue: "BeatReview"), value: reviewItem, range: range)
		}
	}
	
	@objc func showReviewItem(range:NSRange, forEditing:Bool) {
		var reviewItem = BeatReviewItem(reviewString: "")
		let effectiveRange:NSRangePointer? = nil
		
		if (range.length == 0) {
			let attrs = delegate.textView.textStorage?.attributes(at: range.location, effectiveRange: effectiveRange)
			
			if (attrs?[NSAttributedString.Key(rawValue: "BeatReview")] == nil) {
				closePopover()
				return
			} else {
				reviewItem = attrs?[NSAttributedString.Key(rawValue: "BeatReview")] as! BeatReviewItem
			}
		}
		
		if ((currentRange == range || reviewItem == item) && self.popover.isShown) {
			return
		} else {
			if (reviewItem != item) {
				closePopover()
			}
		}
		
		currentRange = range
		item = reviewItem
		var reviewRange = range
		
		if (reviewItem.emptyReview) {
			delegate.textView.textStorage?.enumerateAttribute(NSAttributedString.Key(rawValue: "BeatReview"), in: range, using: { value, rng, stop in
				let item:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem.init(reviewString: "")
				
				if (!item.emptyReview) {
					reviewItem = item
					reviewRange.length += rng.location - reviewRange.location + rng.length
					stop.pointee = true
				}
			})
		}
		
		// The range has to be at least 1 in length for the popover to display correctly.
		// Ensure we're not going out of range.
		if (reviewRange.length == 0) {
			var displayRange = NSMakeRange(reviewRange.location, 1)
			if (NSMaxRange(displayRange) > delegate.textView.string.count) {
				displayRange.location -= 1
			}
			reviewRange = displayRange
		}
		
		var rect = delegate.textView.firstRect(forCharacterRange: reviewRange, actualRange: nil)
		rect = (self.delegate.textView.window?.convertFromScreen(rect))!
		rect = self.delegate.textView.convert(rect, from: nil)
		
		editorView.controller = self
		editorView.item = reviewItem
		editorView.editor?.string = reviewItem.string as String
		
		if (forEditing) {
			editorView.editor?.isEditable = true
		} else {
			editorView.editor?.isEditable = false
		}
		
		editorView.shown = true
		popover.contentSize = NSMakeSize(200, 130);
				
		popover.show(relativeTo: rect, of:delegate.textView, preferredEdge: NSRectEdge.maxY)
		editorView.editor?.window?.makeFirstResponder(editorView.editor)
	}
	
	@objc func saveReview(item: BeatReviewItem) {
		if (item.string.length > 0) {
			// Save
			self.delegate.textView.textStorage?.addAttribute(NSAttributedString.Key(rawValue: "BeatReview"), value: item, range: currentRange)
		} else {
			// Remove
			self.delegate.textView.textStorage?.removeAttribute(NSAttributedString.Key(rawValue: "BeatReview"), range: currentRange)
			print("empty!")
		}
		
		self.delegate.renderBackground(for: currentRange)
	}
	
	@objc func applyReview() {
		self.closePopover()
	}
	
	@objc func closePopover() {
		editorView.shown = false
		popover.close()
	}
}

class BeatReviewEditor: NSViewController, NSTextViewDelegate {
	@IBOutlet var editor:NSTextView?
	@IBOutlet var editButton:NSButton?
	
	var item:BeatReviewItem?
	var shown:Bool = false
	var controller:BeatReview?
	
	init() {
		super.init(nibName: "ReviewView", bundle: Bundle.main)
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		editor?.delegate = self
		editor?.textContainerInset = NSMakeSize(5.0, 8.0)
	}
	
	func textDidChange(_ notification: Notification) {
		if (shown) {
			item?.string = editor?.string as? NSString
			
			guard (item != nil) else { return }
			controller?.saveReview(item: item!)
		}
	}
		
	@IBAction func confirm(sender:Any?) {
		item?.string = editor?.string as? NSString
		controller?.applyReview()
	}
}

class PopoverContentView:NSView {
	var backgroundView:PopoverBackgroundView?
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		if let frameView = self.window?.contentView?.superview {
			if backgroundView == nil {
				backgroundView = PopoverBackgroundView(frame: frameView.bounds)
				backgroundView!.autoresizingMask = NSView.AutoresizingMask([.width, .height]);
				frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
			}
		}
	}
}

class PopoverBackgroundView:NSView {
	override func draw(_ dirtyRect: NSRect) {
		BeatReview.reviewColor().set()
		self.bounds.fill()
	}
}

class BeatReviewItem:NSObject {
	var string:NSString!
	@objc var emptyReview:Bool {
		get {
			if (string.length == 0) {
				return true
			} else {
				return false
			}
		}
	}
	
	@objc init(reviewString:NSString?) {
		string = reviewString ?? ""
		super.init()
	}
}
protocol BeatReviewDelegate {
	func confirm(sender:Any?)
}
class BeatReviewTextView:NSTextView {
	var reviewDelegate: BeatReviewDelegate?
	
	override func keyDown(with event: NSEvent) {
		if(event.keyCode == 53) {
			reviewDelegate?.confirm(sender: self)
			return
		}
		
		super.keyDown(with: event)
	}
}
