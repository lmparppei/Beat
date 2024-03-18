//
//  BeatTimelineController.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 19.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//
//  Modern implementation of the timeline

import AppKit

class BeatTimelineController:NSView, BeatTimelineObjectDelegate {
	@IBOutlet weak var delegate:BeatEditorDelegate?
	
	var items:[BeatTimelineObject] = []
	var selectedItems:[BeatTimelineObject] = []
	
	func contextMenu(for: BeatTimelineObject) {
		//
	}
	
	func deselect(_ items:[BeatTimelineObject]? = nil) {
		if (items == nil) {
			selectedItems = []
		} else {
			items?.forEach {
				selectedItems.removeObject(object: $0)
			}
		}
	}
	
	func selectRange(_ range:NSRange) {
		
	}
	
	func didClick(item:BeatTimelineObject) {
		// 
	}
	
}

protocol BeatTimelineObjectDelegate {
	func contextMenu(for:BeatTimelineObject)
	//&func select(_ item:BeatTimelineObject)
}

class BeatTimelineObject:NSView {
	var selected = false
}
