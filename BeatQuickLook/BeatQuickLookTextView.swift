//
//  BeatQuickLookTextView.swift
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 11.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

public class BeatQuickLookTextView:NSTextView {
	var scaleFactor = 0.0
	
	override public func resize(withOldSuperviewSize oldSize: NSSize) {
		
		if let superview = self.superview, let width = self.textContainer?.size.width {
			let superWidth = (superview.frame.size.width < width) ? superview.frame.size.width : (width + 10.0)
			let scale = superWidth / width
			
			// Let's first restore the size
			if (scaleFactor > 0.0) {
				scaleUnitSquare(to: NSMakeSize(1 / scaleFactor, 1  / scaleFactor))
			}
			
			// Then scale and store the previous scale factor
			scaleUnitSquare(to: NSMakeSize(scale, scale))
			scaleFactor = scale
			
			// Then calculate insets to center the content
			// Left/right insets
			let width = (superview.frame.size.width / 2.0 - width * scaleFactor / 2.0) / (1.0 / scaleFactor)
			
			self.textContainerInset = NSMakeSize(width, 10.0);
		}
		
		super.resize(withOldSuperviewSize: oldSize)
	}
}
