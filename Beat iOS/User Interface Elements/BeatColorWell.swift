//
//  BeatColorWell.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 8.4.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

class BeatColorWell:UIColorWell {
	
	@IBInspectable var themeKey:String = ""
	@IBInspectable var darkColor:Bool = false
	@IBInspectable var commonColor:Bool = false
	@IBInspectable var lineType:String?
	
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
	
		self.selectedColor = (self.darkColor) ? (color.darkColor ?? color.lightColor) : color.lightColor
	}
	
}
