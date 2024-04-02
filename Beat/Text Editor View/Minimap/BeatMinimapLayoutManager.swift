//
//  BeatMinimapLayoutManager.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

class BeatMinimapLayoutManager:NSLayoutManager {
	// When using non-contiguous layout, we might need to run an action after layout operations have finished.
	var postLayoutAction: (() -> ())?
	weak var editorDelegate:BeatEditorDelegate?
	
	class func minimapFontSize() -> CGFloat {
		return 2.0;
	}
		
	override func usedRect(for container: NSTextContainer) -> CGRect {
		let usedRect = super.usedRect(for: container)
		return CGRect(origin: .zero, size: CGSize(width: usedRect.maxX, height: usedRect.height))
	}
	
	/// Add an action to be executed when layout finished.
	private func addPostLayout(action: @escaping () -> ()) {
		let oldPostLayoutAction = postLayoutAction
		
		// Create a queue of actions by nesting closures.
		postLayoutAction = {
			oldPostLayoutAction?();
			action()
		}
	}
	
	/// Execute the given action when layout is complete. That may be right away or waiting for layout to complete.
	///
	/// - Parameter action: The action that should be done if and when layout is complete.
	///
	func onLayoutFinished(action: @escaping () -> ()) {
		if hasUnlaidCharacters {
			addPostLayout(action: action)
		} else {
			action()
		}
	}
	
	// Instead of drawing actual glyphs, we'll draw small rectangles.
	override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		guard let textStorage = self.textStorage else { return }
		
		// Compute the width of a single rectangle representing one character in the original text display.
		let width:CGFloat = BeatMinimapLayoutManager.minimapFontSize() / 2
		
		// Ignored types
		let ignoredProps:[NSLayoutManager.GlyphProperty] = [.null, .controlCharacter]
		
		// Enumerate line fragments and draw the rect glyphs
		enumerateLineFragments(forGlyphRange: glyphsToShow) { (_rect, usedRect, _textContainer, glyphRange, _) in
			let origin = usedRect.origin
			
			for index in 0..<glyphRange.length {
				
				// Don't draw hidden glyphs or control characters
				let property = self.propertyForGlyph(at: glyphRange.location + index)
				
				if ignoredProps.contains(property) { continue }

				let charIndex = self.characterIndexForGlyph(at: glyphRange.location + index)
				if let color = textStorage.attribute(.foregroundColor, at: charIndex, effectiveRange: nil) as? NSColor {
					color.withAlphaComponent(0.30).setFill()
				}
				
				let rectRepresentation = CGRect(x: origin.x + CGFloat(index),
									  y: origin.y,
									  width: width,
									  height: usedRect.size.height)
				
				// Draw the fragment
				NSBezierPath(rect: rectRepresentation).fill()
			}
		}
	}
}

extension NSLayoutManager {
	
	/// Enumerate the fragment rectangles covering the characters located on the line with the given character index.
	/// **NOTE:** This is stolen from CodeEditor. The code has to be converted to rely on Beat's parser.
	///
	/// - Parameters:
	///   - charIndex: The character index determining the line whose rectangles we want to enumerate.
	///   - block: Block that gets invoked once for every fragement rectangles on that line.
	func enumerateFragmentRects(forLineContaining charIndex: Int, using block: @escaping (CGRect) -> Void) {
		guard let text = textStorage?.string as NSString? else { return }
		
		let currentLineCharRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
		
		if currentLineCharRange.length > 0 {  // all, but the last line (if it is an empty line)
			let currentLineGlyphRange = glyphRange(forCharacterRange: currentLineCharRange, actualCharacterRange: nil)
			enumerateLineFragments(forGlyphRange: currentLineGlyphRange){ (rect, _, _, _, _) in block(rect) }
		} else {                              // the last line if it is an empty line
			block(extraLineFragmentRect)
		}
	}
	
	/// Returns `true` if the current layout manager has unlaid characters.
	var hasUnlaidCharacters: Bool {
		firstUnlaidCharacterIndex() < (self.textStorage?.length ?? 0)
	}
}

// MARK: - Type setter

class BeatMinimapTypeSetter: NSATSTypesetter {
	
	override func layoutParagraph(at lineFragmentOrigin: UnsafeMutablePointer<NSPoint>) -> Int {
		let padding = currentTextContainer?.lineFragmentPadding ?? 0,
			width   = currentTextContainer?.size.width ?? 100
		
		// Determine the size of the rectangles to layout. (They are always twice as high as wide.)
		let fontHeight = BeatMinimapLayoutManager.minimapFontSize()
		
		let lineHeight = fontHeight + 1		// 1 point gap between lines
		let fontWidth = fontHeight / 2 		// Glyph width is half the height
		
		beginParagraph()
		
		if paragraphGlyphRange.length > 0 {
			// This line is not empty. Enumerate through glyphs and calculate rects for the glyphs.
			var remainingGlyphRange = paragraphGlyphRange
			
			while remainingGlyphRange.length > 0 {
				var lineFragmentRect = NSRect.zero
				var remainingRect = NSRect.zero
				
				beginLine(withGlyphAt: remainingGlyphRange.location)
				
				getLineFragmentRect(&lineFragmentRect,
									usedRect: nil,
									remaining: &remainingRect,
									forStartingGlyphAt: remainingGlyphRange.location,
									proposedRect: NSRect(origin: lineFragmentOrigin.pointee, size: CGSize(width: width, height: lineHeight)),
									lineSpacing: 0,
									paragraphSpacingBefore: 0,
									paragraphSpacingAfter: 0)
				
				let lineFragementRectEffectiveWidth = max(lineFragmentRect.size.width, 0)
				
				// Calculate how many glyphs our line fragment can house
				var numberOfGlyphs:Int
				var lineGlyphRangeLength:Int
				var numberOfGlyphsThatFit = max(Int(floor(lineFragementRectEffectiveWidth / fontWidth)), 1)
				
				// Elastic glyphs can be compacted, so we can safely add them to the range
				let glyphProperty = layoutManager?.propertyForGlyph(at: remainingGlyphRange.location + numberOfGlyphsThatFit)
				while numberOfGlyphsThatFit < remainingGlyphRange.length && glyphProperty == .elastic
				{
					numberOfGlyphsThatFit += 1
				}
				
				// No more glyphs fit, we need to break the paragraph in two
				if numberOfGlyphsThatFit < remainingGlyphRange.length {
					// Loop backwards to find find a break point. If we can't find one, let's just add the max glyphs.
					numberOfGlyphs = numberOfGlyphsThatFit
					
					//
					gLoop: for glyphs in stride(from: numberOfGlyphsThatFit, to: 0, by: -1) {
						var actualGlyphRange = NSRange()
						
						let glyphIndex = remainingGlyphRange.location + glyphs - 1
						let charIndex = characterRange(forGlyphRange: NSRange(location: glyphIndex, length: 1),
													   actualGlyphRange: &actualGlyphRange)
						
						// We'll continue the loop until we are at the boundary.
						if actualGlyphRange.location < glyphIndex { continue }
						
						let glyphProp = layoutManager?.propertyForGlyph(at: glyphIndex)
						if glyphProp == .elastic && shouldBreakLine(byWordBeforeCharacterAt: charIndex.location)
						{
							// We can split the paragraph here
							numberOfGlyphs = glyphs
							break gLoop
						}
					}
					
					lineGlyphRangeLength = numberOfGlyphs
					
				} else {
					// Otherwise we'll just add the glyphs to the paragraph
					numberOfGlyphs = remainingGlyphRange.length
					lineGlyphRangeLength = numberOfGlyphs + paragraphSeparatorGlyphRange.length
				}
				
				let lineFragementUsedRect = NSRect(origin: CGPoint(x: lineFragmentRect.origin.x + padding,
																   y: lineFragmentRect.origin.y),
												   size: CGSize(width: CGFloat(numberOfGlyphs), height: fontHeight))
				
				// The glyph range covered by this line fragement — this may include the paragraph separator glyphs
				let remainingLength = remainingGlyphRange.length - numberOfGlyphs,
					lineGlyphRange  = NSRange(location: remainingGlyphRange.location, length: lineGlyphRangeLength)
				
				// The rest of what remains of this paragraph
				remainingGlyphRange = NSRange(location: remainingGlyphRange.location + numberOfGlyphs, length: remainingLength)
				
				setLineFragmentRect(lineFragmentRect,
									forGlyphRange: lineGlyphRange,
									usedRect: lineFragementUsedRect,
									baselineOffset: 0)
				
				setLocation(NSPoint(x: padding, y: 0),
							withAdvancements: nil, //Array(repeating: 1, count: numberOfGlyphs),
							forStartOfGlyphRange: NSRange(location: lineGlyphRange.location, length: numberOfGlyphs))
				
				// No more glyphs remaining. Let's hide the paragraph separator.
				if remainingGlyphRange.length == 0 {
					setLocation(NSPoint(x: NSMaxX(lineFragementUsedRect), y: 0),
								withAdvancements: nil,
								forStartOfGlyphRange: paragraphSeparatorGlyphRange)
					
					setNotShownAttribute(true, forGlyphRange: paragraphSeparatorGlyphRange)
				}
				
				endLine(withGlyphRange: lineGlyphRange)
				
				// Add current line height to the line fragment origin
				lineFragmentOrigin.pointee.y += lineHeight
			}
		} else {
			// This is an empty line.
			beginLine(withGlyphAt: paragraphSeparatorGlyphRange.location)
			
			var lineFragmentRect = NSRect.zero
			var lineFragementUsedRect = NSRect.zero
			
			getLineFragmentRect(&lineFragmentRect,
								usedRect: &lineFragementUsedRect,
								forParagraphSeparatorGlyphRange: paragraphSeparatorGlyphRange,
								atProposedOrigin: lineFragmentOrigin.pointee)
			
			setLineFragmentRect(lineFragmentRect,
								forGlyphRange: paragraphSeparatorGlyphRange,
								usedRect: lineFragementUsedRect,
								baselineOffset: 0)
			setLocation(NSPoint.zero, withAdvancements: nil, forStartOfGlyphRange: paragraphSeparatorGlyphRange)
			setNotShownAttribute(true, forGlyphRange: paragraphSeparatorGlyphRange)
			
			endLine(withGlyphRange: paragraphSeparatorGlyphRange)
			
			lineFragmentOrigin.pointee.y += lineHeight
		}
		
		endParagraph()
		
		return NSMaxRange(paragraphSeparatorGlyphRange)
	}
	
	// Adjust the height of the fragment rectangles for empty lines.
	//
	override func getLineFragmentRect(_ lineFragmentRect: UnsafeMutablePointer<NSRect>,
									  usedRect lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
									  forParagraphSeparatorGlyphRange paragraphSeparatorGlyphRange: NSRange,
									  atProposedOrigin lineOrigin: NSPoint)
	{
		let fontHeight = BeatMinimapLayoutManager.minimapFontSize()
		
		// We always leave one point of space between lines
		let lineHeight = fontHeight + 1
		
		super.getLineFragmentRect(lineFragmentRect,
								  usedRect: lineFragmentUsedRect,
								  forParagraphSeparatorGlyphRange: paragraphSeparatorGlyphRange,
								  atProposedOrigin: lineOrigin)
		lineFragmentRect.pointee.size.height     = lineHeight
		lineFragmentUsedRect.pointee.size.height = fontHeight
	}
}
