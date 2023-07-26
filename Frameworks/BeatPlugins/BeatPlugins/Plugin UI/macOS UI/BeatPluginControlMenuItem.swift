//
//  BeatPluginMenuItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 24.1.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc public protocol BeatPluginControlMenuExports:JSExport {
	@objc func addItem(_ newItem: NSMenuItem)
	@objc func removeItem(_ item: NSMenuItem)
}
@objc public class BeatPluginControlMenu:NSMenu, BeatPluginControlMenuExports {
	@objc override public func addItem(_ newItem: NSMenuItem) {
		super.addItem(newItem)
	}
	@objc override public func removeItem(_ item: NSMenuItem) {
		super.removeItem(item)
	}
}

@objc public protocol BeatPluginControlMenuItemExports:JSExport {
	@objc var on:Bool { get set }
	@objc var submenu:NSMenu? { get set }
}

public class BeatPluginControlMenuItem:NSMenuItem, BeatPluginControlMenuItemExports {
	
	var method:JSValue
	
	@objc public var on:Bool {
		get {
			if self.state == .on { return true } else { return false }
		}
		set {
			if (newValue) { self.state = .on }
			else { self.state = .off }
		}
	}
	
	@objc public init(title:String, shortcut:[String], method: JSValue) {
		self.method = method

		var keyEquivalent = ""
		var keyEquivalentMask:NSEvent.ModifierFlags = []
		
		for sc in shortcut {
			if sc == "cmd" || sc == "command" {
				keyEquivalentMask.insert(.command)
			}
			else if sc == "ctrl" || sc == "control" {
				keyEquivalentMask.insert(.control)
			}
			else if sc == "option" || sc == "opt" || sc == "alt" {
				keyEquivalentMask.insert(.option)
			}
			else if sc == "shift" {
				keyEquivalentMask.insert(.shift)
			}
			else {
				keyEquivalent = sc
			}
		}
		
		super.init(title: title, action: #selector(runMethod), keyEquivalent: keyEquivalent)
		self.keyEquivalentModifierMask = keyEquivalentMask
		self.target = self
	}
	
	@objc public func validateState() {
		if self.on {
			self.state = .on
		} else {
			self.state = .off
		}
	}
	
	@objc public func runMethod() {
		self.method.call(withArguments: [])
	}
	
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	
	
}
