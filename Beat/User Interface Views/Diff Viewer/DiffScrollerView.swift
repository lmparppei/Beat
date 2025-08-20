//
//  DiffScrollerView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 6.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

// MARK: - Custom Diff Scrollbar

class DiffScrollerView: NSScroller {
	private var insertRanges: [NSRange] = []
	private var deleteRanges: [NSRange] = []
	private var totalLength: CGFloat = 1.0
	
	func updateDiffRanges(insertRanges: [NSRange], deleteRanges: [NSRange], totalLength: Int) {
		self.insertRanges = insertRanges
		self.deleteRanges = deleteRanges
		self.totalLength = CGFloat(max(totalLength, 1))
		self.needsDisplay = true
	}
	
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		drawDiffIndicators()
	}
	
	private func drawDiffIndicators() {
		// Set up colors
		let insertColor = NSColor.systemGreen.withAlphaComponent(0.6)
		let deleteColor = NSColor.systemRed.withAlphaComponent(0.6)
		
		let slotRect = self.rect(for: .knobSlot)
		let indicatorWidth: CGFloat = self.frame.width
		
		// Draw insert indicators
		drawIndicators(ranges: insertRanges, color: insertColor, slotRect: slotRect, indicatorWidth: indicatorWidth)
		
		// Draw delete indicators
		drawIndicators(ranges: deleteRanges, color: deleteColor, slotRect: slotRect, indicatorWidth: indicatorWidth)
	}
	
	private func drawIndicators(ranges: [NSRange], color: NSColor, slotRect: NSRect, indicatorWidth: CGFloat) {
		color.setFill()
		
		for range in ranges {
			let rangeStart = CGFloat(range.location) / totalLength
			let rangeEnd = CGFloat(range.location + range.length) / totalLength
			
			// Calculate position in scrollbar
			let yStart = slotRect.origin.y + slotRect.size.height * rangeStart
			let height = max(2.0, slotRect.size.height * (rangeEnd - rangeStart))
			
			// Draw indicator
			let indicatorRect = NSRect(
				x: slotRect.origin.x,
				y: yStart,
				width: indicatorWidth,
				height: height
			)
			
			let path = NSBezierPath(roundedRect: indicatorRect, xRadius: 1.0, yRadius: 1.0)
			path.fill()
		}
	}
}
