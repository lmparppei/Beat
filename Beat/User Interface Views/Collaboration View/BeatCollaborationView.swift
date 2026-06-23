//
//  BeatCollaborationView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import yswift

class CollaborationButton:NSButton {
	var popover: NSPopover?
	var collaborationMenu: CollaborationView?

	weak var client:YClient?
	
	private var observers: [NSObjectProtocol] = []
	private var transientPopover: NSPopover?

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
		
		vc.setup(with: client)
		collaborationMenu = vc
		
		setupNotificationListeners()
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

	// MARK: - Click

	@objc private func handleClick() {
		guard let client, let vc = collaborationMenu else { return }
		
		if let popover, popover.isShown {
			popover.close()
			self.popover = nil
			return
		}

		vc.setup(with: client)
		
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
			nc.addObserver(forName: .YDisconnected, object: client, queue: .main) { [weak self] _ in
				self?.popover?.close()
				self?.reset()
				
				self?.showTransient("Disconnected. Remember to save a local copy.")
				
				//self?.transientPopover?.close()
				//self?.removeFromSuperview()
			}
		]
	}

	// MARK: - Transient notification

	private func showTransient(_ message: String) {
		transientPopover?.close()
		guard !(popover?.isShown ?? false) else { return }

		let label = NSTextField(labelWithString: message)
		label.font = .systemFont(ofSize: 12)
		label.textColor = .secondaryLabelColor
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

	weak var client: YClient?
	//private var role: String = ""

	// Snapshot used for table display, refreshed in reload()
	private var participants: [YUserAwareness] = []

	func setup(with client: YClient) {
		self.client = client
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
			return circleImage(color: .systemGray, diameter: 10)
		case "name":
			return participant.name
		default:
			return nil
		}
	}

	
	// MARK: - Actions

	@IBAction func copyRoomID(_ sender: Any?) {
		if let roomId = client?.room {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(roomId, forType: .string)
		}
	}
	
	@IBAction func disconnect(_ sender: Any?) {
		client?.close()
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
