//
//  BeatPageTextView.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 8.8.2025.
//

import UXKit

// MARK: - Custom text view for rendered pages.

/// This is by all means a simple NS/UITextView, but on macOS it handles clicks to custom hyperlinks and esc presses. On iOS, we need to draw the view differently based on the drawing target to avoid rasterization.
@objc open class BeatPageTextView:UXTextView {
	weak var previewController:BeatPreviewManager?
    
#if os(macOS)
	/// The user clicked on a link, which direct to `Line` objects
	override public func clicked(onLink link: Any, at charIndex: Int) {
		guard
			let line = link as? Line,
			let previewController = self.previewController
		else { return }
		
		previewController.closeAndJumpToRange(line.textRange())
	}
	
	override public func cancelOperation(_ sender: Any?) {
		superview?.cancelOperation(sender)
	}
#else
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        let isPDF = !UIGraphicsGetPDFContextBounds().isEmpty

        if !self.layer.shouldRasterize && isPDF {
            self.draw(self.bounds)
        } else {
            super.draw(layer, in: ctx)
        }
    }
#endif
}
