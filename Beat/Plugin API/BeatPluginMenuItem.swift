//
//  BeatPluginMenuItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatPluginMenuItem:NSMenuItem {
	@objc var pluginName:String = ""

	var type:BeatPluginType = BeatPluginType.ToolPlugin
	
	@objc convenience init(title string: String, pluginName:String, type:BeatPluginType) {
		self.init(title: string, action: nil, keyEquivalent: "")
		self.pluginName = pluginName
		self.type = type
	}
}
