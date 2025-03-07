//
//  BeatMenuItemWithFloat.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 31.10.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

@objc class BeatRevisionMenuItem:NSMenuItem {
	var handler:((_ menuItem:BeatRevisionMenuItem) -> Void)?
	var generation:Int = 0
	
	class func revisionItems(currentGeneration:Int, handler: @escaping (_ menuItem:BeatRevisionMenuItem) -> Void) -> [NSMenuItem] {
		var items:[NSMenuItem] = []
		
		for generation in BeatRevisions.revisionGenerations() {
			let title = BeatLocalization.localizedString(forKey: "revision." + String(generation.level + 1))
			let item = BeatRevisionMenuItem(title: title, action: #selector(handle), keyEquivalent: "")
			
			if generation.level == currentGeneration { item.state = .on }
			
			item.generation = generation.level
			item.handler = handler
			item.target = item
			item.image = BeatColors.labelImage(forColor: generation.color, size: CGSizeMake(18.0, 18.0))
			
			items.append(item)
		}
		
		return items
	}
	
	@objc func handle() {
		handler?(self)
	}
}

