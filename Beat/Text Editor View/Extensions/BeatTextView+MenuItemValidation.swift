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
		// Nothing here anymore. I have moved all text-view related checks to validateMenuItem.
	}
	
	open override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if let item = menuItem as? BeatOnOffMenuItem {
			return item.setChecked(document: self.editorDelegate)
		} else if menuItem.action == #selector(toggleFocusMode) {
			return self.validateFocusMode(menuItem)
		} else if menuItem.action == #selector(toggleLineNumbers) {
			menuItem.state = (self.enclosingScrollView?.rulersVisible ?? false) ? .on : .off
		}
		
		return super.validateMenuItem(menuItem)
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
