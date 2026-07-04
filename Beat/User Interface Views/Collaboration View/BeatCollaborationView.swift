//
//  BeatCollaborationView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore
import yswift

class CollaborationButton:NSButton {
	var popover: NSPopover?
	var collaborationMenu: CollaborationView?

	weak var client:YClient?
	@IBOutlet weak var document:BeatEditorDelegate?
	
	private var observers: [NSObjectProtocol] = []
	private var transientPopover: NSPopover?

	private enum CollaborationButtonState {
		case connected
		case disconnected
		case reconnecting
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		target = self
		action = #selector(handleClick)
		
		self.wantsLayer = true
		self.layer?.cornerRadius = 10
		self.layer?.backgroundColor = NSColor.black.cgColor
	}

	deinit {
		observers.forEach { NotificationCenter.default.removeObserver($0) }
	}

	func setup(with client: YClient) {
		self.client = client
		
		let sb = NSStoryboard(name: "BeatCollaborationView", bundle: .main)
		guard let vc = sb.instantiateInitialController() as? CollaborationView else { print("Failed to load"); return }
		vc.loadView()
		
		vc.setup(with: client, document: self.document)
		collaborationMenu = vc
		
		setupNotificationListeners()

		self.changeStatus(status: .connected)
	}
	
	/// Resets the status of this menu to default (hidden, no client)
	func reset() {
		Task {
			await MainActor.run {
				self.isHidden = true
				self.popover?.close()
				self.client = nil
				self.collaborationMenu = nil
			}
		}
	}

	@objc public func showCollaborationMenu() {
		self.handleClick()
	}
	
	// MARK: - Click

	@objc private func handleClick() {
		guard let client, let vc = collaborationMenu else { return }
		
		if let popover, popover.isShown {
			popover.close()
			self.popover = nil
			return
		}

		vc.setup(with: client, document: self.document)
		
		let pop = NSPopover()
		pop.contentViewController = vc
		pop.behavior = .semitransient
		pop.contentSize = NSSize(width: 260, height: 200)
		pop.show(relativeTo: bounds, of: self, preferredEdge: .minY)
		popover = pop
	}
	
	// MARK: - Notifications

	private func setupNotificationListeners() {
		observers.forEach { NotificationCenter.default.removeObserver($0) }
		
		guard let client else { return }
		
		let nc = NotificationCenter.default

		observers = [
			nc.addObserver(forName: .YPeerJoined, object: client, queue: .main) { [weak self] note in
				let name = note.userInfo?["name"] as? String ?? "Someone"
				self?.collaborationMenu?.reload()
				self?.showTransient("\(name) joined")
			},
			nc.addObserver(forName: .YPeerLeft, object: client, queue: .main) { [weak self] note in
				let name = note.userInfo?["name"] as? String ?? "Someone"
				self?.collaborationMenu?.reload()
				self?.showTransient("\(name) left")
			},
			nc.addObserver(forName: .YDisconnected, object: client, queue: .main) { [weak self] note in
				self?.transientPopover?.close()
				
				if let rawReason = note.userInfo?["reason"] as? Int,
					let reason = YNetworkClientDisconnectReason(rawValue: rawReason) {
					if reason == .userTriggered || reason == .hostTerminated {
						// User triggered session end
						self?.popover?.close()
						self?.reset()
					}
				} else {
					// Change status
					self?.changeStatus(status: .disconnected)
				}
				
				self?.showTransient("Disconnected. Remember to save a local copy.")
			},
			nc.addObserver(forName: .YReconnecting, object: client, queue: .main) { [weak self] note in
				self?.transientPopover?.close()
				self?.changeStatus(status: .reconnecting)
			},
			nc.addObserver(forName: .YSessionEnded, object: client, queue: .main) { [weak self] note in
				self?.showTransient("Session ended. Remember to save a local copy.")
				self?.reset()
			}
		]
	}
		
	private func changeStatus(status:CollaborationButtonState) {
		
		if status == .connected {
			self.title = "Collaborating"
			if #available(macOS 11.0, *) {
				self.image = NSImage.init(systemSymbolName: "person.2.fill", accessibilityDescription: nil)
			}
		} else if status == .disconnected {
			self.title = "Disconnected"
			if #available(macOS 11.0, *) {
				self.image = NSImage.init(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
			}
		} else if status == .reconnecting {
			self.title = "Reconnecting…"
			if #available(macOS 11.0, *) {
				self.image = NSImage.init(systemSymbolName: "phone.connection", accessibilityDescription: nil)
			}
		}
		
	}

	// MARK: - Transient notification

	private func showTransient(_ message: String) {
		transientPopover?.close()
		guard !(popover?.isShown ?? false) else { return }

		let label = NSTextField(labelWithString: message)
		label.font = .systemFont(ofSize: 12)
		label.textColor = .labelColor
		label.sizeToFit()

		let padding: CGFloat = 12
		let container = NSView(frame: NSRect(
			x: 0, y: 0,
			width: label.frame.width + padding * 2,
			height: label.frame.height + padding * 2
		))
		label.frame.origin = NSPoint(x: padding, y: padding)
		container.addSubview(label)

		let vc = NSViewController()
		vc.view = container

		let pop = NSPopover()
		pop.contentViewController = vc
		pop.contentSize = container.frame.size
		pop.behavior = .transient
		pop.show(relativeTo: bounds, of: self, preferredEdge: .minY)
		transientPopover = pop

		DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak pop] in
			pop?.close()
		}
	}
}

class CollaborationView: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	@IBOutlet weak var roleField: NSTextField?
	@IBOutlet weak var roomField: NSTextField?
	@IBOutlet weak var participantsList: NSTableView?
	@IBOutlet weak var statusLight: NSButton?
	@IBOutlet weak var statusLabel: NSTextField?

	weak var document: BeatEditorDelegate?
	weak var client: YClient?
	//private var role: String = ""

	// Snapshot used for table display, refreshed in reload()
	private var participants: [YUserAwareness] = []

	func setup(with client: YClient, document:BeatEditorDelegate?) {
		self.client = client
		self.document = document
		reload()
	}

	func reload() {
		guard let client else { return }
		participants = client.awareness.states.values.compactMap {
			// Only include online users and our local presence
			return (client.networkClient.activePeers.contains($0.userId) || $0.userId == client.userId) ? $0 : nil
		}
			
		//roleField?.stringValue = role
		roomField?.stringValue = client.room ?? "(none)"
		updateStatus()
		participantsList?.reloadData()
	}

	private func updateStatus() {
		let connected = client?.isConnected ?? false
		statusLabel?.stringValue = connected ? "Connected" : "Disconnected"
		statusLight?.image = circleImage(color: connected ? .systemGreen : .systemRed, diameter: 10)
	}

	// MARK: - NSTableViewDataSource
	// Column identifiers expected in IB: "dot" (NSImageCell) and "name" (NSTextFieldCell)

	func numberOfRows(in tableView: NSTableView) -> Int {
		participants.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		guard row < participants.count else { return nil }
		let participant = participants[row]

		switch tableColumn?.identifier.rawValue {
		case "dot":
			return userColorImage(for: participant.userId)
		case "name":
			return participant.name
		default:
			return nil
		}
	}
	
	func userColorImage(for userId: String) -> NSImage? {
		var image:NSImage?
		
		if let color = self.client?.userColor(for: userId) {
			image = BeatColors.labelImage(forColor: color, size: CGSize(width: 12, height: 12))
		}
		
		return image
	}

	
	// MARK: - Actions

	@IBAction func copyRoomID(_ sender: Any?) {
		if let roomId = client?.room {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(roomId, forType: .string)
		}
	}
	
	@IBAction func disconnect(_ sender: Any?) {
		if let client {
			if client.isConnected {
				client.close()
			} else {
				document?.endCollaboration(withDocumentClosing: false)
			}
		}
	}
	
	@IBAction func shareJoinLink(_ sender: NSButton) {
		guard let roomId = client?.room else { return }

		let url = URL(string: "beat://join?\(roomId)")!
		let inviteText = "Join my (beat) session!\n\n\(url.absoluteString)"
				
		let picker = NSSharingServicePicker(items: [inviteText])
		picker.delegate = self
		picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
	}

	// MARK: - Helpers

	private func circleImage(color: NSColor, diameter: CGFloat) -> NSImage {
		let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
			color.setFill()
			NSBezierPath(ovalIn: rect).fill()
			return true
		}
		image.isTemplate = false
		return image
	}
}


// MARK: - Sharing picker delegate

extension CollaborationView:NSSharingServicePickerDelegate {
	/// Adds "Copy Link" sharing option
	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
		
		let string = BeatLocalization.localizedString(forKey: "general.copyLink")
		
		var image:NSImage
		if #available(macOS 11.0, *) {
			image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)!
		} else {
			image = NSImage()
		}
		
		let copyService = NSSharingService(title: string,
										   image: image,
										   alternateImage: nil) {
			guard let string = items.first as? String else { return }
			
			if let range = string.range(of: "beat:") {
				let url = string.suffix(from: range.lowerBound)
				NSPasteboard.general.clearContents()
				NSPasteboard.general.setString(String(url), forType: .string)
			}			
		}
		return [copyService] + proposedServices
	}
}
