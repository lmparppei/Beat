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

extension Document {

	/// Some collaboration events are put into the manager to make some sense into this spaghetti
	@objc @IBAction func startCollaboration(_ sender:Any?) {
		self.showCollaborationProgressView(message: "Starting…")
		BeatCollaborationManager.beginCollaboration(document: self)
	}
		
	override open func endCollaboration(documentClosing:Bool) {
		super.endCollaboration(documentClosing: documentClosing)
		
		Task {
			await MainActor.run {
				self.collaborationButton?.isHidden = true
				self.collaborationButton?.reset()
			}
		}
	}
	
	override open func setupCollaboration(joining:Bool = false) {
		super.setupCollaboration(joining: joining)
		
		// OS-specific setup
		guard let yClient else { return }
		
		self.collaborationButton?.setup(with: yClient)
		self.collaborationButton?.isHidden = false

		yClient.onPeerLeft = { [weak self] userId, members in
			Task { await MainActor.run {
				self?.textView?.updateCarets()
			} }
		}
	}
	
	
	// MARK: - Awareness
	
	override open func updateRemoteCarets() {
		Task { await MainActor.run {
			self.textView?.updateCarets()
		} }
	}
	
	
	// MARK: - UI for syncing
	
	public override func showWaitingForSync() {
		self.showCollaborationProgressView(message: "Syncing…")
	}
	
	@objc func showCollaborationProgressView(message:String) {
		let rect = CGRect(x: 0, y: 0, width: 300, height: 30)
		self.progressPanel = NSPanel(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
		
		let label = NSTextField(labelWithString: message)
		label.sizeToFit()
		label.frame.origin.x = 30.0
		label.frame.origin.y = (rect.height - label.frame.height) / 2
		
		let indicator = NSProgressIndicator(frame: CGRectMake(5.0, 5.0, 20.0, 20.0))
		indicator.style = .spinning
		indicator.startAnimation(nil)
		
		let image:NSImage
		if #available(macOS 11.0, *) {
			image = NSImage.init(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel") ?? NSImage(imageLiteralResourceName: "xmark.circle.fill")
		} else {
			image = NSImage()
		}
		
		let button = NSButton(title: "Cancel", image: image, target: self, action: #selector(stopWaitingForSync))
		button.bezelStyle = .inline
		button.sizeToFit()
		
		button.frame.origin.x = rect.width - 5.0 - button.frame.width
		button.frame.origin.y = (rect.height - button.frame.height) / 2
		
		self.progressPanel?.contentView?.addSubview(label)
		self.progressPanel?.contentView?.addSubview(indicator)
		self.progressPanel?.contentView?.addSubview(button)
		
		if let progressPanel {
			self.windowForSheet?.beginSheet(progressPanel)
		}
	}
	
	@objc func stopWaitingForSync() {
		hideWaitingForSync()
		self.yClient?.onUpdate = nil
		self.endCollaboration(documentClosing: false)
	}
	
	@objc public override func hideWaitingForSync() {
		hideCollaborationProgressView()
	}
	
	@objc public func hideCollaborationProgressView() {
		if let progressPanel {
			self.windowForSheet?.endSheet(progressPanel)
			self.progressPanel = nil
		}
	}
	
	public override func showCollaborationError(_ description: String, canReconnect: Bool, shouldClose: Bool = false) {
		Task { await MainActor.run {
			self.hideWaitingForSync()
			guard self.windowForSheet?.attachedSheet == nil else { return }
			
			let alert = NSAlert()
			alert.messageText = "Connection Error"
			alert.informativeText = description
			alert.alertStyle = .warning
			alert.addButton(withTitle: "OK")
			if canReconnect { alert.addButton(withTitle: "Reconnect") }
			
			alert.beginSheetModal(for: windowForSheet!) { [weak self] response in
				if canReconnect && response == .alertSecondButtonReturn {
					self?.yClient?.reconnect()
				} else {
					self?.endCollaboration(documentClosing: false)
				}
				
				// Close the document if needed
				if shouldClose {
					self?.close()
				}
			}
		}}
	}
	
	@objc override public func disconnectedAfterError(reason: YNetworkClientDisconnectReason.RawValue, error: NSError?) {
		let disconnectReason = YNetworkClientDisconnectReason(rawValue: reason) ?? .error
		
		switch disconnectReason {
		case .userTriggered, .hostTerminated:
			Swift.print("User triggered disconnect. This should be filtered out.")
			return  // clean disconnect, no UI update needed
		case .networkLost:
			showCollaborationError("Connection lost. Check your connection.", canReconnect: true)
		case .timedOut:
			showCollaborationError("Connection timed out.", canReconnect: true)
		case .hostNotFound:
			showCollaborationError("Server not found.", canReconnect: false)
		/*
			 // These are server errors and handled elsewhere
		case .roomNotFound:
			showCollaborationError("Room ID not found.", canReconnect: false)
		case .hostTerminated:
			showCollaborationError("The host ended the session.", canReconnect: false)
		*/
		default:
			showCollaborationError("Something went wrong.", canReconnect: yClient?.room != nil)
		}
	}
}
