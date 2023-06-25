//
//  BeatReview.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 Review system + items + editor/display window classes.
 
 This is also me learning some Swift, which is not going too well.
 Dread lightly.
 
 Edit 01/2023:
 Yeah, thanks past me. This class is an abomination, but appears to do what it says.
 I've never had to touch this until I went and changed how text backgrounds are displayed.
 
 From what I've gathered, it's split into three parts:
 - Review manager (`BeatReview`)
 - Review items (`BeatReviewItem`, added as attributes to the document)
 - Review editor (`BeatReviewEditor`, displayed when either showing or editing review items)
 
 When porting to iOS, this should be split into even more abstract classes. Review items and the manager
 should almost be OK as they are, but we need to change `NSColor` and `NSPopover`to some cross-platform aliases.
 
 Like the revision module, review class also provides ranges and text content for the reviews for
 saving into the document as JSON.
 
 */

#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import UXKit

public protocol BeatReviewDelegate: AnyObject {
	func confirm(sender:Any?)
	//func forwardKeypress(event:NSEvent)
}

public protocol BeatReviewInterface {
    func showReviewItem(range:NSRange, forEditing:Bool)
    func applyReview()
    func deleteReview(item:BeatReviewItem)
}

// MARK: Review item

@objc public class BeatReviewItem:NSObject, NSCopying, NSCoding {
	@objc public var string:NSString! = ""
	
	@objc public var emptyReview:Bool {
		get {
			if (string.length == 0) {
				return true
			} else {
				return false
			}
		}
	}
	
	@objc public init(reviewString:NSString?) {
		string = reviewString ?? ""
		super.init()
	}
	
	public required init?(coder: NSCoder) {
		super.init()
		string = coder.decodeObject(forKey: "string") as? NSString ?? ""
	}
	
	public func encode(with coder: NSCoder) {
		coder.encode(string, forKey: "string")
	}
	
	public func copy(with zone: NSZone? = nil) -> Any {
		let item = BeatReviewItem(reviewString: self.string)
		return item
	}
}


// MARK: Review manager class

@objc public class BeatReview: NSObject {
    #if os(macOS)
        @objc public var popover:NSPopover
        @objc public var editorView:BeatReviewEditor
    #else
        @objc public var popover:UIPopoverPresentationController
    #endif
	
	@IBOutlet var delegate:BeatEditorDelegate?
    
	var currentRange:NSRange = NSMakeRange(0, 0)
	var item:BeatReviewItem?
	
    let editorContentSize = CGSizeMake(200, 160)
	
	@objc public class func reviewColor() -> UXColor {
		return UXColor.init(red: 255.0 / 255.0, green: 229.0 / 255.0, blue: 117.0 / 255, alpha: 1.0)
	}
	@objc public class func attributeKey () -> NSAttributedString.Key {
		return NSAttributedString.Key(rawValue: "BeatReview")
	}
		
	override public init() {
		// Register custom attribute 
		BeatAttributes.registerAttribute(BeatReview.attributeKey().rawValue)
		
        #if os(macOS)
		popover = NSPopover()
		editorView = BeatReviewEditor()
		popover.contentViewController = editorView
        
        if #available(macOS 10.14, *) {
            popover.appearance = NSAppearance(named: .aqua)
        }
        #else
        
        print("Implement review manager")
        self.popover = UIPopoverPresentationController(presentedViewController: PopoverViewController(), presenting: nil)
        
        #endif
	
		
		super.init()
	}
	
	@objc public func setup() {
		if (delegate == nil) { return }		
		setupReviews(ranges: delegate!.documentSettings.get(DocSettingReviews) as? NSArray ?? [])
	}
	
	@objc public func rangesForSaving(string:NSAttributedString) -> NSArray {
		let ranges:NSMutableArray = NSMutableArray()
		var prevRange:NSRange = NSMakeRange(0, 0)
		var prevString:NSString = ""
		
		string.enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, string.length)) { value, range, stop in
			let item:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")

			if (item.emptyReview) {
				return
			}
			
			if (NSMaxRange(prevRange) + 1 == range.location && item.string.isEqual(to: prevString as String)) {
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
	
	@objc public func setupReviews(ranges:NSArray) {
		guard let delegate = self.delegate else { return }
		
		for item in ranges {
			let review = item as? Dictionary ?? [:]
			
			// Guard for nil values, we don't need empty review items
			if (review["range"] == nil || review["string"] == nil) {
				continue
			}
			
			let reviewItem = BeatReviewItem(reviewString: review["string"] as? NSString ?? "")
			let rangeArray:Array<Int> = review["range"] as! Array
			let range = NSMakeRange(rangeArray[0], rangeArray[1])
			
			if (NSMaxRange(range) <= delegate.text().count) {
				delegate.textStorage().addAttribute(BeatReview.attributeKey(), value: reviewItem, range: range)
			}
		}
	}
    
    @objc public func saveReview(item: BeatReviewItem) {
        let trimmedString = item.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if (trimmedString.count > 0 && trimmedString != "") {
            // Save review if it's not empty
            delegate?.addAttribute(BeatReview.attributeKey().rawValue, value: item, range: currentRange)
        }
        
        self.delegate?.renderBackground(for: currentRange)
        delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review edit")))
        #if os(macOS)
        delegate?.updateChangeCount(.changeDone)
        #else
        delegate?.updateChangeCount(.done)
        #endif
    }
	
    public func deleteReview(item:BeatReviewItem) {
        var deleteRange = NSMakeRange(NSNotFound, 0)
        delegate?.textStorage().enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, delegate?.text().count ?? 0), using: { value, range, stop in
            let review = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
            
            if (review == item) {
                deleteRange = range
                stop.pointee = true
            }
        })
        
        if (deleteRange.location != NSNotFound) {
            delegate?.textStorage().removeAttribute(BeatReview.attributeKey(), range: deleteRange)
            delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review deletion")))
            
#if os(macOS)
            editorView.item = nil
            popover.close()
            
            delegate?.renderBackground(for: deleteRange)
            delegate?.updateChangeCount(.changeDone)
#endif
        }

        
        // Commit to attributed text cache
        _ = delegate?.attributedString()
    }
    
    @objc public func applyReview() {
        #if os(macOS)
            self.closePopover()
        #endif
            
        let textView = delegate?.getTextView()
        
        // Move the cursor at the end of review
        var effectiveRange: NSRange = NSMakeRange(0, 0)
        guard let textStorage = textView?.textStorage else { return }
        
        let attr:BeatReviewItem = textStorage.attribute(BeatReview.attributeKey(), at:textView?.selectedRange().location ?? 0,
                                                        longestEffectiveRange: &effectiveRange,
                                                        in: NSMakeRange(0, delegate?.text().count ?? 0)) as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
        
        if (effectiveRange.location != NSNotFound && currentRange.length > 0 && !attr.emptyReview) {
			textView?.selectedRange = NSMakeRange(effectiveRange.location + effectiveRange.length, 0)
        }
        
        // Commit to attributed text cache
        _ = delegate?.attributedString()
    }
    
#if os(macOS)
    
	@objc public func showReviewItem(range:NSRange, forEditing:Bool) {
		// Initialize empty review item
		var reviewItem = BeatReviewItem(reviewString: "")
		let textView = delegate?.getTextView()
		let effectiveRange:NSRangePointer? = nil
		
		// If the cursor landed on a review, display the review at that location
		if (range.length == 0) {
			let attrs = delegate?.textStorage().attributes(at: range.location, effectiveRange: effectiveRange)
			
			guard let item = attrs?[BeatReview.attributeKey()] as? BeatReviewItem
			else {
				// Close any popovers and return if there is no review item here
				closePopover()
				return
			}
			
			reviewItem = item
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
		
		// This is a NEW, empty review. We'll check if there's another item right next to it.
		if (reviewItem.emptyReview) {
			delegate?.textStorage().enumerateAttribute(BeatReview.attributeKey(), in: range, using: { value, rng, stop in
				let item:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem.init(reviewString: "")
				
				if (!item.emptyReview) {
					reviewItem = item
					reviewRange.length += rng.location - reviewRange.location + rng.length
					stop.pointee = true
				}
			})
		}
		
		// The range has to be at least 1 in length for the popover to display correctly.
		if (reviewRange.length == 0) {
			
			var displayRange = NSMakeRange(reviewRange.location, 1)
			if (NSMaxRange(displayRange) > delegate?.text().count ?? 0) {
				displayRange.location -= 1
			}
			reviewRange = displayRange
		}
		
		var rect = textView?.firstRect(forCharacterRange: reviewRange, actualRange: nil)
		rect = (self.delegate?.documentWindow?.convertFromScreen(rect ?? NSZeroRect))!
		rect = textView?.convert(rect ?? NSZeroRect, from: nil)
		
		// Rect has to be at least 1px wide the popover to display correctly
		if rect?.width ?? 0.0 < 1.0 { rect?.size.width = 1.0 }
		
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
			popover.show(relativeTo: rect!, of:textView!, preferredEdge: NSRectEdge.maxY)
			editorView.editor?.window?.makeFirstResponder(editorView.editor)
		}
	}

	
	@objc public func closePopover() {
		// When closing, let's see if the text view is empty.
		// If so, remove the review altogether.
		let string = editorView.editor?.string.trimmingCharacters(in: .whitespacesAndNewlines)
		if (string?.count == 0 && editorView.item != nil) {
			deleteReview(item: editorView.item!)
		}
		
		editorView.shown = false
		popover.close()
	}
#endif
    
}

#if os(macOS)

@objc public class BeatReviewEditor: UXViewController, BeatReviewDelegate, UXTextViewDelegate {
	@IBOutlet weak var editor:BeatReviewTextView?
	@IBOutlet weak var editButton:NSButton?
	
	var item:BeatReviewItem?
	var shown:Bool = false
	weak var controller:BeatReview?
	
	init() {
        let bundle = Bundle(for: type(of: self))
		super.init(nibName: "ReviewView", bundle: bundle)
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override public func dismiss(_ viewController: UXViewController) {
		editor = nil
		editButton = nil
		super.dismiss(viewController)
	}
	
	override public func viewDidLoad() {
		editor?.delegate = self
		editor?.reviewDelegate = self
		editor?.textContainerInset = NSMakeSize(5.0, 8.0)
	}
	
	@IBAction public func confirm(sender:Any?) {
		item?.string = editor?.string as? NSString
		controller?.applyReview()
	}
	
	@IBAction public func edit(sender:Any?) {
		editor?.isEditable = true
		editor?.window?.makeFirstResponder(editor)
		controller?.popover.contentSize = controller?.editorContentSize ?? NSMakeSize(200, 160)
		editButton?.isHidden = true
	}
	
	@IBAction public func delete(sender:Any?) {
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
	
    public func textDidChange(_ notification: Notification) {
		if (shown) {
			item?.string = editor?.string as? NSString
			
			guard (item != nil) else { return }
			controller?.saveReview(item: item!)
		}
	}
}

#endif

@objc public class BeatReviewTextView:UXTextView {
	weak var reviewDelegate: BeatReviewDelegate?
	    
    #if os(macOS)

	override public func keyDown(with event: NSEvent) {
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
    
    #endif
}

/*
 
 Popover views
 
 */
#if os(macOS)
class PopoverContentView:UXView {
	var backgroundView:PopoverBackgroundView?
    
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		if let frameView = self.window?.contentView?.superview {
			if backgroundView == nil {
				backgroundView = PopoverBackgroundView(frame: frameView.bounds)
				backgroundView!.autoresizingMask = UXView.AutoresizingMask([.width, .height]);
				frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
			}
		}
	}
}
#endif

class PopoverBackgroundView:UXView {
    #if os(macOS)
	override func draw(_ dirtyRect: NSRect) {
		BeatReview.reviewColor().set()
		self.bounds.fill()
	}
    #else
    override func awakeFromNib() {
        self.layer.backgroundColor = BeatReview.reviewColor().cgColor
    }
    #endif
}

#if os(iOS)
class PopoverContentViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "square.grid.2x2.fill"), for: .normal)
        button.addTarget(self, action: #selector(displayPopover), for: .touchUpInside)
        self.view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 100),
            button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40),
        ])
        
    }
    
    @IBAction func displayPopover(sender: UIButton!) {
        let popoverVC = PopoverViewController()
        popoverVC.modalPresentationStyle = .popover
        popoverVC.popoverPresentationController?.sourceView = sender
        popoverVC.popoverPresentationController?.permittedArrowDirections = .up
        popoverVC.popoverPresentationController?.delegate = self
        self.present(popoverVC, animated: true, completion: nil)
    }
}

extension UIViewController: UIPopoverPresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class PopoverViewController: UIViewController {
    override func viewDidLoad() {
        self.view.backgroundColor = .systemGray
        self.preferredContentSize = CGSize(width: 300, height: 200)
    }
}
#endif
