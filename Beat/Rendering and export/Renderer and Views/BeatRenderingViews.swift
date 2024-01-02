//
//  BeatRenderingViews.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore
import BeatPagination2

// MARK: - Basic page view for rendering the screenplay

class BeatPagePrintView:NSView {
	override var isFlipped: Bool { return true }
	weak var previewController:BeatPreviewController?
}

class BeatPaginationPageView:NSView {
	override var isFlipped: Bool { return true }
	weak var previewController:BeatPreviewController?
	
	var attributedString:NSAttributedString?
	var pageStyle:RenderStyle
	var settings:BeatExportSettings
	
	var page:BeatPaginationPage?
	
	var textView:BeatPageTextView?
	var linePadding = 0.0
	var size:NSSize
	
	var fonts = BeatFonts.shared()
	
	var paperSize:BeatPaperSize
	var isTitlePage = false
	
	@objc init(page:BeatPaginationPage?, content:NSAttributedString?, settings:BeatExportSettings, previewController: BeatPreviewController?, titlePage:Bool = false) {
		self.size = BeatPaperSizing.size(for: settings.paperSize)

		self.attributedString = content
		self.previewController = previewController
		self.settings = settings
		self.paperSize = settings.paperSize
				
		self.page = page
		if (page != nil) {
			self.attributedString = page!.attributedString()
		} else {
			self.attributedString = content
		}
		
		let styles = self.settings.styles as? BeatStylesheet
		self.pageStyle = styles?.page() ?? RenderStyle(rules: [:])
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		
		self.canDrawConcurrently = true
		self.wantsLayer = true
		self.layer?.backgroundColor = .white
		
		// Force light appearance to get highlights show up correctly
		self.appearance = NSAppearance(named: .aqua)
		
		// Create text views and set attributed string
		createTextView()
		self.textView?.textStorage?.setAttributedString(self.attributedString ?? NSAttributedString(string: ""))
	}
	
	@objc func setContent(attributedString:NSAttributedString, settings:BeatExportSettings) {
		self.textView?.textStorage?.setAttributedString(attributedString)
	}
	
	func createTextView() {
		self.textView = BeatPageTextView(frame: self.textViewFrame())
		
		self.textView?.previewController = self.previewController
		
		self.textView?.isEditable = false

		self.textView?.linkTextAttributes = [
			NSAttributedString.Key.font: fonts.regular,
//			NSAttributedString.Key.foregroundColor: NSColor.black,
			NSAttributedString.Key.cursor: NSCursor.pointingHand
		]
		self.textView?.displaysLinkToolTips = false
		self.textView?.isAutomaticLinkDetectionEnabled = false
		
		self.textView?.font = fonts.regular
		
		self.textView?.textContainer?.lineFragmentPadding = linePadding
		self.textView?.textContainerInset = NSSize(width: 0, height: 0)
		
		let layoutManager = BeatRenderLayoutManager()
		layoutManager.pageView = self
		
		self.textView?.textContainer?.replaceLayoutManager(layoutManager)
		self.textView?.textContainer?.lineFragmentPadding = linePadding
		
		textView?.backgroundColor = .white
		textView?.drawsBackground = true
		
		self.addSubview(textView!)
	}
	
	func textViewFrame() -> NSRect {
		let size = BeatPaperSizing.size(for: settings.paperSize)
		let marginOffset = (settings.paperSize == .A4) ? pageStyle.marginLeftA4 : pageStyle.marginLeftLetter
		
		let textFrame = NSRect(x: self.pageStyle.marginLeft - linePadding + marginOffset,
							   y: self.pageStyle.marginTop,
							   width: size.width - self.pageStyle.marginLeft - self.pageStyle.marginRight,
							   height: size.height - self.pageStyle.marginTop)
		
		return textFrame
	}
	
	func updateContainerSize() {
		paperSize = settings.paperSize
		self.textView?.frame = self.textViewFrame()
	}
	
	// Update content
	func update(page:BeatPaginationPage, settings:BeatExportSettings) {
		self.settings = settings
		self.page = page
		
		// Update container frame if paper size has changed
		if (self.settings.paperSize != self.paperSize) {
			updateContainerSize()
			page.invalidateRender()
		}
		
		self.textView?.textStorage?.setAttributedString(page.attributedString())
	}
	
	override func cancelOperation(_ sender: Any?) {
		superview?.cancelOperation(sender)
	}
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Custom text view

class BeatPageTextView:NSTextView {
	weak var previewController:BeatPreviewController?
	
	/// The user clicked on a link, which direct to `Line` objects
	override func clicked(onLink link: Any, at charIndex: Int) {
		guard
			let line = link as? Line,
			let previewController = self.previewController
		else { return }
		
		previewController.closeAndJumpToRange(line.textRange())
	}
	
	override func cancelOperation(_ sender: Any?) {
		superview?.cancelOperation(sender)
	}
}


// MARK: - Title page

class BeatTitlePageView:BeatPaginationPageView {
	var leftColumn:NSTextView?
	var rightColumn:NSTextView?
	var titlePageLines:[[String:[Line]]]
	
	init(previewController: BeatPreviewController? = nil, titlePage:[[String:[Line]]], settings:BeatExportSettings) {
		self.titlePageLines = titlePage
		super.init(page: nil, content: NSMutableAttributedString(string: ""), settings: settings, previewController: previewController, titlePage: true)
			
		createViews()
		createTitlePage()
		
		isTitlePage = true
	}
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// Creates title page content and places the text snippets into correct spots
	func createTitlePage() {

		guard let leftColumn = self.leftColumn,
			  let rightColumn = self.rightColumn,
			  let textView = self.textView
		else {
			print("ERROR: No text views found, returning empty page")
			return
		}
		
		textView.string = "\n" // Add one extra line break to make title top margin have effect
		leftColumn.string = ""
		rightColumn.string = ""
	
		let renderer = BeatRenderer(settings: self.settings)
		
		var top:[Line] = []
		
		if let title = titlePageElement("title") { top.append(contentsOf: title) }
		if let credit = titlePageElement("credit") { top.append(contentsOf: credit) }
		if let authors = titlePageElement("authors") { top.append(contentsOf: authors) }
		if let source = titlePageElement("source") { top.append(contentsOf: source) }
		
		// Title, credit, author, source on top
		let topContent = NSMutableAttributedString(string: "")
		for el in top {
			let attrStr = renderer.renderLine(el, of: nil, dualDialogueElement: false, firstElementOnPage: false)
			
			topContent.append(attrStr)
		}
		textView.textStorage?.append(topContent)
		
		// Draft date on right side
		if let draftDate = titlePageElement("draft date") {
			let attrStr = NSMutableAttributedString()
			_ = draftDate.map { attrStr.append(renderer.renderLine($0)) }
			rightColumn.textStorage?.append(attrStr)
		}
		
		if let contact = titlePageElement("contact") {
			let attrStr = NSMutableAttributedString()
			_ = contact.map { attrStr.append(renderer.renderLine($0)) }
			leftColumn.textStorage?.append(attrStr)
		}
				
		// Add the rest of the elements on left side
		for d in self.titlePageLines {
			let dict = d
			
			if let element = titlePageElement(dict.keys.first ?? "") {
				let attrStr = NSMutableAttributedString()
				_ = element.map { attrStr.append(renderer.renderLine($0)) }
				leftColumn.textStorage?.append(attrStr)
			}
		}
		
		// Remove backgrounds
		leftColumn.drawsBackground = false
		rightColumn.drawsBackground = false
		textView.drawsBackground = false
		
		// Layout manager doesn't handle newlines too well, so let's trim the column content
		leftColumn.textStorage?.setAttributedString(leftColumn.attributedString().trimmedAttributedString(set: .newlines))
		rightColumn.textStorage?.setAttributedString(rightColumn.attributedString().trimmedAttributedString(set: .newlines))

		// Once we've set the content, let's adjust top inset to align text to bottom
		leftColumn.textContainerInset = NSSize(width: 0, height: 0)
		rightColumn.textContainerInset = NSSize(width: 0, height: 0)
		
		_ = leftColumn.layoutManager!.glyphRange(for: leftColumn.textContainer!)
		_ = rightColumn.layoutManager!.glyphRange(for: rightColumn.textContainer!)
		let leftRect = leftColumn.layoutManager!.usedRect(for: leftColumn.textContainer!)
		let rightRect = rightColumn.layoutManager!.usedRect(for: rightColumn.textContainer!)
				
		// We'll calculate correct insets for the boxes, so the content will be bottom-aligned
		let insetLeft = leftColumn.frame.height - leftRect.height
		let insetRight = rightColumn.frame.height - rightRect.height
		
		leftColumn.textContainerInset = NSSize(width: 0, height: insetLeft)
		rightColumn.textContainerInset = NSSize(width: 0, height: insetRight)
	}
	
	/// Gets **and removes** a title page element from title page array. The array looks like `[ [key: value], [key: value], ...]` to keep the title page elements organized.
	func titlePageElement(_ key:String) -> [Line]? {
		var lines:[Line] = []

		for i in 0..<titlePageLines.count {
			let dict = titlePageLines[i]
			
			if (dict[key] != nil) {
				lines = dict[key] ?? []
				titlePageLines.remove(at: i)
				break
			}
		}
		
		// No title page element was found, return nil
		if lines.count == 0 { return nil }
	
		var type:LineType = .empty
		switch key {
			case "title":
				type = .titlePageTitle
			case "authors":
				type = .titlePageAuthor
			case "credit":
				type = .titlePageCredit
			case "source":
				type = . titlePageSource
			case "draft date":
				type = .titlePageDraftDate
			case "contact":
				type = .titlePageContact
			default:
				type = .titlePageUnknown
		}
		
		var elementLines:[Line] = []
				
		for i in 0..<lines.count {
			let l = lines[i]
			l.type = type
			elementLines.append(l)
		}
				
		return elementLines
	}
	
	/// Updates title page content 
	func updateTitlePage(_ titlePageContent: [[String:[Line]]]) {
		self.titlePageLines = titlePageContent
		createTitlePage()
	}
	
	/// Override page render method for title pages
	func createViews() {
		let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
		let textViewFrame = NSRect(x: pageStyle.marginLeft,
								   y: pageStyle.marginTop,
								   width: frame.size.width - pageStyle.marginLeft * 2,
								   height: 400)
		textView?.frame = frame
		
		let columnFrame = NSRect(x: pageStyle.marginLeft,
								 y: textViewFrame.origin.y + textViewFrame.height,
								 width: textViewFrame.width / 2 - 10,
								 height: frame.height - textViewFrame.size.height - pageStyle.marginBottom - BeatPagination.lineHeight() * 2)
		
		if (leftColumn == nil) {
			leftColumn = NSTextView(frame: columnFrame)
			leftColumn?.isEditable = false
			leftColumn?.drawsBackground = false
			//leftColumn?.backgroundColor = .white
			leftColumn?.isSelectable = false
			
			self.addSubview(leftColumn!)
		}

		if (rightColumn == nil) {
			let rightColumnFrame = NSRect(x: frame.width - pageStyle.marginLeft - columnFrame.width,
										  y: columnFrame.origin.y, width: columnFrame.width, height: columnFrame.height)
			
			rightColumn = NSTextView(frame: rightColumnFrame)
			rightColumn?.isEditable = false
			rightColumn?.drawsBackground = false
			//rightColumn?.backgroundColor = .white
			rightColumn?.isSelectable = false
			
			self.addSubview(rightColumn!)
		}
	}
}

// MARK: - Custom layout manager for text views in rendered page view

class BeatRenderLayoutManager:NSLayoutManager {
	weak var pageView:BeatPaginationPageView?
	
	override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
		super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
		
		let container = self.textContainers.first!
		let revisions = pageView?.settings.revisions as? [String] ?? []
		
		if ((pageView?.isTitlePage ?? false)) {
			return
		}
		
		NSGraphicsContext.saveGraphicsState()
		
		self.enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, originalRange, stop in
			let markerRect = NSMakeRect(container.size.width - 10 - (self.pageView?.pageStyle.marginRight ?? 0.0), usedRect.origin.y - 3.0, 15, usedRect.size.height)
			
			var highestRevision = ""
			var range = originalRange
			
			// This is a fix for some specific languages. Sometimes you might have more characters in range than what are stored in text storage.
			if (NSMaxRange(range) > self.textStorage!.string.count) {
				let len = max(self.textStorage!.string.count - NSMaxRange(range), 0)
				range = NSMakeRange(range.location, len)
				
				if (range.length == 0) {
					return
				}
			}
			
			self.textStorage?.enumerateAttribute(NSAttributedString.Key(BeatRevisions.attributeKey()), in: range, using: { obj, attrRange, stop in
				if (obj == nil) { return }
				let revision = obj as! String
				
				// If the revision is not included in settings, just skip it.
				if (!revisions.contains(where: { $0 == revision })) {
					return
				}
				
				if highestRevision == "" {
					highestRevision = revision
				}
				else if BeatRevisions.isNewer(revision, than: highestRevision) {
					highestRevision = revision
				}
			})
			
			if highestRevision == "" { return }
			
			let marker:NSString = BeatRevisions.revisionMarkers()[highestRevision]! as NSString
			let font = BeatFonts.shared().regular
			marker.draw(at: markerRect.origin, withAttributes: [
				NSAttributedString.Key.font: font,
				NSAttributedString.Key.foregroundColor: NSColor.black
			])
		}
		
		NSGraphicsContext.restoreGraphicsState()
	}
	
	override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
		super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
		/*
		let chrRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
		let key = NSAttributedString.Key(rawValue: "ActiveLine")
		
		let attr = self.temporaryAttribute(key, atCharacterIndex: chrRange.location, effectiveRange: nil) as? Bool ?? false
		if (attr) {
			let rect = self.lineFragmentUsedRect(forGlyphAt: glyphsToShow.location, effectiveRange: nil, withoutAdditionalLayout: true)
			NSColor.red.setFill()
			rect.fill()
		}
		 */
	}
}

