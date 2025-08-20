//
//  DiffTimestampMenu.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class DiffTimestampMenu: NSPopUpButton {
	func selectCommit(_ version: VersionItem) {
		guard let menu = menu else { return }
		
		for item in menu.items {
			guard let menuItem = item as? DiffTimestampMenuItem else { continue }
			let versionItem = menuItem.version
			
			if (version.timestamp.count > 0 && versionItem.timestamp == version.timestamp) ||
				(version.URL != nil && versionItem.URL == version.URL) {
				select(item)
				break
			}
		}
	}
}

class DiffTimestampMenuItem: NSMenuItem {
	var version:VersionItem = VersionItem()
}
