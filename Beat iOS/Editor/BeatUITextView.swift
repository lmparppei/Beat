//
//  BeatUITextView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatUITextView: UITextView {
	
	//@IBInspectable var documentWidth:CGFloat = 640
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	@IBOutlet weak var enclosingScrollView:UIScrollView!
	@IBOutlet weak var pageView:UIView!
	
	var insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
	var pinchRecognizer = UIGestureRecognizer()
	var magnification = 1.0
	var oldMagnification = 0.0
	var prevScale = 0.0
	
	var documentWidth = 640.0

	/*
	override var insetsLayoutMarginsFromSafeArea: Bool {
		get { return true }
		set { super.insetsLayoutMarginsFromSafeArea = true }
	}
	 */
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.textContainerInset = insets
		self.isScrollEnabled = false
		
	
		enclosingScrollView?.delegate = self
		
		 
		// Layout delegation
		layoutManager.delegate = self
		
		
		self.textContainer.widthTracksTextView = false
		self.textContainer.size = CGSize(width: self.documentWidth, height: self.textContainer.size.height)
		
		resizePaper()
		resize()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		resize()
	}
	
	func resizePaper() {
		var frame = pageView.frame
		frame.size.height = textContainer.size.height
		frame.size.width = self.documentWidth + textContainerInset.left + textContainerInset.right
		
		pageView.frame = frame
	}
	
	func resize() {
		var containerHeight = textContainer.size.height + textContainerInset.top + textContainerInset.bottom
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
		
		frame.size.height = enclosingScrollView.contentSize.height
				
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.pageView.frame = frame
			self.enclosingScrollView.zoomScale = zoom
		} completion: { _ in

		}
	}
	

	// MARK: - Rects for ranges
	
	func rectForRange (range: NSRange) -> CGRect {
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		let rect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
		
		return rect
	}
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		/*
		for touch in touches {
			
		}
		 */
	}
	
}

// MARK: - Layout manager delegate

// Manual memory management ahead, dread lightly.

extension BeatUITextView: NSLayoutManagerDelegate {
	func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: UIFont, forGlyphRange glyphRange: NSRange) -> Int {
		
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
		let factor = self.enclosingScrollView.zoomScale
		let contentSize = self.sizeThatFits(CGSize(width: self.documentWidth, height: CGFloat.greatestFiniteMagnitude))
		let scrollSize = CGSize(width: (contentSize.width + self.textContainerInset.left + self.textContainerInset.right) * factor,
								height: (contentSize.height + self.textContainerInset.top + self.textContainerInset.bottom) * factor)
		
		self.enclosingScrollView.contentSize = scrollSize
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
