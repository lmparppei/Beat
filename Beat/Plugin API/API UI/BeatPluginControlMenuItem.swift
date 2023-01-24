//
//  BeatPluginMenuItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 24.1.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc protocol BeatPluginControlMenuExports:JSExport {
	@objc func addItem(_ newItem: NSMenuItem)
	@objc func removeItem(_ item: NSMenuItem)
}
@objc class BeatPluginControlMenu:NSMenu, BeatPluginControlMenuExports {
	@objc override func addItem(_ newItem: NSMenuItem) {
		super.addItem(newItem)
	}
	@objc override func removeItem(_ item: NSMenuItem) {
		super.removeItem(item)
	}
}

@objc protocol BeatPluginControlMenuItemExports:JSExport {
	@objc var on:Bool { get set }
}

class BeatPluginControlMenuItem:NSMenuItem, BeatPluginControlMenuItemExports {
	
	var method:JSValue
	
	@objc var on:Bool {
		get {
			if self.state == .on { return true } else { return false }
		}
		set {
			if (newValue) { self.state = .on }
			else { self.state = .off }
		}
	}
	
	@objc init(title:String, shortcut:[String], method: JSValue) {
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
	
	@objc func validateState() {
		if self.on {
			self.state = .on
		} else {
			self.state = .off
		}
	}
	
	@objc func runMethod() {
		self.method.call(withArguments: [])
	}
	
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	
	
}
