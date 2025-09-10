//
//  BeatPluginMenuItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class manages plugin menus on macOS
 
 */

import Cocoa

class BeatPluginMenuManager:NSObject, NSMenuDelegate {
	@IBOutlet var pluginMenu:NSMenu?
	@IBOutlet var exportMenu:NSMenu?
	@IBOutlet var importMenu:NSMenu?
	
	@objc func setup() {
		// Populate plugin menus at load (we have to do this so custom shortcuts work)
		if (pluginMenu != nil) {
			setupPluginMenu(pluginMenu!)
			pluginMenu?.delegate = self
		}
		if (exportMenu != nil) {
			setupPluginMenu(exportMenu!)
			exportMenu?.delegate = self
		}
		if (importMenu != nil) {
			setupPluginMenu(importMenu!)
			importMenu?.delegate = self
		}
		
		BeatPluginManager.shared().checkForUpdates()
	}
	
	func menuForType(_ type:BeatPluginType) -> NSMenu? {
		switch type {
		case .ToolPlugin:
			return self.pluginMenu
		case .ImportPlugin:
			return self.importMenu
		case .ExportPlugin:
			return self.exportMenu
		case .InternalPlugin:
			return nil
		case .StylePlugin:
			return nil
		default:
			return self.pluginMenu
		}
	}
	
	func menuWillOpen(_ menu: NSMenu) {
		self.setupPluginMenu(menu)
	}
	
	func menuDidClose(_ menu: NSMenu) {
		//self.clearMenu(menu)
	}
	
	@objc func setupPluginMenu(_ menu:NSMenu) {
		var type:BeatPluginType = .ToolPlugin
		
		if menu == self.exportMenu {
			type = .ExportPlugin
		} else if menu == self.importMenu {
			type = .ImportPlugin
		}
		
		let doc:Document? = NSDocumentController.shared.currentDocument as? Document
		let runningPlugins:[String:BeatPlugin] = doc?.runningPlugins as? [String:BeatPlugin] ?? [:]
		
		self.pluginMenuItems(for: menu, runningPlugins: runningPlugins, type:type)
	}
	
	@objc func clearMenu(_ menu:NSMenu) {
		let menuItems = Array(menu.items)
		for item in menuItems {
			// Don't remove menu items for internal plugins
			if let pluginItem = item as? BeatPluginMenuItem, !pluginItem.internalPlugin {
				menu.removeItem(item)
			}
		}
	}
	
	func pluginMenuItems(for parentMenu:NSMenu, runningPlugins:[String:BeatPlugin], type:BeatPluginType) {
		self.clearMenu(parentMenu)
		
		// Reload existing plugins when the menu opens
		let pluginManager = BeatPluginManager.shared()
		pluginManager.loadPlugins()
		
		let disabledPlugins = pluginManager.disabledPlugins()
		
		for plugin in pluginManager.allActivePlugins() {
			if menuForType(plugin.type) != parentMenu || plugin.type == .InternalPlugin || plugin.type == .StylePlugin || disabledPlugins.contains(plugin.name) {
				continue
			}
			
			var displayName = String(plugin.name)
			
			if plugin.type == .ExportPlugin, let _ = displayName.range(of: "Export") {
				displayName = String(format: "%@ %@...", BeatLocalization.localizedString(forKey: "export.prefix"), displayName.replacingOccurrences(of: "Export ", with: ""))
			}
			else if plugin.type == .ImportPlugin, let _ = displayName.range(of: "Import") {
				displayName = String(format: "%@ %@...", BeatLocalization.localizedString(forKey: "import.prefix"), displayName.replacingOccurrences(of: "Import ", with: ""))
			}
			
			let item = BeatPluginMenuItem(title: displayName, pluginName: plugin.name, type: plugin.type)
			item.state = .off
			
			// Set correct target for standalone plugins
			if plugin.type == .ImportPlugin || plugin.type == .ExportPlugin || plugin.type == .StandalonePlugin {
				item.target = BeatPluginManager.shared()
				item.action = #selector(runStandalonePlugin)
			} else {
				item.target = nil
				item.action = #selector(runPlugin)
			}
			
			// See if the plugin is currently running
			item.state = (runningPlugins[displayName] != nil) ? .on : .off
			
			// Add to the parent menu
			parentMenu.addItem(item)
		}
	}
	
	@objc func runPlugin(_ plugin:AnyObject) {
		/// Faux `runPlugin` method. The actual method will be available in first responder document.
	}
	@objc func runStandalonePlugin(_ plugin:AnyObject) {
		/// Faux `runPlugin` method. The actual method will be available in plugin manager.
	}
	
}

class BeatPluginMenuItem:NSMenuItem {
	@IBInspectable @objc var pluginName:String = ""
	@IBInspectable @objc var internalPlugin:Bool = false
	
	var type:BeatPluginType = BeatPluginType.ToolPlugin
	
	@objc convenience init(title string: String, pluginName:String, type:BeatPluginType) {
		self.init(title: string, action: nil, keyEquivalent: "")
		self.pluginName = pluginName
		self.type = type
	}
}
