//
//  ZoomingTextView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.4.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

import Cocoa

class ZoomingTextView : NSTextView {
	
	/// 100% 1x1 unit scaling:
	let unitSize: NSSize = NSSize(width: 1.0, height: 1.0)
	
	/// The last scaling factor that this textview experienced
	private(set) var oldScaleFactor: Double = 1.0
	
	/// The current zoom factor
	private(set) var zoomFactor: Double = 1.0
	
	/// Zooms to the specified scaling factor.
	/// - Parameter factor: The scaling factor. 1.0 = 100%
	func zoomTo(factor: Double) {
		var scaleFactor = factor
		
		// No negative values:
		if scaleFactor < 0 {
			scaleFactor = abs(scaleFactor)
		}
		
		// No 0 value allowed!
		if scaleFactor == 0.0 {
			scaleFactor = 1.0
		}
		
		// Don't repeatedly zoom in on 100%
		// Prevents glitches
		if (scaleFactor < 1.01 && scaleFactor > 0.99) {
			// we'll only reach here if scale factor is about 1.0
			if (oldScaleFactor < 1.01 && oldScaleFactor > 0.99) {
				// print("old and new scale factor are 1.0")
				// For some reason, if we try to set the zoom to 100% when the zoom is
				// already 100%, everything disappears. This prevents that from
				// happening.
				return
			}
		}
		
		// Don't do redundant scaling:
		if scaleFactor == oldScaleFactor {
			// We've already scaled.
			return
		}
		
		
		// Reset the zoom before re-zooming
		scaleUnitSquare(to: convert(unitSize, from: nil))
		
		// Perform the zoom on the text view:
		scaleUnitSquare(to: NSSize(width: scaleFactor, height: scaleFactor))
		
		
		// Handle the details:
		let tc = textContainer!
		let lm = layoutManager!
		
		// To make word-wrapping update:
		let scrollContentSize = enclosingScrollView!.contentSize
		
		// Necessary for word wrap
		frame = CGRect(x:0, y:0, width: scrollContentSize.width, height: 0.0)
		
		tc.containerSize = NSMakeSize(scrollContentSize.width, CGFloat.greatestFiniteMagnitude)
		tc.widthTracksTextView = true
		lm.ensureLayout(for: tc)
		
		// Scroll to the cursor! Makes zooming super nice :)
		alternativeScrollToCursor()
		
		needsDisplay = true
		
		zoomFactor = scaleFactor
		
		// Keep track of the old scale factor:
		oldScaleFactor = scaleFactor
	}
	
	/// Forces the textview to scroll to the current cursor/caret position.
	func alternativeScrollToCursor() {
		if let cursorPosition: NSInteger = selectedRanges.first?.rangeValue.location {
			scrollRangeToVisible(NSRange(location: cursorPosition, length: 0))
		}
	}
}
