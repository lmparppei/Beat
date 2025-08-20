//
//  DiffViewerStatusView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class DiffViewerStatusView: NSView {
	@IBOutlet weak var icon: NSImageView?
	@IBOutlet weak var text: NSTextField?
	
	func update(uncommitedChanges: Bool) {
		if uncommitedChanges {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemYellow
			}
			
			text?.stringValue = "You have uncommitted changes"
		} else {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemGreen
			}
			
			text?.stringValue = "Up to date"
		}
	}
}
