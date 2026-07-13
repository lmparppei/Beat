//
//  BeatReview+Collaboration.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 12.7.2026.
//

import yswift

extension BeatReview {
    
    // MARK: - Collaboration
    
    /// Adds or updates the given review in the shared collaboration array
    public func addOrUpdateSharedReview(_ review:BeatReviewItem) {
        guard let document = delegate as? BeatDocumentBaseController,
                document.collaborating,
                let client = document.client as? YClient,
                let settings = document.sharedDocumentSettings()
        else { return }

        let sharedReview = review.sharedReview()
        client.doc.transact(origin: client.origin) {
            if let i = settings.reviews.toArray().firstIndex(where: { value in
                value.uuid == sharedReview.uuid
            }) {
                settings.reviews.delete(at: i)
                settings.reviews.insert(sharedReview, at: i)
            } else {
                settings.reviews.append(sharedReview)
            }
        }
    }
    
    /// Safely removes the local item
    public func removeSharedReview(_ review:BeatReviewItem) {
        guard let document = delegate as? BeatDocumentBaseController,
                document.collaborating,
                let client = document.yClient,
                let settings = document.sharedDocumentSettings()
        else { return }
        
        client.doc.transact(origin: client.origin) {
            if let i = settings.reviews.toArray().firstIndex(where: { value in
                value.uuid == review.uuid
            }) {
                _ = settings.reviews.remove(at: i)
            }
        }
    }
    
    /// Another peer has removed a review with given UUID. We'll make sure it's removed from the editor and from the local shadow list.
    public func peerRemovedReview(uuid:String) {
        guard let attrStr = self.delegate?.attributedString().copy() as? NSAttributedString else { return }
        
        let key = BeatReview.attributeKey()
        self.reviews.removeValue(forKey: uuid)
        attrStr.enumerateAttribute(key, in: attrStr.range) { val, range, stop in
            guard let r = val as? BeatReviewItem else { return }
            
            if r.uuid == uuid {
                delegate?.textStorage().removeAttribute(key, range: range)
            }
        }
    }
    
    /// Another peer has added a review **item**. We will create a local shadow copy.
    /// - note This does NOT get reflected in the editor. We'll have to probe for changes in text attributes.
    public func peerAddedReview(_ sharedItem:BeatSharedReview) {
        let item = BeatReviewItem(reviewString: sharedItem.string as NSString, uuid: sharedItem.uuid, user: sharedItem.user)
        reviews[sharedItem.uuid] = item
        
        pendingSharedReviewUUIDs.insert(sharedItem.uuid)
    }
    
    /// Update shared values from remote source
    public func sharedReviewsDidUpdate(reviews:[BeatSharedReview]) {
        for review in reviews {
            if let _ = self.reviews[review.uuid] {
                self.reviews[review.uuid]?.string = review.string
                self.reviews[review.uuid]?.user = review.user
            }
        }
        
        if let textStorage = delegate?.textStorage(), let attrStr = textStorage.copy() as? NSAttributedString {
            attrStr.enumerateAttribute(BeatReview.attributeKey(), in: attrStr.range) { value, range, stop in
                // Go through pending items
                guard let review = value as? BeatReviewItem, review.pendingForSharedValue else { return }
                                
                if let existingValue = self.reviews[review.uuid] {
                    // Replace the placeholder item with the actual value
                    textStorage.removeAttribute(BeatReview.attributeKey(), range: range)
                    textStorage.addAttribute(BeatReview.attributeKey(), value: existingValue, range: range)
                    
                    pendingSharedReviewUUIDs.remove(review.uuid)
                }
            }
        }
    }
    
    public func handleSharedReviewChange(sharedReviews:YArray<BeatSharedReview>) {
        let localReviews = self.reviews
        
        // Build a set of current shared UUIDs for quick lookup
        let sharedUUIDs = Set(sharedReviews.map { $0.uuid })
        let localUUIDs = Set(localReviews.keys)
        
        // In shared but not local, this review was added
        for review in sharedReviews where !localUUIDs.contains(review.uuid) {
            self.peerAddedReview(review)
        }
        
        // In local but not in shared, so a peer removed this review
        for uuid in localUUIDs where !sharedUUIDs.contains(uuid) {
            self.peerRemovedReview(uuid: uuid)
        }
        
        // Update all reviews
        self.sharedReviewsDidUpdate(reviews: sharedReviews.toArray())
    }
}
