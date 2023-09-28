//
//  BeatTemplateMenuProvider.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

// MARK: - Menu provider and item for macOS

final class BeatTemplateMenuProvider:NSObject, NSMenuDelegate {

	var items:[NSMenuItem] = []
	
	public func menuWillOpen(_ menu: NSMenu) {
		menu.items = templateItems()
	}
	
	func templateItems() -> [NSMenuItem] {
		if self.items.count > 0 {
			return self.items
		}
		
		let families = BeatTemplates.families()
		
		var items:[NSMenuItem] = []
		
		let showTemplates = NSMenuItem(title: BeatLocalization.localizedString(forKey: "templates.showTutorialsAndTemplates"), action: #selector(showTemplates), keyEquivalent: "")
		items.append(showTemplates)
		items.append(NSMenuItem.separator())
		
		for f in families {
			let templates = BeatTemplates().forFamily(f)

			for template in templates {
				let item = BeatTemplateMenuItem(title: template.title, action: #selector(showTemplate), keyEquivalent: "")
				item.target = self
				item.template = template
				
				items.append(item)
			}
			
			if f != families.last {
				items.append(NSMenuItem.separator())
			}
		}
		
		self.items = items
		return self.items
	}
	
	@objc public func showTemplates() {
		guard let delegate = NSApp.delegate as? BeatAppDelegate else { return }
		delegate.showTemplates()
	}
	
	@objc public func showTemplate(sender:AnyObject?) {
		guard let item = sender as? BeatTemplateMenuItem else { return }
		
		guard let delegate = NSApp.delegate as? BeatAppDelegate,
			  let template = item.template
		else { return }
		
		delegate.showTemplate(template.filename)
	}
}

final class BeatTemplateMenuItem:NSMenuItem {
	var template:BeatTemplateFile?
}
