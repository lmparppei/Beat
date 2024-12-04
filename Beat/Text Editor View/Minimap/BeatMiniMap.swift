//
//  BeatMiniMap.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class MinimapLayoutManager: NSLayoutManager {
	var scaleFactor: CGFloat = 0.3
	var blockHeight: CGFloat = 4.0

	// Determines if a line is important (e.g., non-empty or special content)
	private func isImportantLine(_ lineText: String) -> Bool {
		return false
	}

	// Instead of drawing actual glyphs, we'll draw small rectangles.
	override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
		/*
		guard let textStorage = self.textStorage else { return }
		
		// Compute the width of a single rectangle representing one character in the original text display.
		let width:CGFloat = 2.0
		
		// Ignored types
		let ignoredProps:[NSLayoutManager.GlyphProperty] = [.null, .controlCharacter, .elastic]
		
		// Enumerate line fragments and draw the rect glyphs
		enumerateLineFragments(forGlyphRange: glyphsToShow) { (_rect, usedRect, _textContainer, glyphRange, _) in
			let origin = usedRect.origin
						
			for index in 0..<glyphRange.length {
				
				// Don't draw hidden glyphs or control characters
				let property = self.propertyForGlyph(at: glyphRange.location + index)
				let scaleFactor = self.scaleFactor
				
				let charIndex = self.characterIndexForGlyph(at: glyphRange.location + index)
				if textStorage.string[textStorage.string.index(textStorage.string.startIndex, offsetBy: charIndex)] == " " {
					continue
				}
				if ignoredProps.contains(property) { continue }

				if let color = textStorage.attribute(.foregroundColor, at: charIndex, effectiveRange: nil) as? NSColor {
					color.withAlphaComponent(0.30).setFill()
				}
				
				let rectRepresentation = CGRect(x: origin.x  * scaleFactor + (CGFloat(index) * (self.blockHeight / 2)),
												y: origin.y * scaleFactor,
												width: self.blockHeight / 2,
												height: self.blockHeight)
				
				// Draw the fragment
				NSBezierPath(rect: rectRepresentation).fill()
			}
		}
		 */
	}
}

class MinimapTextView: NSTextView, NSLayoutManagerDelegate {
	var scaleFactor: CGFloat = 0.1

	@objc init(textStorage: NSTextStorage, scrollView:NSScrollView, connectedScrollView:NSScrollView) {
		let textContainer = NSTextContainer(containerSize: CGSizeMake(connectedScrollView.frame.size.width, CGFLOAT_MAX));
		let layoutManager = MinimapLayoutManager()

		super.init(frame: .zero, textContainer: textContainer)

		textContainer.widthTracksTextView = false
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		
		layoutManager.delegate = self

		self.isEditable = false
		self.isSelectable = false
		self.scaleFactor = layoutManager.scaleFactor
		self.font = NSFont.systemFont(ofSize: 4.0)
		
		self.isVerticallyResizable = true
		self.autoresizingMask = [.width, .height]
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
/*
	override func draw(_ dirtyRect: NSRect) {
		// Draw only the visible range of the minimap for performance
		if let layoutManager {
			let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: dirtyRect, in: textContainer!)
			layoutManager.drawGlyphs(forGlyphRange: visibleGlyphRange, at: .zero)
		}
	}
 */

	override var isFlipped: Bool {
		return true
	}
	
	func layoutManager(_ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>, lineFragmentUsedRect: UnsafeMutablePointer<NSRect>, baselineOffset: UnsafeMutablePointer<CGFloat>, in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
		lineFragmentRect.pointee.size.height += 2
		return true
	}
	
	func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: NSFont, forGlyphRange glyphRange: NSRange) -> Int {
		
		let loc = glyphRange.location
		let len = layoutManager.characterIndexForGlyph(at: NSMaxRange(glyphRange)) - loc

		//let str:CFString = (self.textStorage?.string.substring(range: NSMakeRange(loc, len)) ?? "") as CFString
		//let modifiedStr = CFStringCreateMutable(nil, CFStringGetLength(str))
		
		//CFStringFindAndReplace(modifiedStr, CFSTR(" "), CFSTR("•"), CFRangeMake(0, CFStringGetLength(modifiedStr)), 0);
		
		return 0
	}
}
