//
//  NSView+Visibility.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

@objc public extension NSView {
	
	@objc var drawnOnScreen:Bool {
		var drawn = false
		if let layer = self.layer, let window = self.window, let contentLayer = window.contentView?.layer {
			drawn = self.layer?.presentation() != nil
		}
		return drawn
	}
	
}

