//
//  UIView+Appearance.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

@objc extension UIView {

	/// Set and/or get automatic appearance
	@objc static func shouldAppearAsDark(view:UIView, apply:Bool = true) -> Bool {
		guard let bgColor = ThemeManager.shared().outlineBackground
		else { return true }
		
		// Calculate perceived luminance
		var red:CGFloat = 0.0, green:CGFloat = 0.0, blue:CGFloat = 0.0
		bgColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
		
		let luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue)
		let dark = (luminance < 0.35)
		
		if apply {
			view.overrideUserInterfaceStyle = (dark) ? .dark : .light
		}
		
		return dark
	}
	
	@objc func getViewController() -> UIViewController? {
		var responder:UIResponder? = self.next
		while responder != nil {
			if responder!.isKind(of: UIViewController.self) {
				return responder as? UIViewController
			}
			responder = responder?.next
		}
		
		return nil
	}
}
