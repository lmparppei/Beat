//
//  BeatMenuItemWithURL.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 5.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

@objcMembers public class BeatMenuItemWithStylesheet:NSMenuItem {
	@IBInspectable public var stylesheet:String?
	var userStyle = false
}

@objcMembers public class BeatStyleMenuManager:NSObject, NSMenuDelegate {
	@IBOutlet public var styleMenu:NSMenu?
	
	public func setup() {
		styleMenu?.delegate = self
		setupMenuItems()
	}
	
	func setupMenuItems() {
		guard let items = styleMenu?.items as? [BeatMenuItemWithStylesheet] else { return }
		items.forEach {
			if $0.userStyle { styleMenu?.removeItem($0) }
		}
		
		let userStyles = BeatStyles.shared.availableUserStylesheets()
		
		userStyles.forEach { stylesheet in
			let item = BeatMenuItemWithStylesheet(title: stylesheet, action: nil, keyEquivalent: "")
			// This is a bit cursed, but let's take both the target and selector from first item in this menu
			item.action = styleMenu?.items.first?.action
			item.target = styleMenu?.items.first?.target
			
			item.userStyle = true
			item.stylesheet = stylesheet
			
			styleMenu?.addItem(item)
		}
	}
	
	public func menuWillOpen(_ menu: NSMenu) {
		setupMenuItems()
	}
}
