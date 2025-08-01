//
//  NSView+Appearance.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

@objc extension NSView {

	/// Set and/or get automatic appearance
	@objc static func shouldAppearAsDark(backgroundColor:NSColor, view:NSView, apply:Bool = true) -> Bool {
		// Calculate perceived luminance
		var red:CGFloat = 0.0, green:CGFloat = 0.0, blue:CGFloat = 0.0
		backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
		
		let luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue)
		let dark = (luminance < 0.35)
		
		if apply {
			//view.overrideUserInterfaceStyle = (dark) ? .dark : .light
			if #available(macOS 10.14, *) {
				view.appearance = (dark) ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
			}
		}
		
		return dark
	}
}
