//
//  BeatReview.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 Like the revision module, review class also provides ranges and text content for the reviews for
 saving into the document as JSON.
 
 */

#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import UXKit

public protocol BeatReviewInterface {
    func showReviewItem(range:NSRange, forEditing:Bool)
	func applyReview(item:BeatReviewItem)
    func deleteReview(item:BeatReviewItem)
}

// MARK: - Review item

@objc public class BeatReviewItem:NSObject, NSCopying, NSCoding {
	@objc public var string:NSString! = ""
	
    @objc public var keywords:[String] {
        if string.range(of: "#").location == NSNotFound { return [] }
        
        let pattern = "#(\\w+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let results = regex.matches(in: self.string as String, options: [], range: NSRange(location: 0, length: self.string.length))
            return results.map { self.string.substring(with: $0.range(at: 1)) }
        } catch {
            print("Regex error: \(error)")
            return []
        }
    }
    
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


// MARK: - Review manager

@objc public class BeatReview: NSObject {
	@IBOutlet var delegate:BeatEditorDelegate?
    
	var currentRange:NSRange = NSMakeRange(0, 0)
	var currentItem:BeatReviewItem?
	
	var previouslyShownReview:BeatReviewItem?
	
    let editorContentSize = CGSizeMake(200, 160)
    var reviewEditor:BeatReviewEditor?
	
	@objc public class func reviewColor() -> UXColor {
		return UXColor.init(red: 255.0 / 255.0, green: 229.0 / 255.0, blue: 117.0 / 255, alpha: 1.0)
	}
	@objc public class func attributeKey () -> NSAttributedString.Key {
		return NSAttributedString.Key(rawValue: "BeatReview")
	}
    
    @objc public override init() {
        BeatAttributes.registerAttribute(BeatReview.attributeKey().rawValue)
        super.init()
    }
		
    @objc public init(delegate:BeatEditorDelegate) {
        self.delegate = delegate
        super.init()
        setup()
    }
	
    /// Load review ranges
	@objc public func setup() {
		guard let documentSettings = self.delegate?.documentSettings
			else { return }
        
        BeatAttributes.registerAttribute(BeatReview.attributeKey().rawValue)
		setupReviews(ranges: documentSettings.get(DocSettingReviews) as? NSArray ?? [])
	}
	
    /// Loads review attributes to text view
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
    
    /// Creates an array of review ranges for saving as JSON
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
                // TODO: Fix review attribute ranges
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
    
    /// Stores a single review item
    @objc public func saveReview(item: BeatReviewItem) {
        let trimmedString = item.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if (trimmedString.count > 0 && trimmedString != "") {
            // Save review if it's not empty
            delegate?.addAttribute(BeatReview.attributeKey().rawValue, value: item, range: currentRange)
        }
        
        self.delegate?.formatting.refreshBackground(for: currentRange)
        delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review edit")))
        
		changeDone()
    }
	
    /// Deletes a review item from text view
    public func deleteReview(item:BeatReviewItem) {
		guard let delegate else { print("No delegate set for review editor"); return }
		
        var deleteRange = NSMakeRange(NSNotFound, 0)
        delegate.textStorage().enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, delegate.text().count), using: { value, range, stop in
            let review = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
			
            if (review == item) {
                deleteRange = range
                stop.pointee = true
            }
        })
        
        if (deleteRange.location != NSNotFound) {
            delegate.textStorage().removeAttribute(BeatReview.attributeKey(), range: deleteRange)
			delegate.textDidChange(Notification(name: Notification.Name(rawValue: "Review deletion")))
            
			self.closePopover()
            delegate.formatting.refreshBackground(for: deleteRange)
            
            changeDone()
        }

        // Commit to attributed text cache
        _ = delegate.attributedString()
    }
    
    @objc public func applyReview(item:BeatReviewItem) {
        self.closePopover()

		guard let delegate = self.delegate,
              let textView = delegate.getTextView()
        else { return }
        
        // textStorage has different optionality on macOS and iOS. Nicely done again, Apple.
        #if os(macOS)
            guard let textStorage = textView.textStorage else { return }
        #else
            let textStorage = textView.textStorage
        #endif
            
        // Move the cursor at the end of review
        var effectiveRange: NSRange = NSMakeRange(0, 0)
        
        let attr:BeatReviewItem = textStorage.attribute(BeatReview.attributeKey(), at:textView.selectedRange().location,
                                                        longestEffectiveRange: &effectiveRange,
                                                        in: NSMakeRange(0, delegate.text().count)) as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
        
        if (effectiveRange.location != NSNotFound && currentRange.length > 0 && !attr.emptyReview) {
			textView.selectedRange = NSMakeRange(effectiveRange.location + effectiveRange.length, 0)
        }
        
        // Commit to attributed text cache
        _ = delegate.attributedString()
    }
	
	func reviewItem(at location:Int) -> BeatReviewItem? {
		let attr = delegate?.textStorage().attribute(BeatReview.attributeKey(), at: location, effectiveRange: nil)
		return attr as? BeatReviewItem
	}
}


// MARK: - Review popover view (cross-platform)

/// Don't ask me about this code.

extension BeatReview {
    @objc public func showReviewIfNeeded(range:NSRange, forEditing:Bool) {
        guard let delegate else { return }
        if delegate.text().count == 0 || delegate.selectedRange.location == delegate.text().count { return }
        
        if forEditing {
            showReviewEditorIfNeeded(range: range, forEditing: forEditing)
        } else {
            let loc = delegate.selectedRange.location
            let item = self.delegate?.textStorage().attribute(BeatReview.attributeKey(), at: loc, effectiveRange: nil) as? BeatReviewItem
            
            if let review = item, !review.emptyReview, review != previouslyShownReview {
                self.showReviewEditorIfNeeded(range: range, forEditing: false)
                previouslyShownReview = review
            } else {
                previouslyShownReview = nil
                self.closePopover()
                #if os(iOS)
                self.delegate?.getTextView().becomeFirstResponder()
                #endif
            }
        }
    }
    
	@objc public func showReviewEditorIfNeeded(range:NSRange, forEditing:Bool) {
		guard let delegate = self.delegate else { return }
		
		// Initialize an empty review item
		var reviewItem = BeatReviewItem(reviewString: "")
		
		// If the cursor landed on a review, display the review at that location
		if range.length == 0 {
			if let item = self.reviewItem(at: range.location) {
                #if os(iOS)
                // on iPhone, we won't show it if it's the same we just showed
				if self.previouslyShownReview == item {
					closePopover()
					return
				}
                // ... if we *are* showing it, let's end editing as well
                self.delegate?.getTextView().endEditing(true)
                #endif
				// Set new review and store it
				reviewItem = item
				self.previouslyShownReview = reviewItem
			} else {
				// Zero length and no review available, just return
				self.previouslyShownReview = nil
				closePopover()
				return
			}
		}
				
		if ((currentRange == range || reviewItem == currentItem) && self.popoverVisible) {
			// If a review popover is already visible for the current item, do nothing
			return
		} else if (reviewItem != currentItem) {
			// If this item is currently edited, we'll close the popover before proceeding
			closePopover()
		}
		
		// Store inspected review item and its range
		currentRange = range
		currentItem = reviewItem
		var reviewRange = range
		
		// This is a NEW, empty review. We'll check if there's another item right next to it and join the ranges.
		if (reviewItem.emptyReview && forEditing) {
			delegate.textStorage().enumerateAttribute(BeatReview.attributeKey(), in: range, using: { value, rng, stop in
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
			if (NSMaxRange(displayRange) > delegate.text().count) {
				displayRange.location -= 1
			}
			reviewRange = displayRange
		}
        
		// Create editor popover if we're not already displaying it
        if self.reviewEditor?.item != reviewItem {
            self.reviewEditor = BeatReviewEditor(review: reviewItem, delegate: self, editable: forEditing)
            self.reviewEditor?.show(range: range, editable: forEditing, sender: delegate.getTextView())
        }
	}
	    
    @objc public func closePopover() {
		self.reviewEditor?.close()
		self.reviewEditor = nil
    }
    
    @objc public var editorVisible:Bool {
        return (self.reviewEditor != nil)
    }
    
    func editorDidClose(for item:BeatReviewItem) {
        let string = item.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.count == 0 {
            deleteReview(item: item)
        }
		
		self.currentItem = nil
    }
}

// MARK: - OS compatibility layer
extension BeatReview {
	var popoverVisible:Bool {
		#if os(macOS)
            return self.reviewEditor?.popover?.isShown ?? false
		#elseif os(iOS)
            return (self.reviewEditor?.editor?.presentingViewController?.presentingViewController == self)
		#endif
	}
	
	func changeDone() {
        // Look at this mess. Come on, Apple. After you've stopped using slave labour, maybe provide some outo-of-the-box compatibility between the systems.
		#if os(macOS)
			delegate?.updateChangeCount(.changeDone)
		#elseif os(iOS)
			delegate?.updateChangeCount(.done)
		#endif
	}
}
/*
 
 meit' ei oo montaa
 sitä suurempaa
 on tavata uusi sisarus
 aamuyöllä
 
 hotellihuoneessa
 joskus kuudelta
 uuden aamun kalpea valo
 verhojen raosta
 
 sille ei oo sanoja vieläkään
 mut me ollaan totta
 sä näät mut
 mä nään sut
 
 nukahdat parin metrin päähän minusta
 mut en oo ikinä
 ollut näin lähellä
 ketään
 
 en oo ikinä
 ollut näin lähellä ketään.
 
 */
