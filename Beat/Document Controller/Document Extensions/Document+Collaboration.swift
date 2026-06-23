//
//  Document+YDocument.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 17.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore
import yswift

/*
 
 WARNING: THESE CAN'T BE HERE
 
 */
fileprivate var markedTextRange:NSRange?

extension Document {

	@objc var yClient:YClient? { return self.client as? YClient }		
	
	@objc @IBAction func startCollaboration(_ sender:Any?) {
		BeatCollaborationManager.beginCollaboration(document: self)
	}
	
	@objc func joinCollaboration(roomId:String) {
		self.setupCollaboration(string: "", joining: true)
		
		if let client = self.yClient {
			client.clientName = BeatUserDefaults.shared().get("userName") as? String ?? "Anonymous"
			client.connect(room: roomId)
		}
	}
	
	/// Disconnect, deallocate, kill listeners.
	@objc func endCollaboration(documentClosing:Bool) {
		guard let client = self.client as? YClient else { return }
		client.close()
		
		self.client = nil
		self.collaborating = false
		
		Task {
			await MainActor.run {
				self.collaborationButton?.isHidden = true
				self.collaborationButton?.reset()
			}
		}
	}
	
	@objc func connectAndBeginCollaboration(onRoomCreated:((String) -> Void)?) {
		setupCollaboration(string: self.parser.text())
		if let client = self.client as? YClient {
			client.onRoomCreated = onRoomCreated
			client.connect()
		}
	}
	
	@objc func setupCollaboration(string:String, joining:Bool = false) {
		self.collaborating = true
		
		let userName:String? = BeatUserDefaults.shared().get("userName") as? String
		self.client = YClient(doc: YDocument(), clientName: userName ?? "")
		
		guard let client = self.client as? YClient else { return }
		let doc = client.doc
		
		self.collaborationButton?.setup(with: client)
		self.collaborationButton?.isHidden = false
		
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
			self?.textView?.updateCarets()
		}
				
		//client.connect(room: "test")
	}
	
	
	// MARK: Shared document change listener
	
	func sharedDocumentChanged(event:YEvent) {
		guard let textStorage = self.textStorage(),
			  let client = self.yClient,
			  let e = event as? YTextEvent
		else { return }
		
		let wasEditing = textStorage.isEditing
		
		// Save current selection
		let selectedRange = self.selectedRange()
		var selStart = selectedRange.location
		var selEnd = selectedRange.location + selectedRange.length
		
		var pos = 0
		
		// Avoid local echo
		if event.transaction.origin as? String == client.origin, !self.undoManager.isUndoing, !self.undoManager.isRedoing {
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
				
				self.parser.parseChange(in: NSMakeRange(pos, 0), with: str)
				self.textStorage().insert(attrStr, at: pos)
									
				// Push selection forward if insert is before or at caret
				if pos <= selStart { selStart += insertLen }
				if pos <= selEnd { selEnd += insertLen }
				
				pos += insertLen
			} else if let delete = d.delete {
				let range = NSMakeRange(pos, delete)
				
				self.parser.parseChange(in: NSMakeRange(pos, delete), with: "")
				
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

		self.textDidChange(nil)
		
		// Restore selection, clamped to actual text storage length
		let length = self.textStorage().length
		let newStart = min(selStart, length)
		let newEnd   = min(selEnd,   length)
		
		// Set new selection but don't trigger the normal selection change event
		self.skipSelectionUpdate = true
		self.setSelectedRange(NSMakeRange(newStart, newEnd - newStart))
	}
	
	// MARK: - Selection update
	
	@objc func updateSelectionAwareness() {
		self.yClient?.updateSelectedRange(self.selectedRange())
	}
	
	
	// MARK: - Undo
	
	@objc func collaborationUndo() {
		guard let client = self.yClient else { return }
		client.undoManager.undo()
	}
	
	@objc func collaborationRedo() {
		guard let client = self.yClient else { return }
		client.undoManager.redo()
	}
	
	
	// MARK: - Shared attributes
	
	@objc static var supportedSharedAttributes: [NSAttributedString.Key] = [BeatRevisions.attributeKey()]
	
	open override func addSharedAttribute(_ key: NSAttributedString.Key!, value: Any!, range: NSRange) {
		guard Document.supportedSharedAttributes.contains(key) else { return }
		
		if key == BeatRevisions.attributeKey(), let value = value as? BeatRevisionItem {
			self.yClient?.addSharedAttribute(key: key, value: value.generationLevel, range: range)
		}
	}
	
	open override func removeSharedAttribute(_ key: NSAttributedString.Key, range: NSRange) {
		guard Document.supportedSharedAttributes.contains(key) else { return }
		
		self.yClient?.removeSharedAttribute(key: key, range: range)
	}
}
