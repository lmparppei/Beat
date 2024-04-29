//
//  BeatColorLabelView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 29.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa
import BeatCore

class BeatColorLabelView: NSImageView {
	
	@IBInspectable @objc public var colorName:String = ""
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.image = BeatColors.labelImage(forColor: colorName, size: CGSizeMake(self.frame.height, self.frame.height))
	}

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
