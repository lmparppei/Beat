//
//  BeatOutlineStackView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.1.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

fileprivate var previousHeight = 0.0

class BeatOutlineStackView:NSStackView {
	@IBOutlet weak var outlineCell:BeatOutlineViewCell?
		
	override var fittingSize: NSSize {
		let size = super.fittingSize
		return size
	}
	
	override var intrinsicContentSize: NSSize {
		var size = super.intrinsicContentSize
		
		if BeatUserDefaults.shared().getBool(BeatSettingRelativeOutlineHeights) {
			//self.layoutSubtreeIfNeeded()
			if let cell = outlineCell, let scene = cell.scene {
				let sizeModifier = BeatUserDefaults.shared().getFloat(BeatSettingOutlineFontSizeModifier) * 0.1 + 1
				let modifier = 90.0 * sizeModifier

				if let pages = cell.outlineView?.editorDelegate.pagination().numberOfPages, pages > 0 {
					// Calculate the relative size of the scene
					let relativeHeight = modifier * scene.printedLength
										
					if relativeHeight > size.height {
						size.height = relativeHeight
					}
					
					previousHeight = size.height
					return size
				}
			}
		}
		
		return size
	}
}
