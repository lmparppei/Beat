//
//  BeatUITextView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

class BeatUITextView: UITextView {

	//@IBInspectable var documentWidth:CGFloat = 640
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	@IBOutlet weak var enclosingScrollView:UIScrollView!
	@IBOutlet weak var pageView:UIView!
	
	var insets = UIEdgeInsets(top: 50, left: 40, bottom: 50, right: 40)
	var pinchRecognizer = UIGestureRecognizer()
	
	var customLayoutManager:BeatLayoutManager
	
	@objc class func createTextView(editorDelegate:BeatEditorDelegate, frame:CGRect, pageView:BeatPageView, scrollView:BeatScrollView) -> BeatUITextView {
		let textContainer = NSTextContainer()
		let layoutManager = BeatLayoutManager()
		let textStorage = NSTextStorage(string: "")
		
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		
		let textView = BeatUITextView(frame: frame, textContainer: textContainer, layoutManager: layoutManager)
		textView.autoresizingMask = [.flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		
		textView.textContainer.widthTracksTextView = false
		textView.pageView = pageView
		textView.enclosingScrollView = scrollView
				
		layoutManager.editorDelegate = editorDelegate
		textView.setup()
		
		return textView
	}
	
	init(frame: CGRect, textContainer: NSTextContainer?, layoutManager:BeatLayoutManager) {
		customLayoutManager = layoutManager
		super.init(frame: frame, textContainer: textContainer)
	}
	override var textLayoutManager: NSTextLayoutManager? {
		return nil
	}
	
	required init?(coder: NSCoder) {
		customLayoutManager = BeatLayoutManager()
		super.init(coder: coder)

		self.textStorage.removeLayoutManager(self.textStorage.layoutManagers.first!)
		
		customLayoutManager.addTextContainer(self.textContainer)
		customLayoutManager.textStorage = self.textStorage
		
		self.textContainer.replaceLayoutManager(customLayoutManager)
	}
	
	override var layoutManager: NSLayoutManager {
		return customLayoutManager
	}
	
	class func linePadding() -> CGFloat {
		return 40.0
	}
	
	@objc var documentWidth:CGFloat {
		var width = 0.0
		let padding = self.textContainer.lineFragmentPadding
		
		guard let delegate = self.editorDelegate else { return 0.0 }
		
		if delegate.pageSize == .A4 {
			width = BeatFonts.characterWidth() * 59
		} else {
			width = BeatFonts.characterWidth() * 61
		}
		
		return width + padding * 2
	}
		
	func setup() {
		self.textContainerInset = insets
		self.isScrollEnabled = false
		
		// Delegates
		enclosingScrollView?.delegate = self
		layoutManager.delegate = self
		
		// View setup
		self.textContainer.widthTracksTextView = false
		self.textContainer.heightTracksTextView = false
		
		self.textContainer.size = CGSize(width: self.documentWidth, height: self.textContainer.size.height)
		self.textContainer.lineFragmentPadding = BeatUITextView.linePadding()
				
		// Listen to changes
		NotificationCenter.default.addObserver(self, selector: #selector(didChangeSelection), name: UITextView.textDidChangeNotification, object: self)
		
		resizePaper()
		resize()
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setup()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		resize()
	}
	
	@objc func resizePaper() {
		var frame = pageView.frame
		frame.size.height = textContainer.size.height
		frame.size.width = self.documentWidth + textContainerInset.left + textContainerInset.right + BeatUITextView.linePadding()
		
		pageView.frame = frame
	}
	
	@objc func resize() {
		var containerHeight = textContainer.size.height + textContainerInset.top + textContainerInset.bottom
		guard let enclosingScrollView = self.enclosingScrollView else {
			print("WARNING: No scroll view set for text view")
			return
		}
		
		if (containerHeight < enclosingScrollView.frame.height) {
			containerHeight = enclosingScrollView.frame.height
		}
		
		self.textContainer.size = CGSize(width: self.documentWidth, height: containerHeight)
		self.textContainerInset = insets
		
		var frame = pageView.frame
				
		// Center the page view
		var x = (enclosingScrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0 }
		frame.origin.x = x
		
		var zoom = enclosingScrollView.zoomScale
		
		if (frame.height * zoom < enclosingScrollView.frame.height) {
			var targetHeight = frame.height
			if (self.frame.height < enclosingScrollView.frame.height) {
				targetHeight = enclosingScrollView.frame.height
			}
			let factor = targetHeight / enclosingScrollView.frame.height
			zoom = enclosingScrollView.zoomScale / factor
		}
		
		resizeScrollViewContent()
		
		frame.size.width = zoom * (self.documentWidth + self.insets.left + self.insets.right)
		frame.size.height = enclosingScrollView.contentSize.height
		self.pageView.frame = frame
		
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.enclosingScrollView.zoomScale = zoom
		} completion: { _ in
		}
	}
	
	// MARK: - Dialogue input
	
	func shouldCancelCharacterInput() -> Bool {
		guard let editorDelegate = self.editorDelegate else { return false }
		let line = editorDelegate.currentLine()
		
		/// We'll return `true` when the current line is empty
		if editorDelegate.characterInput && line!.string.count == 0 {
			print("Shuould cancel")
			return true
		} else {
			return false
		}
	}
	
	func cancelCharacterInput() {
		print("Canceling character input")
		
		guard let editorDelegate = self.editorDelegate else { return }
		
		let line = editorDelegate.characterInputForLine
		
		editorDelegate.characterInput = false
		editorDelegate.characterInputForLine = nil
		
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.firstLineHeadIndent = 0.0
		paragraphStyle.minimumLineHeight = BeatiOSFormatting.editorLineHeight()
		
		let attributes:[NSAttributedString.Key:Any] = [
			NSAttributedString.Key.font: editorDelegate.courier!,
			NSAttributedString.Key.paragraphStyle: paragraphStyle
		]
		
		self.typingAttributes = attributes
		self.setNeedsDisplay()
		self.setNeedsLayout()
		
		editorDelegate.setTypeAndFormat?(line, type: .empty)
	}
		

	// MARK: - Rects for ranges
	
	@objc func rectForRange (range: NSRange) -> CGRect {
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		let rect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
		
		return rect
	}
	
	
	// MARK: - Touch events
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesBegan(touches, with: event)
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesMoved(touches, with: event)
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesEnded(touches, with: event)
	}

	// MARK: - Other events
	
	@objc func didChangeSelection () {
		guard let editorDelegate = self.editorDelegate else { return }
		
		if (editorDelegate.currentLine().isAnyParenthetical()) {
			self.autocapitalizationType = .none
		} else {
			self.autocapitalizationType = .sentences
		}
	}
	
}

// MARK: - Layout manager delegate

// Manual memory management ahead, dread lightly.

extension BeatUITextView: NSLayoutManagerDelegate {
	func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: UIFont, forGlyphRange glyphRange: NSRange) -> Int {
		if self.editorDelegate?.documentIsLoading ?? false { return 0 }
		
		let line = editorDelegate?.parser.line(atPosition: charIndexes[0])
		if line == nil { return 0 }
		
		let type = line?.type
		if type == .section { return 0; }

		// Markdown indices
		let mdIndices:NSMutableIndexSet = NSMutableIndexSet(indexSet: line!.formattingRanges(withGlobalRange: true, includeNotes: false))
		
		// Add scene number range to markup indices
		if line!.sceneNumberRange.length > 0 {
			let sceneNumberRange = NSMakeRange(Int(line!.position) + Int(line!.sceneNumberRange.location), line!.sceneNumberRange.length)
			mdIndices.add(in: sceneNumberRange)
		}
		
		// Add possible color range to markup indices
		if line!.colorRange.length > 0 {
			let colorRange = NSMakeRange(Int(line!.position) + line!.colorRange.location, line!.colorRange.length)
			mdIndices.add(in: colorRange)
		}
				
		// perhaps do nothing
		if mdIndices.count == 0 &&
			!(type == .heading || type == .transitionLine || type == .character) &&
			!(line!.string.containsOnlyWhitespace() && line!.string.count > 1) {
			return 0
		}
		
		let location = charIndexes[0]
		let length = glyphRange.length
		
		let start = text.index(text.startIndex, offsetBy: location)
		let end = text.index(text.startIndex, offsetBy: location + length)
		let strRange = start..<end
		let subString = String(textStorage.string[strRange])
		let str = subString as CFString
		
		if subString == "\n" {
			return 0
		}
		
		// Create a mutable copy
		var modifiedStr = CFStringCreateMutable(nil, CFStringGetLength(str));
		CFStringAppend(modifiedStr, str);
		
		if (type == .heading || type == .transitionLine) {
			// Uppercase
			CFStringUppercase(modifiedStr, nil)
		}
				
		//let glyphProperty = NSLayoutManager.GlyphProperty()
		
		if line!.string.containsOnlyWhitespace() {
			CFStringFindAndReplace(modifiedStr, " " as CFString, "•" as CFString, CFRangeMake(0, CFStringGetLength(modifiedStr)), CFStringCompareFlags.init(rawValue: 0))
			let newGlyphs = GetGlyphsForCharacters(font: aFont as CTFont, string: modifiedStr!)
			layoutManager.setGlyphs(newGlyphs, properties:props, characterIndexes:charIndexes, font:aFont, forGlyphRange: glyphRange)
			
			free(newGlyphs)
		}
		else {
			let newGlyphs = GetGlyphsForCharacters(font: aFont as CTFont, string: modifiedStr!)
			layoutManager.setGlyphs(newGlyphs, properties: props, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
			newGlyphs.deallocate()
		}
		
		modifiedStr = nil
		return glyphRange.length
	}
	
	func GetGlyphsForCharacters(font:CTFont, string:CFString) -> UnsafeMutablePointer<CGGlyph> {
		let count = CFStringGetLength(string)

		let characters = UnsafeMutablePointer<unichar>.allocate(capacity: count)
		let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: count)
				
		CFStringGetCharacters(string, CFRangeMake(0, count), characters)
		CTFontGetGlyphsForCharacters(font, characters, glyphs, count);
		
		characters.deallocate()
		
		return glyphs
	}
	 

}

// MARK: - Scroll view delegation

extension BeatUITextView: UIScrollViewDelegate {
	
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return pageView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		let frame = enclosingScrollView.frame
		var x = (frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0 }
		
		var pageFrame = pageView.frame
		pageFrame.origin.x = x
		pageView.frame = pageFrame
	}
	
	func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		var x = (scrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0; }
		
		var frame = pageView!.frame
		frame.origin.x = x
		
		var zoom = scrollView.zoomScale
		
		if (frame.height < scrollView.frame.height) {
			let factor = frame.height / scrollView.frame.height
			zoom = scrollView.zoomScale / factor
		}
		
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.pageView.frame = frame
			self.enclosingScrollView.zoomScale = zoom
		} completion: { _ in
			
		}
	}
	
	func resizeScrollViewContent() {
		// Add constraints to the text view
		let layoutManager = self.layoutManager
		//let textContainerInset = self.textContainerInset

		// Calculate the index of the last glyph that fits within the available height
		let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: self.text.count)

		// Get the rectangle of the line fragment that contains the last glyph
		var lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex - 1, effectiveRange: nil)
		var lastLineY = lastLineRect.maxY
		if lastLineRect.origin.y == 0.0 {
			lastLineRect = layoutManager.extraLineFragmentRect
			lastLineY = lastLineRect.maxY * -1
		}
		
		let factor = self.enclosingScrollView.zoomScale
		let contentSize = CGSize(width: self.documentWidth, height: lastLineY)
		let scrollSize = CGSize(width: (contentSize.width + self.textContainerInset.left + self.textContainerInset.right) * factor,
								height: (contentSize.height + self.textContainerInset.top + self.textContainerInset.bottom) * factor)

		let heightNow = self.enclosingScrollView.contentSize.height
		
		// Adjust the size to fit, if the size differs more than 5.0 points
		if (scrollSize.height < heightNow - 5.0 || scrollSize.height > heightNow + 5.0) {
			self.enclosingScrollView.contentSize = scrollSize
		}
		
	}
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }
		
		if key.keyCode == .keyboardTab {
			// Never allow tab
			return
		}
		else if key.keyCode == .keyboardDeleteOrBackspace {
			// Check if we should cancel character input
			if self.shouldCancelCharacterInput() {
				self.cancelCharacterInput()
				return
			}
		}
		
		super.pressesBegan(presses, with: event)
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }

		switch key.keyCode {
		case .keyboardTab:
			editorDelegate?.handleTabPress?()
			break
			
		default:
			super.pressesEnded(presses, with: event)
		}
	}
}

// MARK: - Assisting views

class BeatPageView:UIView {
	override func awakeFromNib() {
		super.awakeFromNib()
		
		layer.shadowRadius = 3.0
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.2
		layer.shadowOffset = .zero
	}
}

class BeatScrollView: UIScrollView {
	
}
