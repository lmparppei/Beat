//
//  BeatLineNumberView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa
import BeatCore
import BeatThemes

extension BeatTextView {
	@objc func setupLineNumberView() {
		self.enclosingScrollView?.rulersVisible = BeatUserDefaults.shared().getBool("showLineNumbers")
		self.enclosingScrollView?.hasVerticalRuler = true
		self.enclosingScrollView?.verticalRulerView = BeatLineNumberRulerView(textView: self, delegate: self.editorDelegate)
	}
	
	@IBAction func toggleLineNumbers(_ sender: NSMenuItem) {
		guard let enclosingScrollView else { return }
		enclosingScrollView.rulersVisible.toggle()
		
		BeatUserDefaults.shared().save(enclosingScrollView.rulersVisible, forKey: "showLineNumbers")
		self.editorDelegate.updateLayout()
	}
}

@objc final class BeatLineNumberRulerView: NSRulerView {
	
	weak var delegate:BeatEditorDelegate?
	var font:NSFont
	var textColor:NSColor = ThemeManager.shared().invisibleTextColor
	var backgroundColor: NSColor = .clear
		
	struct Mark: Codable { let line: Int; let colorName: String }
	
	// MARK: Init
	
	@objc init(textView: NSTextView, delegate:BeatEditorDelegate) {
		self.delegate = delegate
		self.font = delegate.fonts.regular
		
		super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
		self.clientView = textView
		self.ruleThickness = 40
		registerForNotifications(textView: textView)
		updateRuleThickness()
	}
	
	required init(coder: NSCoder) { fatalError() }
	
	private func registerForNotifications(textView: NSTextView) {
		if let scrollView = textView.enclosingScrollView {
			scrollView.contentView.postsBoundsChangedNotifications = true
			NotificationCenter.default.addObserver(
				self, selector: #selector(contentBoundsChanged),
				name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
		}
		
		if let storage = textView.textStorage {
			NotificationCenter.default.addObserver(
				self, selector: #selector(contentDidChange),
				name: NSTextStorage.didProcessEditingNotification, object: storage)
		}
		
		NotificationCenter.default.addObserver(
			self, selector: #selector(contentBoundsChanged),
			name: NSTextView.didChangeSelectionNotification, object: textView)
	}
	
	@objc private func contentDidChange() {
		updateRuleThickness()
		needsDisplay = true
	}
	
	@objc private func contentBoundsChanged() {
		needsDisplay = true
	}
		
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	
	/// Calculates the required width for ruler based on line count
	private func updateRuleThickness() {
		guard let delegate else { return }
		
		let digits = max(3, String(delegate.parser.lines.count).count)
		let sample = String(repeating: "8", count: digits)
		let width = (sample as NSString).size(withAttributes: [.font: font]).width
		let newThickness = ceil(width) + 16
		
		if abs(newThickness - ruleThickness) > 0.5 {
			ruleThickness = newThickness
		}
	}
	
	/// Binary search: largest line whose start <= charIndex.
	private func lineNumber(forCharacterIndex index: Int) -> Int {
		guard let delegate else { return NSNotFound }
		
		let idx = delegate.parser.lineIndex(atPosition: UInt(index))
		
		// Line numbers start from 1
		return Int(idx)+1
	}
	
	private func isLineStart(_ charIndex: Int, forLine lineIndex: Int) -> Bool {
		guard let delegate, lineIndex >= 0, lineIndex < delegate.parser.lines.count else { return false }
				
		if let line = delegate.parser.lines[lineIndex - 1] as? Line {
			return line.position == charIndex
		}
		return false
	}
	
	// MARK: Drawing
	
	override func drawHashMarksAndLabels(in rect: NSRect) {
		guard let textView = clientView as? NSTextView,
			  let layoutManager = textView.layoutManager,
			  let textContainer = textView.textContainer,
			  let delegate
		else { return }
 
		backgroundColor.setFill()
		rect.fill()
 
		var visibleRect = textView.visibleRect
		visibleRect.origin.y -= textView.textContainerInset.height
		
		let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect,
														   in: textContainer)
		
		let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
		let inset = textView.textContainerInset
		
		let selection = textView.selectedRange()
 		
		layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { [weak self] lineRect, _, _, glyphRange, _ in
			guard let self = self else { return }
 
			let charIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
			let lineNum = self.lineNumber(forCharacterIndex: charIndex)
			let lineIdx = lineNum - 1
			
			var isCurrentLine = false
			if lineIdx < delegate.parser.lines.count, let line = delegate.parser.lines[lineIdx] as? Line {
				if (NSIntersectionRange(line.range(), selection).length > 0 || NSLocationInRange(selection.location, line.range())) {
					isCurrentLine = true
				}
			}
			
			// lineRect is in TEXT CONTAINER coordinates, which sits inside the text bounds offset by textContainerInset
			var containerAdjustedRect = lineRect
			containerAdjustedRect.origin.x += inset.width
			containerAdjustedRect.origin.y += inset.height
 
			// Convert the rect through the text view's transform, so scaleUnitSquare: value is handled automatically.
			let converted = textView.convert(containerAdjustedRect, to: self)
 
			if isCurrentLine {
				ThemeManager.shared().selectionColor.withAlphaComponent(0.1).setFill()
				NSRect(x: 0, y: converted.minY, width: self.ruleThickness, height: converted.height).fill()
			}
 
			// Only draw the number on the first fragment of the line
			guard self.isLineStart(charIndex, forLine: lineNum) || lineIdx == delegate.parser.lines.lastIndex else { return }
 
			var lineAttrs = attrs
			if isCurrentLine {
				lineAttrs[.foregroundColor] = NSColor.labelColor
			}
 
			let numberString = "\(lineNum)"
			let size = numberString.size(withAttributes: lineAttrs)
			let x = self.ruleThickness - size.width - 6
			let y = converted.minY + (converted.height - size.height) / 2
			numberString.draw(at: NSPoint(x: x, y: y), withAttributes: lineAttrs)
		}
	}
}
