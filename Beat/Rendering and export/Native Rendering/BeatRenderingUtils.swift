//
//  BeatRendering.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatPagePrintView:NSView {
	override var isFlipped: Bool { return true }
	weak var previewController:BeatPreviewController?
}

class BeatPaginationPageView:NSView {
	override var isFlipped: Bool { return true }
	weak var previewController:BeatPreviewController?
	
	var attributedString:NSAttributedString?
	var pageStyle:RenderStyle
	
	var textView:BeatPageTextView?
	var linePadding = 20.0
	var size:NSSize
	
	var fonts = BeatFonts.shared()
	
	init(size:NSSize, content:NSAttributedString, pageStyle:RenderStyle, previewController: BeatPreviewController? = nil) {
		
		self.size = size
		self.pageStyle = pageStyle
		self.attributedString = content
		self.previewController = previewController
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		
		self.canDrawConcurrently = true
		self.wantsLayer = true
		self.layer?.backgroundColor = .white
		
		createTextView()
		self.textView?.textStorage?.setAttributedString(self.attributedString ?? NSAttributedString(string: ""))
	}
	
	@objc func setContent(attributedString:NSAttributedString, settings:BeatExportSettings) {
		self.textView?.textStorage?.setAttributedString(attributedString)
	}
	
	func createTextView() {
		self.textView = BeatPageTextView(
			frame: NSRect(x: self.pageStyle.marginLeft - linePadding,
						  y: self.pageStyle.marginTop,
						  width: size.width - self.pageStyle.marginLeft,
						  height: size.height - self.pageStyle.marginTop - self.pageStyle.marginBottom)
		)
		
		self.textView?.isEditable = false

		self.textView?.linkTextAttributes = [
			NSAttributedString.Key.font: fonts.courier,
			NSAttributedString.Key.foregroundColor: NSColor.black,
			NSAttributedString.Key.cursor: NSCursor.pointingHand
		]
		self.textView?.displaysLinkToolTips = false
		self.textView?.isAutomaticLinkDetectionEnabled = false
		
		self.textView?.font = fonts.courier
		
		self.textView?.textContainer?.lineFragmentPadding = linePadding
		self.textView?.textContainerInset = NSSize(width: 0, height: 0)
		
		let layoutManager = BeatRenderLayoutManager()
		self.textView?.textContainer?.replaceLayoutManager(layoutManager)
		self.textView?.textContainer?.lineFragmentPadding = linePadding
		
		textView?.backgroundColor = .white
		textView?.drawsBackground = true
		
		self.addSubview(textView!)
	}
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Custom text view

class BeatPageTextView:NSTextView {
	var previewController:BeatPreviewController?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		let trackingArea = NSTrackingArea(rect: bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
		addTrackingArea(trackingArea)
	}
	
	override func mouseMoved(with event: NSEvent) {
		super.mouseMoved(with: event)
		/*
		guard
			let lm = self.layoutManager,
			let tc = self.textContainer
		else { return }

		let localMousePosition = convert(event.locationInWindow, from: nil)
		var partial = CGFloat(1.0)
		let glyphIndex = lm.glyphIndex(for: localMousePosition, in: tc, fractionOfDistanceThroughGlyph: &partial)

		let rect = lm.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
		let range = lm.glyphRange(forBoundingRect: rect, in: self.textContainer!)
		let charRange = lm.characterRange(forGlyphRange: range, actualGlyphRange: nil)
			
		let key = NSAttributedString.Key(rawValue: "ActiveLine")
		
		lm.removeTemporaryAttribute(key, forCharacterRange: self.textStorage!.range)
		lm.addTemporaryAttribute(key, value: true, forCharacterRange: charRange)
		*/
	}
	
	override func clicked(onLink link: Any, at charIndex: Int) {
		guard
			let line = link as? Line,
			let previewController = self.previewController
		else { return }
		
		let range = NSMakeRange(line.position, 0)
		previewController.delegate?.returnToEditor()
		previewController.delegate?.setSelectedRange(range)
		previewController.delegate?.scroll(to: range, callback: {})
	}
}
