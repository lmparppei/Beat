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
        self.setupCollaboration(string: "", joining: true)
        
        if let client = self.yClient {
            client.clientName = BeatUserDefaults.shared().get("userName") as? String ?? "Anonymous"
            client.connect(room: roomId)
        }
    }
    
    /// Disconnect, deallocate, kill listeners.
    @objc open func endCollaboration(documentClosing:Bool) {
        guard let client = self.client as? YClient else { return }
        client.close()
        
        self.client = nil
        self.collaborating = false
        

    }
    
    @objc public func connectAndBeginCollaboration(onRoomCreated:((String) -> Void)?) {
        guard let parser else { return }
        setupCollaboration(string: parser.text())
        if let client = self.client as? YClient {
            client.onRoomCreated = onRoomCreated
            client.connect()
        }
    }
    
    @objc open func setupCollaboration(string:String, joining:Bool = false) {
        self.collaborating = true
        
        let userName:String? = BeatUserDefaults.shared().get("userName") as? String
        self.client = YClient(doc: YDocument(), clientName: userName ?? "")
        
        guard let client = self.client as? YClient else { return }
        let doc = client.doc
                
        doc.transact(origin: client.origin) {
            doc.getText().insert(0, text: string)
        }
        
        // Don't allow undoing the initial transaction
        client.undoManager.clear()
        
        // Set up basic observation listener
        doc.getText().observe { [weak self] event, txn in
            self?.sharedDocumentChanged(event: event)
        }
                
        client.networkClient.onError = { e in
            Swift.print("ERROR:", e)
        }
                    
        client.onDisconnect = { [weak self] reason, error in
            if reason == .userTriggered {
                self?.endCollaboration(documentClosing: false)
            }
        }
        
        client.onAwarenessUpdate = { [weak self] awareness in
            self?.updateRemoteCarets()
        }
            
        //client.connect(room: "test")
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
                    Swift.print("Revision:", revision)
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
        }
    }
    
    @objc public func removeSharedAttribute(_ key: NSAttributedString.Key, range: NSRange) {
        guard BeatCollaborationUtils.supportedSharedAttributes.contains(key) else { return }
        
        self.yClient?.removeSharedAttribute(key: key, range: range)
    }
}

@objc class BeatCollaborationUtils:NSObject {
    @objc public static var supportedSharedAttributes: [NSAttributedString.Key] = [BeatRevisions.attributeKey()]
}
