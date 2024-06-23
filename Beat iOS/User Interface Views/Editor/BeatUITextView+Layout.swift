//
//  BeatUITextView+Layout.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 19.6.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatUITextView {
	
	// MARK: - Resize scroll view and text view
	/**
	 
	 To achieve the "page-like" view, we need to do some trickery.
	 
	 Instead of using the built-in scroll view of `UITextView`, we're wrapping `UITextView` inside an `NSView` placed inside a `UIScrollView`.
	 Whenever the text view content changes, we'll need to resize the wrapping view and content size of the enclosing scroll view.
	 
	 */
		
	/// Called when setting up the view and adjusting paper size
	@objc func resizePaper() {
		var frame = pageView.frame
		frame.origin.x = 0.0
		frame.origin.y = 0.0
		frame.size.height = textContainer.size.height
		frame.size.width = self.documentWidth + textContainerInset.left + textContainerInset.right + BeatUITextView.linePadding()
		
		pageView.frame = frame
		
		let containerHeight = textContainer.size.height + textContainerInset.top + textContainerInset.bottom
		self.textContainer.size = CGSize(width: self.documentWidth, height: containerHeight)
		self.textContainerInset = insets
	}
	
	/// Used to reliably resize the text view to fit content
	@objc func resize() {
		// We'll ignore this method on phones
		guard !mobileMode else {
			mobileViewResize()
			return
		}

		guard let enclosingScrollView = self.enclosingScrollView else {
			print("WARNING: No scroll view set for text view")
			return
		}
		
		// Resize content view size in scroll view. This value has to be set before any of the following calculations.
		resizeScrollViewContent()
		
		var frame = pageView.frame
		var zoom = enclosingScrollView.zoomScale
		
		// Make sure the page view height is at least the height of the screen
		if (frame.height * zoom < enclosingScrollView.frame.height) {
			var targetHeight = frame.height
			if (self.frame.height < enclosingScrollView.frame.height) {
				targetHeight = enclosingScrollView.frame.height
			}
			let factor = targetHeight / enclosingScrollView.frame.height
			zoom = enclosingScrollView.zoomScale / factor
		}
		
		// Center the page view
		let x = (enclosingScrollView.frame.width - pageView.frame.width) / 2
		frame.origin.x = max(x, 0.0)
		
		// Calculate page view size
		let width = floor(self.documentWidth + self.insets.left + self.insets.right)
		let height = floor(self.pageView.frame.size.height)

		// Page view size is scaled
		frame.size.width = zoom * width
		frame.size.height = enclosingScrollView.contentSize.height
						
		// And now, welcome to fun with floating points.
		// iOS frame sizes tend to be off by ~0.000001, so we'll have to round everything to ensure we're not doing anything unnecessary.
		if preciseRound(frame.origin.x, precision: .tenths) != preciseRound(pageView.frame.origin.x, precision: .tenths) { pageView.frame.origin.x = frame.origin.x }
		if preciseRound(frame.width, precision: .tenths) != preciseRound(pageView.frame.width, precision: .tenths) { pageView.frame.size.width = frame.width }
//		if preciseRound(frame.height, precision: .tenths) != preciseRound(pageView.frame.height, precision: .tenths) { pageView.frame.size.height = frame.height }

		// Check if we should resize text view frame or not.
		// Note that the self here is important (don't get confused with page view frame)
		if floor(self.frame.origin.x) != 0.0 { self.frame.origin.x = 0.0 }
		if width != floor(self.frame.width) { self.frame.size.width = width }
		if height != floor(self.frame.height) { self.frame.size.height = height }
	}
	
	@objc func firstResize() {
		if (self.mobileMode) {
			updateMobileScale()
			return
		}
		
		let newSize = sizeThatFits(CGSize(width: self.documentWidth, height: CGFloat.greatestFiniteMagnitude))
		let inset = self.textContainerInset
		
		self.frame.size = newSize
		self.enclosingScrollView.contentSize = CGSize(width: contentSize.width + inset.left + inset.right, height: contentSize.height + inset.top + inset.bottom)
		
		// Calculate initial page view size
		let width = floor(self.documentWidth + self.insets.left + self.insets.right)
		let zoom = enclosingScrollView.zoomScale
		self.pageView.frame.origin.x = 0.0
		self.pageView.frame.size.width = width * zoom
	}
	
	@objc func resizeScrollViewContent() {
		let layoutManager = self.layoutManager
		let inset = self.textContainerInset
		
		// Calculate the index of the last glyph that fits within the available height
		var lastGlyphIndex = layoutManager.numberOfGlyphs - 1
		if (lastGlyphIndex < 0) { lastGlyphIndex = 0 }
	

		// Get the rectangle of the line fragment that contains the last glyph
		var lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
		
		var lastLineY = lastLineRect.maxY
		if lastLineRect.origin.y <= 0.0 {
			lastLineRect = layoutManager.extraLineFragmentRect
			lastLineY = abs(lastLineRect.maxY)
		}
		
		let factor = self.enclosingScrollView.zoomScale
		let contentSize = CGSize(width: self.documentWidth, height: lastLineY)
		
		var scrollSize = CGSize(width: (contentSize.width + inset.left + inset.right) * factor,
								height: (contentSize.height + inset.top + inset.bottom) * factor)

		if scrollSize.height * factor < self.enclosingScrollView.frame.height {
			scrollSize.height = self.enclosingScrollView.frame.height - ((inset.top - inset.bottom) * factor)
		}
		
		let heightNow = self.enclosingScrollView.contentSize.height
		
		// Adjust the size to fit, if the size differs more than 5.0 points
		if (scrollSize.height < heightNow - 5.0 || scrollSize.height > heightNow + 5.0) {
			scrollSize.height += 12.0
			self.enclosingScrollView.contentSize = scrollSize
		}	
	}

	
	// MARK: - Mobile sizing
	
	var mobileScale:CGFloat {
		let scale = BeatUserDefaults.shared().getInteger(BeatSettingPhoneFontSize)
		return 1.1 + CGFloat(scale) * 0.15
		
	}
	
	@objc public func updateMobileScale() {
		self.zoomScale = mobileScale
	}
	
	func mobileViewResize() {
		let documentWidth = self.documentWidth
		self.textContainer.size.width = documentWidth
		
		let factor = 1 / self.zoomScale
		let scaledFrame = self.frame.width * factor
		
		var insets = self.insets
		
		if (documentWidth < scaledFrame) {
			insets.left = ((self.frame.size.width - documentWidth - BeatUITextView.linePadding() * 2) / 2) * factor
		}
		
		self.textContainerInset = insets
	}
	
}
