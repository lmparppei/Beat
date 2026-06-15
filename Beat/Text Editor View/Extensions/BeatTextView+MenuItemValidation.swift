//
//  BeatTextView+MenuItemValidation.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension BeatTextView:NSMenuDelegate {
	
	/// Sets up automatically validated items. These items check a value in another object and toggle themselves on/off based on that.
	@objc func setupValidationItems() {
		self.validatedMenuItems = [
			BeatValidationItem(
				action: #selector(toggleTypewriterMode),
				setting: BeatSettingTypewriterMode,
				target: BeatUserDefaults.shared()
			)
		]
	}
	
	func validate(_ menuItem: NSMenuItem) -> Bool {
		for item in validatedMenuItems where item.selector == menuItem.action {
			return item.validate()
		}
		
		return true
	}
	
	open override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
		// Remove context menu for layout orientation change
		if (item.action == #selector(changeLayoutOrientation)) {
			return false
		}
		return super.validateUserInterfaceItem(item)
	}
	
	public func menuWillOpen(_ menu: NSMenu) {
		if let versionMenu = menu as? BeatLineVersionMenu, let currentLine = self.editorDelegate.currentLine {
			versionMenu.populate(with: currentLine, editorDelegate: self.editorDelegate)
		}
	}
}
/**
 
 
 
 */
