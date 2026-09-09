//
//  BeatToolbarView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatThemes

class BeatToolbarView:NSView {
	
	var leftBackground = CALayer()
	var rightBackground = CALayer()
	
	@IBOutlet weak var excludedView:NSView?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.layer?.addSublayer(leftBackground)
		self.layer?.addSublayer(rightBackground)
	}
		
	override func layout() {
		super.layout()
		updateBackgrounds()
	}
	
	func updateBackgrounds() {
		let padding = 5.0
		let yPadding = 3.0
		
		var leftWidth = 0.0
		var leftX = self.frame.size.width
		
		var rightX = self.frame.size.width
		var rightWidth = 0.0
		
		var height = 0.0
		var y = 0.0
		
		for view in self.subviews.filter({ type(of: $0) is NSButton.Type }) {
			if view == excludedView { continue }
			
			if view.frame.origin.x < self.frame.width / 2 {
				leftX = min(leftX, view.frame.origin.x)
				leftWidth = max(leftWidth, view.frame.maxX - leftX)
				
				y = max(y, view.frame.minY)
				height = max(height, view.frame.height)
			} else {
				rightX = min(rightX, view.frame.minX)
				rightWidth = max(rightWidth, view.frame.maxX)
			}
		}
		
		y = (self.frame.size.height - (height + yPadding * 2)) / 2
		height = height + yPadding * 2
	
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		
		leftBackground.frame = CGRect(x: leftX - padding, y: y, width: leftWidth + padding * 2, height: height)
		rightBackground.frame = CGRect(x: rightX - padding, y: y, width: rightWidth - rightX + padding * 2, height: height)
		
		leftBackground.cornerRadius = 8
		rightBackground.cornerRadius = 8
		
		leftBackground.backgroundColor = ThemeManager.shared().marginColor.withAlphaComponent(0.5).cgColor
		rightBackground.backgroundColor = ThemeManager.shared().marginColor.withAlphaComponent(0.5).cgColor
		
		CATransaction.commit()
	}
}
