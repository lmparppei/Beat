//
//  File.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore
import AppKit
import yswift

@objc class BeatCollaborationManager: NSObject {

	// MARK: - Host flow

	class func beginCollaboration(document: Document) {
		if document.fileURL != nil && !document.hasUnautosavedChanges {
			presentSaveRequiredAlert(for: document)
		} else {
			connectAndBeginCollaboration(document: document)
		}
	}

	private class func presentSaveRequiredAlert(for document: Document) {
		let alert = NSAlert()
		alert.messageText = "Save Required"
		alert.informativeText = "You need to save this document before starting a collaboration session.\n\n⚠️ NOTE: This is still an experimental feature, so keep a backup of the file at hand."
		alert.alertStyle = .warning
		alert.addButton(withTitle: "Save")
		alert.addButton(withTitle: "Cancel")

		guard let window = document.windowForSheet else {
			return
		}

		alert.beginSheetModal(for: window) { response in
			if response == .alertFirstButtonReturn {
				triggerSave(for: document)
			}
		}
	}
	
	private class func connectAndBeginCollaboration(document:Document) {
		let timeOut = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
			document.hideCollaborationProgressView()
			presentTimeOutMessage(document)
		}
		
		document.connectAndBeginCollaboration { roomId in
			timeOut.invalidate()
			
			Task { await MainActor.run {
				document.hideCollaborationProgressView()
				presentStartSessionSheet(for: document, roomId: roomId)
			} }
		}
	}

	private class func triggerSave(for document: Document) {
		document.save(withDelegate: self,
					   didSave: #selector(document(_:didSave:contextInfo:)),
					   contextInfo: nil)
	}

	@objc private class func document(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
		guard didSave, let document = document as? Document else { return } // user cancelled the save panel
		connectAndBeginCollaboration(document: document)
	}

	private class func presentTimeOutMessage(_ document:Document?) {
		// If the user already canceled the operation, we don't need to show this
		guard document?.collaborating ?? false else { return }
		
		let alert = NSAlert()
		alert.messageText = "Could Not Start Collaboration"
		alert.informativeText = "The server did not respond in time. Check your Internet connection. The service might be temporarily down as well."
		alert.addButton(withTitle: "OK")
		
		if let window = document?.windowForSheet {
			alert.beginSheetModal(for: window) { _ in
				document?.endCollaboration(documentClosing: false)
			}
		} else {
			alert.runModal()
			document?.endCollaboration(documentClosing: false)
		}
	}
	
	private class func presentStartSessionSheet(for document: Document, roomId:String) {
		let (accessory, nameField, _) = makeNameRoomAccessoryView(roomId: roomId)

		let alert = NSAlert()
		alert.messageText = "Start Collaboration"
		alert.informativeText = "Share this room ID with anyone you want to invite."
		alert.accessoryView = accessory
		alert.addButton(withTitle: "Start")
		alert.addButton(withTitle: "Cancel")
		alert.window.initialFirstResponder = nameField

		let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
			guard response == .alertFirstButtonReturn else { return }
			let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
			
			if let client = document.client as? YClient {
				client.clientName = name
				client.awareness.localState?.name = client.clientName
			}
			
			document.collaborationButton?.showCollaborationMenu()
		}

		if let window = document.windowForSheet {
			alert.beginSheetModal(for: window, completionHandler: handleResponse)
		} else {
			handleResponse(alert.runModal())
		}
	}

	// MARK: - Join flow

	@objc class func openJoinModal(_ roomId:String? = nil) {
		let (accessory, nameField, roomField) = makeNameRoomAccessoryView(roomId: roomId)

		let alert = NSAlert()
		alert.messageText = "Join Collaboration"
		alert.informativeText = "Enter your name and the room ID you were given."
		alert.accessoryView = accessory
		alert.addButton(withTitle: "Join")
		alert.addButton(withTitle: "Cancel")
		alert.window.initialFirstResponder = nameField

		guard alert.runModal() == .alertFirstButtonReturn else { return }

		var name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		if name.isEmpty { name = "Anonymous" }
		let roomId = roomField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !roomId.isEmpty else { return } // maybe a validation alert here… or, oh well, we need a view controller for the whole thing later on

		BeatUserDefaults.shared().save(name, forKey: "userName")
		joinDocument(room: roomId)
	}

	class func joinDocument(room: String) {
		guard let delegate = NSApplication.shared.delegate as? BeatAppDelegate else { return }
		delegate.joinCollaborationSession(room)
	}

	// MARK: - Shared accessory view

	private class func makeNameRoomAccessoryView(roomId:String? = nil) -> (view: NSView, nameField: NSTextField, roomField:NSTextField) {
		let width: CGFloat = 280
		let rowHeight: CGFloat = 24
		let spacing: CGFloat = 8

		let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight * 2 + spacing))

		let nameLabel = NSTextField(labelWithString: "Name:")
		nameLabel.frame = NSRect(x: 0, y: rowHeight + spacing, width: 70, height: rowHeight)

		let userName = BeatUserDefaults.shared().get("userName") as? String
		
		let nameField = NSTextField(frame: NSRect(x: 76, y: rowHeight + spacing, width: width - 76, height: rowHeight))
		nameField.stringValue = userName != nil ? userName! : ""
		nameField.placeholderString = "Your Name"

		let roomLabel = NSTextField(labelWithString: "Room ID:")
		roomLabel.frame = NSRect(x: 0, y: 0, width: 70, height: rowHeight)

		let roomField = NSTextField(frame: NSRect(x: 76, y: 0, width: width - 76, height: rowHeight))
		roomField.stringValue = roomId ?? ""
		roomField.placeholderString = "Room ID"
		roomField.isEditable = roomId == nil
		roomField.isSelectable = true

		container.addSubview(nameLabel)
		container.addSubview(nameField)
		container.addSubview(roomLabel)
		container.addSubview(roomField)

		return (container, nameField, roomField)
	}
}
