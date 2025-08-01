//
//  BeatAutomaticAppearance.swift
//  Beat Ad Hoc
//
//  Created by Lauri-Matti Parppei on 18.1.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 It's been a while since I wrote this class, but IIRC, you can use this to create an `NSView` which automatically sets the appearance based on *how* dark its background value is.
 This exists to support custom colors in sidebar. If you set a light enough background color, dark UI elements will be far to dark and vice versa.
 The `IBInspectable` value doesn't seem to be used, but that could be fixed for future use.
 
 The code even supports macOS Mojave.
 
 */

import AppKit

class BeatAutomaticAppearanceView:NSView {
	@IBInspectable var themePropertyToFollow:String = "outlineBackground"
	
	@objc var appearAsDark:Bool {
		let delegate = NSApplication.shared.delegate as? BeatAppDelegate
		let dark = delegate?.isDark() ?? false

		guard let bgColor = (dark) ? ThemeManager.shared().outlineBackground.darkColor : ThemeManager.shared().outlineBackground.lightColor
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
