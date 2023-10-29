//
//  BeatThemeColorWell.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 27.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa
import BeatThemes
import BeatDynamicColor

@objc class BeatThemeColorWell:NSColorWell {
	@IBInspectable var themeKey:String = ""
	@IBInspectable var darkColor:Bool = false
	@IBInspectable var commonColor:Bool = false
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		NotificationCenter.default.addObserver(self, selector: #selector(resetColor), name: Notification.Name(rawValue: "Reset theme"), object: nil)
		
		resetColor()
	}
	
	@objc func resetColor() {
		guard let color = ThemeManager.shared().value(forKey: self.themeKey) as? DynamicColor else {
			print("Error in Theme Editor: Color not found -", themeKey)
			return
		}
		
		self.color = (self.darkColor) ? (color.darkColor ?? color.lightColor) : color.lightColor
	}
}
