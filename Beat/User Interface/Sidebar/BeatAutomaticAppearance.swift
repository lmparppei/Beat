//
//  BeatAutomaticAppearance.swift
//  Beat Ad Hoc
//
//  Created by Lauri-Matti Parppei on 18.1.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatAutomaticAppearanceView:NSView {
	@IBInspectable var themePropertyToFollow:String = "outlineBackground"
	
	// This is a flag for older macOS versions
	@objc var appearAsDark:Bool {
		let delegate = NSApplication.shared.delegate as? BeatAppDelegate
		let dark = delegate?.isDark() ?? false

		guard let bgColor = (dark) ? ThemeManager.shared().outlineBackground().darkAquaColor : ThemeManager.shared().outlineBackground().aquaColor
		else { return true }
		
		// Calculate perceived luminance
		let luminance = (0.2126 * bgColor.redComponent + 0.7152 * bgColor.greenComponent + 0.0722 * bgColor.blueComponent)
		if (luminance < 0.3) {
			if #available(macOS 10.14, *) {
				self.appearance = NSAppearance(named: .darkAqua)
			}
			return true
		} else {
			self.appearance = NSAppearance(named: .aqua)
			return false
		}
	}
	
	override func viewWillDraw() {
		_ = self.appearAsDark
		super.viewWillDraw()
	}
	
}
