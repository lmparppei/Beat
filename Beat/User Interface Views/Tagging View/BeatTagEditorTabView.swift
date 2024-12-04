//
//  BeatTagEditorTabView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.8.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatTagEditorTabView:NSTabViewController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {

		var items = super.toolbarDefaultItemIdentifiers(toolbar)
		items.insert(NSToolbarItem.Identifier.flexibleSpace, at: items.count)

		return items
	}
	
	override var tabViewItems: [NSTabViewItem] {
		get {
			let items = super.tabViewItems
			for item in items {
				item.label = item.viewController?.title ?? "(none)"
			}
			return items
		}
		set {
			super.tabViewItems = newValue
		}
	}	
}
