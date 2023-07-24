//
//  BeatPluginLibraryDataSource.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc class BeatPluginLibraryDataSource:NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
	weak var pluginManager = BeatPluginManager.shared()
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		guard let pluginManager = self.pluginManager else { return 0 }
		if (item == nil) {
			return pluginManager.availablePluginNames().count
		} else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return pluginManager!.availablePluginNames()[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
		return true
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
		return false
	}
	
	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
		return true
	}
	
}
