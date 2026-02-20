//
//  BeatReview+Popover.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 11.2.2026.
//

import Foundation

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

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
            deleteReview(item)
        }
        
        self.currentItem = nil
    }
}

/*
 
 far away from you
 in a foreign country
 foreign flags
 and
 a train station
 on which, i just realize
   I've been on weeks prior
 this is my life now
 
 the vines hide the ancient walls
 i cover myself
 i hide so much from you
 to protect you
 from my very being
 
 this is my life for now
 cities blend into another
 countries become a blur of
 languages and hotel rooms
 
 faces crumble away
 flakes of old paintings
 my body deprecates
 at the same pace
 outside and inside
 
 so far away
  from you
 
 */
