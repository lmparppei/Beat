//
//  BeatRecentFileListCell.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatRecentFileCell: NSTableCellView {

	@IBOutlet weak var filename:NSTextField!
	@IBOutlet weak var date:NSTextField!
	@objc var url:NSURL?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.menu = NSMenu()
		
		let item = NSMenuItem(title: BeatLocalization.localizedString(forKey: "general.revealInFinder"), action: #selector(reveal), keyEquivalent: "")
		item.target = self
		
		self.menu?.addItem(item)
	}
	
	@objc func reveal() {
		guard let fileURL = url as? URL, let path = url?.path else { return }
		if FileManager.default.fileExists(atPath: path) {
			NSWorkspace.shared.activateFileViewerSelecting([fileURL])
		}
	}
}

class BeatRecentFilesView:NSOutlineView {
	override func menu(for event: NSEvent) -> NSMenu? {
		let point = self.convert(event.locationInWindow, from: nil)
		let row = self.row(at: point)
		
		guard row != -1,
			  let cell = self.view(atColumn: 0, row: row, makeIfNecessary: false) as? BeatRecentFileCell else { print("FAIL"); return nil }

		return cell.menu
	}
	
}
