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

import JavaScriptCore

/// JS API exports for the individual review items (objects attached to text)
@objc public protocol BeatReviewItemExports:JSExport {
    var string:String { get set }
    var keywords: [String] { get }
    var emptyReview:Bool { get }
}

/// JS API exports for the main review class
@objc public protocol BeatReviewExports:JSExport {
    func saveReview(_ item: BeatReviewItem)
    func deleteReview(_ item:BeatReviewItem)
    func getReviews() -> [BeatReviewItem]
    func item(at location: Int) -> BeatReviewItem?
	func rangeForReview(_ review:BeatReviewItem) -> NSRange
	func reviewsChanged()
    
    var popoverVisible:Bool { get }
    var isEditing:Bool { get }
}


// MARK: - Review item

@objc public class BeatReviewItem:NSObject, NSCopying, NSCoding, BeatReviewItemExports {
	@objc public var string:String = ""
	
    @objc public var keywords:[String] {
        let string = self.string as NSString
        if string.range(of: "#").location == NSNotFound { return [] }
        
		// Regexes are highly inefficient, but a lookup is only used if a hash symbol is found
        let pattern = "#(\\w+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let results = regex.matches(in: self.string, options: [], range: NSRange(location: 0, length: string.length))
            return results.map { string.substring(with: $0.range(at: 1)) }
        } catch {
            print("Regex error: \(error)")
            return []
        }
    }
    
	@objc public var emptyReview:Bool {
		get {
            let string = self.string as NSString
			if (string.length == 0) {
				return true
			} else {
				return false
			}
		}
	}
	
	@objc public init(reviewString:NSString?) {
		string = (reviewString as? String ?? "")
		super.init()
	}
	
	public required init?(coder: NSCoder) {
		super.init()
		string = coder.decodeObject(forKey: "string") as? String ?? ""
	}
	
	public func encode(with coder: NSCoder) {
		coder.encode(string, forKey: "string")
	}
	
	public func copy(with zone: NSZone? = nil) -> Any {
		let item = BeatReviewItem(reviewString: self.string as NSString)
		return item
	}
}


// MARK: - Review manager

@objc public class BeatReview: NSObject, BeatReviewExports {
    public func test(_ idx:BeatReviewItem?) -> BeatReviewItem? {
        return self.getReviews().first
    }
    
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
            
            if (NSMaxRange(prevRange) + 1 == range.location && item.string == prevString as String) {
                // TODO: Fix review attribute ranges
                print("We should fix this attribute...")
            }
            
            ranges.add([
                "range": [range.location, range.length],
                "string": item.string
            ])
            
            if (!item.emptyReview) {
                prevRange = range
                prevString = item.string as NSString
            }
        }
        
        return ranges
    }
    
    /// Stores a single review item
    @objc public func saveReview(_ item: BeatReviewItem) {
        let trimmedString = item.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if (trimmedString.count > 0 && trimmedString != "") {
            // Save review if it's not empty
            delegate?.addAttribute(BeatReview.attributeKey().rawValue, value: item, range: currentRange)
        }
        
        self.delegate?.formatting.refreshBackground(for: currentRange)
        delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review edit")))
        
        // Commit to attributed text cache
        _ = delegate?.getAttributedText()
		changeDone()
    }
	
    /// Deletes a review item from text view
    public func deleteReview(_ item:BeatReviewItem) {
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
        _ = delegate.getAttributedText()
    }
    
    /// Applies changes to a review item
    @objc public func applyReview(_ item:BeatReviewItem) {
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
	
    @objc public func rangeForReview(_ review:BeatReviewItem) -> NSRange {
        return rangeForReview(review, startPosition: 0)
    }
    
    @objc public func rangeForReview(_ review:BeatReviewItem, startPosition:Int) -> NSRange {
		var effectiveRange: NSRange = NSMakeRange(NSNotFound, 0)
		
		guard let delegate = self.delegate,
			  let textView = delegate.getTextView()
		else { return effectiveRange }
				
		// textStorage has different optionality on macOS and iOS. Nicely done again, Apple.
		#if os(macOS)
			guard let textStorage = textView.textStorage else { return effectiveRange }
		#else
			let textStorage = textView.textStorage
		#endif
		
        textStorage.enumerateAttribute(BeatReview.attributeKey(), in: textStorage.range) { attr, range, stop in
            guard let reviewItem = attr as? BeatReviewItem else { return }
            if reviewItem == review, !review.emptyReview {
                effectiveRange = range
                stop.pointee = true
            }
        }
        
		return effectiveRange
	}
	
	@objc public func reviewsChanged() {
		delegate?.textDidChange(Notification(name: Notification.Name(rawValue: "Review edit")))
	}
	    
    /// Alias for conforming to ObjC plugin API protocol
	public func item(at location: Int) -> BeatReviewItem? { return reviewItem(at: location) }
	
    /// Returns a review object at given text position
	func reviewItem(at location:Int) -> BeatReviewItem? {
		let attr = delegate?.textStorage().attribute(BeatReview.attributeKey(), at: location, effectiveRange: nil)
		return attr as? BeatReviewItem
	}
	
    /// Returns all review items stored in the editor text
	public func getReviews() -> [BeatReviewItem] {
		var reviewList:[BeatReviewItem] = []
		
		guard let string = self.delegate?.attributedString() as? NSAttributedString
		else { print("Warning: No string for fetching reviews"); return reviewList }
		
		string.enumerateAttribute(BeatReview.attributeKey(), in: NSMakeRange(0, string.length)) { value, range, stop in
			let review:BeatReviewItem = value as? BeatReviewItem ?? BeatReviewItem(reviewString: "")
			let clampedRange = range.clamped(to: string.length)
			
			if (!review.emptyReview && clampedRange.length > 0) {
				reviewList.append(review)
			}
		}
		
		return reviewList
	}
	
    @objc public var popoverVisible:Bool {
        #if os(macOS)
            return self.reviewEditor?.popover?.isShown ?? false
        #elseif os(iOS)
            return (self.reviewEditor?.editor?.presentingViewController?.presentingViewController == self)
        #endif
    }
    
    func changeDone() {
        delegate?.addToChangeCount()
    }
    
    public var isEditing:Bool {
        #if os(macOS)
            guard let reviewEditor, let popover = reviewEditor.popover, let editor = reviewEditor.editor
            else { return false }
            
            return popover.isShown && editor.editable
        #else
            return false
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
