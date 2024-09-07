//
//  BeatPreviewController+Settings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension BeatPreviewController {
	@IBAction func showPreviewOptions(sender:NSButton) {
		self.optionsPopover = NSPopover()
		let options = BeatPreviewOptions()
		options.editorDelegate = self.delegate
		
		self.optionsPopover?.contentViewController = options
		self.optionsPopover?.behavior = .transient
		self.optionsPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
	}
}
