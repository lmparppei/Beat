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
			// OK, so, I'm *very* bad with NSScrollView and everything seems pretty weird.
			// I'm circumventing those issues with this spaghetti code.
			
			guard let documentView = self.documentView,
				  let clipView = self.contentView as? CenteringClipView
			else { return }

			// Get desired page size for current page size and magnify to fit
			let pageFrame = BeatPaperSizing.size(for: self.editorDelegate?.pageSize ?? .A4)
			self.magnify(toFit: NSMakeRect(0, 0, pageFrame.width, self.frame.size.height))
			
			// Set document view size and the center the clip view again
			documentView.frame.size.width = pageFrame.width * (1 / self.magnification)
			clipView.setBoundsOrigin(clipView.bounds.origin)
		}
	}
	
}

