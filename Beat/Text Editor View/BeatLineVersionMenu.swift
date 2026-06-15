//
//  BeatLineVersionMenu.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

/// - note: This is just a placeholder. You have to defined a menu delegate for this menu to work correctly.
class BeatLineVersionMenu: NSMenu {
	fileprivate weak var editorDelegate:BeatEditorDelegate?
	
	func populate(with line:Line?, editorDelegate:BeatEditorDelegate) {
		guard let line else { return }
		
		self.removeAllItems()
		self.editorDelegate = editorDelegate
		
		var items:[NSMenuItem] = []
		var i = 0
		
		let newVersionItem = NSMenuItem(title: BeatLocalization.localizedString(forKey: "versionMenu.newVersion"), action: #selector(addVersion), keyEquivalent: "")
		newVersionItem.target = self
		items.append(newVersionItem)
		items.append(NSMenuItem.separator())
		
		var versions:[NSMenuItem] = []
		
		for version in line.versions as? [[String:Any]] ?? [] {
			var checked = false
			var text = version["text"] as? String ?? ""
			
			// Text for current version of the string is NOT stored into the array at this point, so let's use the actual one
			if line.currentVersion == i {
				text = line.stringForDisplay()
				checked = true
			}
			
			text = "\(i+1). " + text
			
			if text.count > 50 {
				text = text.prefix(50).appending("...")
			}
			
			let item = NSMenuItem(title: text, action: #selector(switchLineVersion), keyEquivalent: "")
			item.state = checked ? .on : .off
			item.tag = i
			item.target = self
						
			versions.append(item)
			
			i += 1
		}
		
		if versions.count > 0 {
			items.append(contentsOf: versions)
		} else {
			items.append(NSMenuItem(title: BeatLocalization.localizedString(forKey: "versionMenu.noVersions"), action: nil, keyEquivalent: ""))
		}
		
		self.items = items
	}
	
	@objc func switchLineVersion(_ sender: NSMenuItem) {
		guard let editorDelegate else { return }
		editorDelegate.textActions.switch(toVersion: sender.tag)
	}
	
	@objc func addVersion(_ sender: Any?) {
		guard let currentLine = editorDelegate?.currentLine else { return }
		editorDelegate?.textActions.addVersion(for: currentLine)
	}
}
