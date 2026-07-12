//
//  BeatDocumentBaseController+Collaboration.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 23.6.2026.
//

import Foundation
import yswift

extension BeatDocumentBaseController {
    @objc public var yClient:YClient? { return self.client as? YClient }
        
    @objc public func joinCollaboration(roomId:String) {
        // Replace the Beat URL scheme just in case
        let room = roomId.replacingOccurrences(of: "beat://join?", with: "")
        
        self.setupCollaboration(joining: true)
        
        if let client = self.yClient {
            self.waitingForRemoteTextFormatting = true
            showWaitingForSync()
            
            // When joining a collaboration session, we need to wait for sync step 2 before allowing any changes.
            // This listener is nilled once it has run successfully.
            client.onUpdate = { [weak self] type in
                guard let self else { return }
                
                if type == .step2 {
                    self.hideWaitingForSync()
                    self.yClient?.onUpdate = nil
                }
            }
                        
            client.clientName = BeatUserDefaults.shared().get("userName") as? String ?? "Anonymous"
            client.connect(room: room)
        }
    }
    
    @objc open func showWaitingForSync() {
        Swift.print("Override showWaitingForSync in OS implementation")
    }
    
    @objc open func hideWaitingForSync() {
        Swift.print("Override hideWaitingForSync in OS implementation")
    }
    
    /// Override this  with code to apply formatting to the text received from remote user when connecting.
    @objc open func applyInitialRemoteTextFormatting() {
        Swift.print("Override applyRemoteInitialFormatting in OS implementation")
    }
    
    @objc open func showCollaborationError(_ description: String, canReconnect: Bool, shouldClose: Bool = false) {
        Swift.print("Override showError in OS implementation")
    }
    
    @objc open func disconnectedAfterError(reason:YNetworkClientDisconnectReason.RawValue, error:NSError?) {
        Swift.print("Override disconnectedAfterError in OS implementation")
    }
        
    /// Disconnect, deallocate, kill listeners.
    @objc open func endCollaboration(documentClosing:Bool) {
        guard let client = self.client as? YClient else { return }
        client.close()
        
        self.client = nil
        self.collaborating = false
        
        if let lm = self.layoutManager() as? BeatLayoutManager {
            lm.resetRemoteUserSelections()
        }
        
        // Do any further teardown in OS-specific implementation
    }
    
    @objc public func connectAndBeginCollaboration(onRoomCreated:((String) -> Void)?) {
        setupCollaboration()
        if let client = self.client as? YClient {
            client.onRoomCreated = onRoomCreated
            client.connect()
        }
    }
    
    @objc open func setupCollaboration(joining:Bool = false) {
        self.collaborating = true
        
        guard let server = Bundle(for: BeatDocumentBaseController.self).infoDictionary?["collaborationServer"] as? String else {
            Swift.print("NO SERVER DEFINED. Remember to add server name to BeatCore Info.plist")
            return
        }
        
        let userName:String? = BeatUserDefaults.shared().get("userName") as? String
        self.client = YClient(doc: YDocument(), server: server, clientName: userName ?? "")
        
        guard let client = self.client as? YClient else { return }
        let doc = client.doc
        
        var text = ""
        
        if !joining, let parser {
            // The host gives our source of truth
            text = parser.text()
        }
                
        doc.transact(origin: client.origin) {
            doc.getText().insert(0, text: text)

            if !joining {
                let settings = doc.getObject(BeatSharedDocumentSettings.self, "documentSettings")

                // Bake revisions
                // This is a little silly. We should maybe transmit the full JSON setting block here and let the receiving end apply everything they need from that.
                let revisions = self.revisionTracking.revisedRanges()
                if let additions = revisions["Addition"] {
                    for addition in additions {
                        if addition.count < 3 { continue }
                        
                        let range = NSMakeRange(addition[0].intValue, addition[1].intValue)
                        let generation = addition[2].intValue
                        
                        doc.getText().format(range.location, length: range.length, attributes: [BeatRevisions.attributeKey().rawValue: generation])
                    }
                }
                                
                // Update other metadata
                let reviewsAndRanges = self.review?.getReviewsAndRanges() ?? [:]
                for range in reviewsAndRanges.keys {
                    let review = reviewsAndRanges[range]
                    if let sharedReview = review?.sharedReview() {
                        doc.getText().format(range.location, length: range.length, attributes: [BeatReview.attributeKey().rawValue: sharedReview.uuid])
                        
                        settings.reviews.append(sharedReview)
                    }
                }
            }
        }
                
        // Don't allow undoing the initial transaction
        client.undoManager.clear()
        
        // Set up basic observation listener
        doc.getText().observe { [weak self] event, txn in
            self?.sharedDocumentChanged(event: event)
        }
        
        // Set up document setting listener (two different ways of doing it)
        setupDocumentSettings()
        
        doc.getObject(BeatSharedDocumentSettings.self, "documentSettings").observe { [weak self] event, txn in
            self?.sharedDocumentSettingsChanged(event: event)
        }
        
        client.networkClient.onError = { [weak self] description, error in
            Swift.print("Server error: \(description)")
            
            // Handle server errors
            if error.domain == "YServer", let reason = YServerError(rawValue: error.code) {
                if reason == .roomNotFound {
                    self?.showCollaborationError("Room not found.", canReconnect: false, shouldClose: true)
                }
            }
        }
                    
        client.onDisconnect = { [weak self] reason, error in
            if reason == .userTriggered {
                self?.endCollaboration(documentClosing: false)
            } else {
                // Filter out non-error reasons
                if reason != .userTriggered && reason != .hostTerminated {
                    self?.disconnectedAfterError(reason: reason.rawValue, error: error as? NSError)
                }
            }
        }
        
        client.onAwarenessUpdate = { [weak self] awareness in
            self?.updateRemoteCarets()
        }
                    
        // Do any additional UI setup on OS-specific implementation
    }
    
    @objc open func updateRemoteCarets() {
        Swift.print("!!! Override updateRemoteCarets in OS-specific implementation")
    }
    
    
    // MARK: Shared document change listener
    
    func sharedDocumentChanged(event:YEvent) {
        guard let parser = self.parser,
              let client = self.yClient,
              let e = event as? YTextEvent
        else { return }
        
        let textStorage = self.textStorage()
        let wasEditing = textStorage.isEditing
        
        // Save current selection
        let selectedRange = self.selectedRange()
        var selStart = selectedRange.location
        var selEnd = selectedRange.location + selectedRange.length
        
        var pos = 0
        
        // Avoid local echo
        if event.transaction.origin as? String == client.origin, !client.undoManager.undoing, !client.undoManager.redoing {
            return
        }
        
        self.applyingRemoteEdits = true
        if !wasEditing { textStorage.beginEditing() }
        
        // Iterate through deltas. Note that we need to parse changes before adding anything to the actual text view.
        for d in e.delta() {
            var editedRange = NSMakeRange(pos, 0)
            
            if let retain = d.retain {
                editedRange.length = retain
                pos += retain
            } else if let insert = d.insert, let str = insert as? String {
                editedRange.length = str.count
                
                let insertLen = str.count
                let attrStr = NSAttributedString(string: str)
                
                parser.parseChange(in: NSMakeRange(pos, 0), with: str)
                textStorage.insert(attrStr, at: pos)
                                    
                // Push selection forward if insert is before or at caret
                if pos <= selStart { selStart += insertLen }
                if pos <= selEnd { selEnd += insertLen }
                
                pos += insertLen
            } else if let delete = d.delete {
                let range = NSMakeRange(pos, delete)
                
                parser.parseChange(in: NSMakeRange(pos, delete), with: "")
                
                let wasEditing = self.textStorage().isEditing
                if !wasEditing { self.textStorage().beginEditing() }
                self.textStorage().replaceCharacters(in: range, with: "")
                if !wasEditing { self.textStorage().endEditing() }
                
                // Clamp and shift selection around the deleted range.
                let delEnd = pos + delete
                if selStart > pos {
                    selStart = selStart < delEnd ? pos : selStart - delete
                }
                if selEnd > pos {
                    selEnd = selEnd < delEnd ? pos : selEnd - delete
                }
            }
            
            // Handle attributes
            
            let attrs = d.getAttributes()
            if attrs.count > 0 {
                if let revision = attrs[BeatRevisions.attributeKey().rawValue] as? Int {
                    var revisionItem:BeatRevisionItem?
                    if revision >= 0 {
                        revisionItem = BeatRevisionItem(type: .addition, generation: revision)
                    } else {
                        revisionItem = BeatRevisionItem(type: .removalSuggestion, generation: 0)
                    }
                    if let revisionItem {
                        self.textStorage().addAttribute(BeatRevisions.attributeKey(), value: revisionItem, range: editedRange)
                    }
                }
            }
        }
        
        if !wasEditing { textStorage.endEditing() }
        self.applyingRemoteEdits = false

        self.textDidChange()
        
        // Restore selection, clamped to actual text storage length
        let length = self.textStorage().length
        let newStart = min(selStart, length)
        let newEnd   = min(selEnd,   length)
        
        // Set new selection but don't trigger the normal selection change event
        self.skipSelectionUpdate = true
        self.setSelectedRange(NSMakeRange(newStart, newEnd - newStart))
    }
    
    
    // MARK: - Document settings & metadata
    
    func setupDocumentSettings() {
        guard let client = self.yClient else { return }
        
        let doc = client.doc
        
        let settings = doc.getObject(BeatSharedDocumentSettings.self, "documentSettings")
        settings.$reviews
            .sink { reviews in
                // Check for any registered reviews
                Swift.print(" ---> ", reviews)
            }
            .store(in: &client.objectBag)
    }
    
    /// - warning: `keys` values are hard-coded and predefined for now.
    public func updateDocumentSettings(key:String, value:Any) {
        guard let client = self.yClient else { return }
        
        client.doc.transact(origin: client.origin) {
            let settings = client.doc.getObject(BeatSharedDocumentSettings.self, "documentSettings")
            
            if key == "reviews", let reviews = value as? [BeatSharedReview] {
                settings.reviews.assign(reviews)
            }
        }
    }
    
    public func sharedDocumentSettingsChanged(event: YEvent) {
        Swift.print("Event:",event.changes())
        //guard let doc = self.yClient?.doc, var bag = self.yClient?.objectBag else { return }
    
    }
    
    
    
    // MARK: - Selection update
    
    @objc public func updateSelectionAwareness() {
        self.yClient?.updateSelectedRange(self.selectedRange())
    }
    
    // MARK: - Undo
    
    @objc public func collaborationUndo() {
        yClient?.undoManager.undo()
    }
    
    @objc public func collaborationRedo() {
        yClient?.undoManager.redo()
    }
    
    
    // MARK: - Shared attributes
    
    @objc public func addSharedAttribute(_ key: NSAttributedString.Key!, value: Any!, range: NSRange) {
        guard BeatCollaborationUtils.supportedSharedAttributes.contains(key) else { return }
        
        if key == BeatRevisions.attributeKey(), let value = value as? BeatRevisionItem {
            self.yClient?.addSharedAttribute(key: key, value: value.generationLevel, range: range)
        } else if key == BeatReview.attributeKey(), let review = value as? BeatReviewItem, !review.emptyReview {
            self.yClient?.addSharedAttribute(key: key, value: review.uuid, range: range)
        }
    }
    
    @objc public func removeSharedAttribute(_ key: NSAttributedString.Key, range: NSRange) {
        guard BeatCollaborationUtils.supportedSharedAttributes.contains(key) else { return }
        
        self.yClient?.removeSharedAttribute(key: key, range: range)
    }
}

@objc class BeatCollaborationUtils:NSObject {
    @objc public static var supportedSharedAttributes: [NSAttributedString.Key] = [
        BeatRevisions.attributeKey(),
        BeatReview.attributeKey()
    ]
}


public class BeatSharedDocumentSettings:YObject {
    @Property var pageSize:Int = 0
    @WProperty var tags: YArray<String> = []
    @WProperty var reviews: YArray<BeatSharedReview> = []
}
