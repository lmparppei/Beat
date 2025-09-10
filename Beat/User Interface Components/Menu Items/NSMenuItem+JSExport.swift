//
//  NSMenuItem+JSExport.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.9.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//
//  Provides JS API access to all menu items

@objc protocol NSMenuExports:JSExport {
	var title:String { get set }
	func getMenuItems() -> [NSMenuItem]
}

@objc extension NSMenu:@retroactive JSExport, NSMenuExports {
	@objc func getMenuItems() -> [NSMenuItem] {
		return self.items
	}
	
}

/// JS API access for menu items
@objc protocol NSMenuItemExports:JSExport {
	var title:String { get set }
	var keyEquivalent:String { get set }
	var keyEquivalentModifierMask:NSEvent.ModifierFlags { get set }
	var target:AnyObject? { get set }
	var action:Selector? { get set }
	var menu:NSMenu? { get set }
	var submenu:NSMenu? { get set }
	var isHidden:Bool { get }
}

extension NSMenuItem:@retroactive JSExport, NSMenuItemExports {
}
