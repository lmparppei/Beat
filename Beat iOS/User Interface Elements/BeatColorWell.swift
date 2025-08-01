//
//  BeatColorWell.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 8.4.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

class BeatColorWell:UIColorWell {
	
	@IBInspectable var themeKey:String = ""
	@IBInspectable var lineType:String?
	
	var colorChangeWorkItem: DispatchWorkItem?
		
	override func awakeFromNib() {
		super.awakeFromNib()
						
		resetColor()
		self.addTarget(self, action: #selector(colorDidChange), for: .valueChanged)
	}
	
	@objc func colorDidChange() {
		// We need to throttle the color changes a little
		let item = DispatchWorkItem { [weak self] in
			self?.saveColor()
		}
		
		colorChangeWorkItem?.cancel()
		colorChangeWorkItem = item
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
	}
	
	func saveColor() {
		guard let color = selectedColor, let themeColor = ThemeManager.shared().value(forKey: themeKey) as? DynamicColor else {
			print("Theme Editor: Color not found:", themeKey)
			return
		}
		
		themeColor.lightColor = color
		themeColor.darkColor = color
		
		ThemeManager.shared().saveTheme()
		NotificationCenter.default.post(name: NSNotification.Name("Theme color changed"), object: nil, userInfo: ["sender": self])
	}
	
	@objc func resetColor() {
		guard let color = ThemeManager.shared().value(forKey: self.themeKey) as? DynamicColor else {
			print("Error in Theme Editor: Color not found -", themeKey)
			return
		}
	
		self.selectedColor = color
	}
	
}
