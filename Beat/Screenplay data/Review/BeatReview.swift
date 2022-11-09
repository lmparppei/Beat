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

protocol BeatReviewDelegate: AnyObject {
	func confirm(sender:Any?)
	//func forwardKeypress(event:NSEvent)
}

// MARK: Review item

class BeatReviewItem:NSObject, NSCopying, NSCoding {
	var string:NSString! = ""
	
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
	
	required init?(coder: NSCoder) {
		super.init()
		string = coder.decodeObject(forKey: "string") as? NSString ?? ""
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(string, forKey: "string")
	}
	
	func copy(with zone: NSZone? = nil) -> Any {
		let item = BeatReviewItem(reviewString: self.string)
		return item
	}
}


// MARK: Review manager class

class BeatReview: NSObject {
	@objc var popover:NSPopover
	@objc var editorView:BeatReviewEditor
	@IBOutlet var delegate:BeatEditorDelegate?
	var currentRange:NSRange = NSMakeRange(0, 0)
	var item:BeatReviewItem?
	
	let editorContentSize = NSMakeSize(200, 160)
	
	@objc class func reviewColor() -> NSColor {
		return NSColor.init(red: 255.0 / 255.0, green: 229.0 / 255.0, blue: 117.0 / 255, alpha: 1.0)
	}
	@objc class func attributeKey () -> NSAttributedString.Key {
		return NSAttributedString.Key(rawValue: "BeatReview")
	}
		
	override init() {
		// Register custom attribute 
		BeatAttributes.registerAttribute(BeatReview.attributeKey().rawValue)
		
		popover = NSPopover()
		editorView = BeatReviewEditor()
		popover.contentViewController = editorView
	
		if #available(macOS 10.14, *) {
			popover.appearance = NSAppearance(named: .aqua)
		}
		
		super.init()
	}
	
	@objc func setup() {
		if (delegate == nil) { return }		
		setupReviews(ranges: delegate!.documentSettings.get(DocSettingReviews) as? NSArray ?? [])
	}
	
	@objc func rangesForSaving(string:NSAttributedString) -> NSArray {
		let ranges:NSMutableArray = NSMutableArray()
		var prevRange:NSRange = NSMakeRange(0, 0)
		var prevString:NSString = ""
		
		string.enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, string.length)) { value, range, stop in
			let item:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")

			if (item.emptyReview) {
				return
			}
			
			if (NSMaxRange(prevRange) + 1 == range.location && item.string.isEqual(to: prevString)) {
				print("We should fix this attribute...")
			}
			
			ranges.add([
				"range": [range.location, range.length],
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
			
			if (NSMaxRange(range) <= delegate!.textView.string.count) {
				delegate?.textView.textStorage?.addAttribute(BeatReview.attributeKey(), value: reviewItem, range: range)
			}
		}
	}
	
	@objc func showReviewItem(range:NSRange, forEditing:Bool) {
		// Initialize empty review item
		var reviewItem = BeatReviewItem(reviewString: "")
		let effectiveRange:NSRangePointer? = nil
		
		// If the cursor landed on a review, display the review at that location
		if (range.length == 0) {
			let attrs = delegate?.textView.textStorage?.attributes(at: range.location, effectiveRange: effectiveRange)
			
			if (attrs?[BeatReview.attributeKey()] == nil) {
				closePopover()
				return
			} else {
				reviewItem = attrs?[BeatReview.attributeKey()] as! BeatReviewItem
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
			delegate?.textView.textStorage?.enumerateAttribute(BeatReview.attributeKey(), in: range, using: { value, rng, stop in
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
			if (NSMaxRange(displayRange) > delegate?.textView.string.count ?? 0) {
				displayRange.location -= 1
			}
			reviewRange = displayRange
		}
		
		var rect = delegate?.textView.firstRect(forCharacterRange: reviewRange, actualRange: nil)
		rect = (self.delegate?.textView.window?.convertFromScreen(rect ?? NSZeroRect))!
		rect = self.delegate?.textView.convert(rect ?? NSZeroRect, from: nil)
		
		editorView.controller = self
		editorView.item = reviewItem
		editorView.editor?.string = reviewItem.string as String
		
		popover.contentSize = NSMakeSize(200, 130);
		
		if (forEditing) {
			editorView.editor?.isEditable = true
			editorView.editButton?.isHidden = true
		} else {
			editorView.editor?.isEditable = false
			editorView.editButton?.isHidden = false
			
			// Calculate appropriate size for the content
			let textSize = editorView.editor?.attributedString().height(containerWidth: editorContentSize.width) ?? 60
			let insetHeight = editorView.editor?.textContainerInset.height ?? 0
			
			popover.contentSize = NSMakeSize(editorContentSize.width, 40 + textSize * 1.1 + insetHeight * 2)
		}
		
		editorView.shown = true
				
		if (delegate != nil) {
			popover.show(relativeTo: rect!, of:delegate!.textView, preferredEdge: NSRectEdge.maxY)
			editorView.editor?.window?.makeFirstResponder(editorView.editor)
		}
	}
	
	@objc func saveReview(item: BeatReviewItem) {
		let trimmedString = item.string.trimmingCharacters(in: .whitespacesAndNewlines)
		if (trimmedString.count > 0 && trimmedString != "") {
			// Save review if it's not empty
			self.delegate?.textView.textStorage?.addAttribute(BeatReview.attributeKey(), value: item, range: currentRange)
		}
		
		self.delegate?.renderBackground(for: currentRange)
		delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review edit")))
		delegate?.updateChangeCount(.changeDone)
	}
	
	@objc func applyReview() {
		self.closePopover()
		
		// Move the cursor at the end of review
		var effectiveRange: NSRange = NSMakeRange(0, 0)
		let attr:BeatReviewItem = delegate?.textView.textStorage?.attribute(BeatReview.attributeKey(),
																			at:delegate?.textView.selectedRange().location ?? 0,
																			longestEffectiveRange: &effectiveRange,
																			in: NSMakeRange(0, delegate?.textView.string.count ?? 0))
								  as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
		
		if (effectiveRange.location != NSNotFound && currentRange.length > 0 && !attr.emptyReview) {
			delegate?.textView.setSelectedRange(NSMakeRange(effectiveRange.location + effectiveRange.length, 0))
		}
		
		// Commit to attributed text cache
		delegate?.getAttributedText()
	}
	
	func deleteReview(item:BeatReviewItem) {
		var deleteRange = NSMakeRange(NSNotFound, 0)
		delegate?.textView.textStorage?.enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, delegate?.text().count ?? 0), using: { value, range, stop in
			let review = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
			
			if (review == item) {
				deleteRange = range
				stop.pointee = true
			}
		})
		
		if (deleteRange.location != NSNotFound) {
			editorView.item = nil
			delegate?.textView.textStorage?.removeAttribute(BeatReview.attributeKey(), range: deleteRange)
			delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review deletion")))
			popover.close()
			
			self.delegate?.renderBackground(for: deleteRange)
			delegate?.updateChangeCount(.changeDone)
		}
		
		// Commit to attributed text cache
		delegate?.getAttributedText()
	}
	
	@objc func closePopover() {
		// When closing, let's see if the text view is empty.
		// If so, remove the review altogether.
		let string = editorView.editor?.string.trimmingCharacters(in: .whitespacesAndNewlines)
		if (string?.count == 0 && editorView.item != nil) {
			deleteReview(item: editorView.item!)
		}
		
		editorView.shown = false
		popover.close()
	}
}

class BeatReviewEditor: NSViewController, NSTextViewDelegate, BeatReviewDelegate {
	@IBOutlet weak var editor:BeatReviewTextView?
	@IBOutlet weak var editButton:NSButton?
	
	var item:BeatReviewItem?
	var shown:Bool = false
	weak var controller:BeatReview?
	
	init() {
		super.init(nibName: "ReviewView", bundle: Bundle.main)
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func dismiss(_ viewController: NSViewController) {
		editor = nil
		editButton = nil
		super.dismiss(viewController)
	}
	
	override func viewDidLoad() {
		editor?.delegate = self
		editor?.reviewDelegate = self
		editor?.textContainerInset = NSMakeSize(5.0, 8.0)
	}
	
	@IBAction func confirm(sender:Any?) {
		item?.string = editor?.string as? NSString
		controller?.applyReview()
	}
	
	@IBAction func edit(sender:Any?) {
		editor?.isEditable = true
		editor?.window?.makeFirstResponder(editor)
		controller?.popover.contentSize = controller?.editorContentSize ?? NSMakeSize(200, 160)
		editButton?.isHidden = true
	}
	
	@IBAction func delete(sender:Any?) {
		if (item != nil) {
			controller?.deleteReview(item: item!)
		}
	}
/*
	func forwardKeypress(event:NSEvent) {
		// This is a VERY WEIRD HACK and I apologize
		editor?.window?.makeFirstResponder(controller?.delegate?.textView)
		editor?.window?.makeFirstResponder(controller?.delegate?.textView)
		editor?.window?.sendEvent(event)
		editor?.window?.sendEvent(event)
	}
 */
	
	/* Text view delegation */
	
	func textDidChange(_ notification: Notification) {
		if (shown) {
			item?.string = editor?.string as? NSString
			
			guard (item != nil) else { return }
			controller?.saveReview(item: item!)
		}
	}
}

class BeatReviewTextView:NSTextView {
	weak var reviewDelegate: BeatReviewDelegate?
	
	override func keyDown(with event: NSEvent) {
		/*
		 
		 The following doesn't work:
		 
		// 123 124 125 126 are the arrow keys.
		// If the review is empty and the user has shift key pressed, the user probably
		// wanted to expand the selection, so pass the event through.
		if (NSLocationInRange(Int(event.keyCode), NSMakeRange(123, 4)) && self.string.count == 0 && event.modifierFlags.contains(.shift)) {
			reviewDelegate?.forwardKeypress(event: event)
			return
		}
		*/
		
		// Close on esc or shift-enter
		if (event.keyCode == 53 ||
			event.keyCode == 36 && event.modifierFlags.contains(.shift)) {
			reviewDelegate?.confirm(sender: self)
			return
		}
		
		super.keyDown(with: event)
	}
	
}

/*
 
 Popover views
 
 */

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

