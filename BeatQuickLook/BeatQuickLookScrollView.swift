//
//  BeatQuickLookScrollView.swift
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 27.5.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 This scales the contents according to width.
 
 */

import AppKit
import BeatCore

final class BeatQuickLookScrollView:CenteringScrollView {
	@IBOutlet weak var editorDelegate:BeatQuickLookDelegate?
	
	override var frame: NSRect {
		didSet {
			let pageFrame = BeatPaperSizing.size(for: self.editorDelegate?.pageSize ?? .A4)
			let factor =  1 / (pageFrame.width / self.frame.width)
			
			self.magnification = factor
		}
	}
}

