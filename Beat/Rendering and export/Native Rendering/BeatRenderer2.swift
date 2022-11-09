//
//  BeatRenderer2.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 `BeatPageView` contains multitude of `BeatPageBlock` objects, which in turn contain `BeatPageElement` objects.
 The latter holds a reference to the line it represents, and can be rendered into a formatted `NSAttributedString`,
 and each parent element renders itself using that string.
 
 NOTE: A line break is appended to the actual line string, but all element heights have to be calculated without it.
 
*/

import Cocoa

protocol BeatPageViewDelegate:NSObject {
	var styles:Styles { get }
	var settings:BeatExportSettings { get }
	var fonts:BeatFonts { get }
	var pages:[BeatPageView2] { get }
}

class BeatRenderer2:NSObject, BeatPageViewDelegate {
	var lines = [Line]()
	var titlePageLines = [Line]()
	var livePagination = false
	var fonts = BeatFonts.shared()
	var settings:BeatExportSettings
	var styles:Styles = Styles.shared
	
	var titlePage:BeatPageView2?
	var pages = [BeatPageView2]()
	var currentPage:BeatPageView2? = nil
	
	@objc init(document:Document, screenplay:BeatScreenplay, settings:BeatExportSettings, livePagination:Bool) {
		self.livePagination = livePagination
		self.lines = screenplay.lines
		self.titlePageLines = screenplay.titlePage
		self.settings = settings
		
		super.init()
	}
	
	var numberOfPages:Int {
		get {
			// If the page count is zero, we'll paginate the document
			if pages.count == 0 { paginate() }
			return pages.count
		}
	}

	/// Paginate the given document from scratch
	@objc func paginate() {
		self.pages.removeAll()
		paginate(fromIndex: 0)
	}
	
	/// Create a PDF using the current pagination data
	@objc func pdf() -> URL {
		let pdf = PDFDocument()
		
		for page in pages {
			// Create a PDF image using the current page
			page.display()
			let data = page.dataWithPDF(inside: NSMakeRect(0, 0, page.frame.width, page.frame.height))
			let pdfPage = PDFPage(image: NSImage(data: data)!)!
			pdf.insert(pdfPage, at: pdf.pageCount)
		}
		
		let url = tempURL()
		pdf.write(to: url)
		NSWorkspace.shared.open(url)
		
		return url
	}
	
	func tempURL() -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("pdf")
		return url
	}
	
	@objc func paginate(fromIndex:Int) {
		// Reset current page
		currentPage = nil
		
		// This is the element queue. We are iterating the document line-by-line,
		// but work with blocks. When an element becomes part of a block, it's added
		// to the queue, so the pagination will know to skip it when iterating.
		// The queue is flushed after a new line is reached.
		var tmpElements:[Line] = []
		
		// Continuous pagination can paginate from any given line index
		if fromIndex == 0 {
			pages = []
			currentPage = BeatPageView2(delegate: self)
		}
		
		for i in fromIndex...lines.count - 1 {
			let line = lines[i]
			
			// Ignore lines before the given index
			if (fromIndex > 0 && NSMaxRange(line.textRange()) < fromIndex) { continue }
			
			// Catch wrong parsing.
			// This shouldn't happen, but stuff like this can rarely get through the parser.
			if (line.string.count == 0) { continue }
			
			// If the line has been already handled, ignore this line. Otherwise let's clear the temp queue.
			if (tmpElements.contains(line)) { continue }
			else { tmpElements.removeAll() }
			
			// Skip invisible elements (unless we are printing notes)
			if (line.type == .empty) { continue }
			else if (line.isInvisible()) {
				if (!(settings.printNotes && line.note())) { continue }
			}
						
			// If this is the FIRST page, add a break to mark for the end of title page and beginning of document
			// if (_pageBreaks.count == 0 && _livePagination) [self pageBreak:element position:0 type:@"First page"];
			
			// If we've started a new page since we began paginating, see if the rest of the page is intact.
			// If so, we can just use our cached results.
			/*
			if (hasBegunANewPage && currentPage?.lines.count == 0 &&
				!line.unsafeForPageBreak && _pageCache.count >= self.pages.count) {
				Line *firstLineOnCachedPage = _pageCache[self.pages.count-1].firstObject;
				
				if (firstLineOnCachedPage.uuid == element.uuid) {
					[self useCachedPaginationFrom:self.pages.count - 1];
					// Stop pagination
					break;
				}
			}
			 */
						
			// catch forced page breaks first
			if (line.type == .pageBreak) {
				addPage(currentPage!, onCurrentPage: [line], onNextPage: [])
				addPageBreak(element: line, position: -1, type: "Forced page break")
				continue
			}
			
			/**
			 Get the block for current line and add it to temp element queue.
			 A block is something that has to be handled as one when paginating, such as:
			 • a single paragraph or transition
			 • dialogue block, or a dual dialogue block
			 • a heading or a shot, followed by another block
			*/
			tmpElements = []
			
			let blocks = blocksFor(lineAtIndex: i)
			var pageBlocks:[BeatPageBlock] = []
			
			for block in blocks {
				let pageBlock = BeatPageBlock(block: block, delegate: self)
				pageBlocks.append(pageBlock)
				tmpElements.append(contentsOf: block)
			}
			//tmpElements = blockFor(lineAtIndex: i)
			
			// Create visual representation for the block
			let blockGroup = BeatBlockGroup(blocks: pageBlocks)
			//let block = BeatPageBlock(block: tmpElements, delegate: self)
			
			// See if it fits on current page
			if currentPage!.remainingSpace >= blockGroup.height {
				// Add every part of the block group
				for pageBlock in pageBlocks {
					currentPage!.addBlock(pageBlock)
				}
				continue
			}
			else {
				// The block does not fit.
				let remainingSpace = currentPage!.remainingSpace
				
				if (remainingSpace < BeatRenderer2.lineHeight()) {
					// Less than 1 row, just roll over to the next page
					addPage(currentPage!, onCurrentPage: [], onNextPage: tmpElements)
					continue
				}
				
				if blockGroup.blocks.count > 1 {
					let pageBreak = blockGroup.splitGroup(remainingSpace: remainingSpace)

				} else {
					let block = blockGroup.blocks.first!
					let pageBreak = block.splitBlock(remainingSpace: remainingSpace)
					addPage(currentPage!, onCurrentPage: pageBreak.0, onNextPage: pageBreak.1)
				}
			
				//... also add a page break here
			}
		}
		
		// The loop has ended.
		pages.append(currentPage!)
	}

	func addPageBreak(element:Line, position:Int, type:String) {
		print("Implement live pagination page breaks")
	}
	
	func addPage(_ page:BeatPageView2, onCurrentPage:[Line], onNextPage:[Line]) {
		// Add elements on the current page
		let prevPageBlock = BeatPageBlock(block: onCurrentPage, delegate: self)
		page.addBlock(prevPageBlock)
		pages.append(page)
		
		// Create a new page and add the rest on that one
		currentPage = BeatPageView2(delegate: self)
		let nextPageBlock = BeatPageBlock(block: onNextPage, delegate: self)
		currentPage!.addBlock(nextPageBlock)
	}
	
	/// Returns the screenplay block for the given line
	func blocksFor(lineAtIndex:Int) -> [[Line]] {
		let line = lines[lineAtIndex]
		var block = [line]
		
		if line.isAnyCharacter() {
			return [dialogueBlock(forLineAtIndex: lineAtIndex)]
		}
		else if line == self.lines.last { return [block] }
		else if line.type != .heading && line.type != .lyrics && line.type != .centered && line.type != .shot { return [block] }
		
		var idx = lineAtIndex + 1
		let nextLine = lines[idx]
		
		// Headings and shots swallow up the whole following block
		if (line.type == .heading || line.type == .shot) &&
			nextLine.type != .heading && nextLine.type != .shot {
			let followingBlock = blocksFor(lineAtIndex: idx).first!
			return [block, followingBlock]
		}
		
		let expectedType:LineType
		if line.type == .lyrics || line.type == .centered { expectedType = line.type }
		else { expectedType = .action }

		// Start from next index
		idx += 1
		while idx < lines.count {
			let l = lines[idx]
			idx += 1
			
			// Skip empty lines, and break when the next line type is not the one we expected
			if l.type == .empty || l.string.count == 0 { continue }
			if l.type == expectedType {
				if l.beginsNewVisualBlock { break } // centered and lyric elements might begin a new block
				block.append(l)
			} else {
				break
			}
		}
		
		return [block]
	}
	
	/// Returns dialogue block for the given line
	func dialogueBlock(forLineAtIndex idx:Int) -> [Line] {
		let line = self.lines[idx]
		var block = [line]
		var i = idx + 1
		
		var isDualDialogue = false
		while (i < lines.count) {
			let l = lines[i]
			i += 1
			
			if l.type == .character { break }
			else if !l.isDialogue() && !l.isDualDialogue() { break }
			else if l.isDualDialogue() { isDualDialogue = true }
			else if isDualDialogue && (l.isDialogue() || l.type == .dualDialogueCharacter) { break }
			
			block.append(l)
		}
		
		return block
	}
	
	/// Shorthand for a basic text block
	class func createTextBlock(width:CGFloat) -> NSTextBlock {
		let block = NSTextBlock()
		block.setContentWidth(width, type: .absoluteValueType)
		return block
	}
	
	/// Return the line height
	class func lineHeight() -> CGFloat {
		return 13.0
	}
	
	/// Returns a `Line` element for character cue, extended by user-defined equivalent for `(CONT'D)`
	class func contdLine(for line:Line) -> Line {
		let charExtension = BeatRenderer2.contdString()
		var cue = line.stripFormatting().replacingOccurrences(strings: [charExtension])
		cue = cue.trimmingCharacters(in: .whitespaces) + charExtension
		
		let cueLine = Line(string: cue, type: line.type, pageSplit: true)!
		return cueLine
	}
	
	/// Returns a `Line` element for `(MORE)`, with user-defined word
	class func moreLine(for line:Line) -> Line {
		let moreString = BeatRenderer2.moreString()
		let moreLine = Line(string: moreString, type: (line.isDualDialogue()) ? .dualDialogueMore : .more, pageSplit: true)!
		
		return moreLine
	}
	
	class func moreString() -> String {
		let moreString = BeatUserDefaults.shared().get("screenplayItemMore") as! String
		return "(" + moreString + ")"
	}
	
	class func contdString() -> String {
		let contdString = BeatUserDefaults.shared().get("screenplayItemContd") as! String
		return " (" + contdString + ")"
	}
}


// MARK: - Page view
/**
 Page view is a `NSView` / `UIView` with a `NSTextView`/`UITextView` inside it.
 A page object holds references to the blocks that have been added on it, and the attributed string is
 rendered based on content of those blocks.
 */
class BeatPageView2:NSView {
	var fonts = BeatFonts.shared()
	var textView:NSTextView
	var headerView:NSTextView
	var pageStyle:RenderStyle
	var paperSize:BeatPaperSize
	var maxHeight = 0.0
	var blocks:[BeatPageBlock] = []
	
	
	var linePadding = 10.0
	
	weak var delegate:BeatPageViewDelegate?
	
	var styles:Styles { get { return delegate!.styles } }
	override var isFlipped: Bool { get { return true } }
	
	init(delegate:BeatPageViewDelegate) {
		self.delegate = delegate
		self.pageStyle = delegate.styles.page()
		
		// Paper size flag
		self.paperSize = delegate.settings.paperSize
				
		// Actual paper size in points
		let size:CGSize
		if delegate.settings.paperSize == .A4 { size = BeatPaperSizing.a4() }
		else { size = BeatPaperSizing.usLetter() }
	
		// Text view height
		// Max height for content. Subtract two lines to make space for page number and header.
		self.maxHeight = size.height - self.pageStyle.marginTop - self.pageStyle.marginBottom - BeatRenderer2.lineHeight() * 2
		
		
		// Create a content text view inside the page
		self.textView = NSTextView(
			frame: NSRect(x: self.pageStyle.marginLeft - linePadding * 2,
						  y: self.pageStyle.marginTop + BeatRenderer2.lineHeight() * 2,
						  width: size.width - self.pageStyle.marginLeft,
						  height: self.maxHeight)
		)
		self.textView.drawsBackground = true
		self.textView.backgroundColor = NSColor.white
				
		self.textView.textContainer!.lineFragmentPadding = linePadding
		self.textView.textContainerInset = NSSize(width: 0, height: 0)

		let layoutManager = BeatRenderLayoutManager()
		self.textView.textContainer?.replaceLayoutManager(layoutManager)
		self.textView.textContainer?.lineFragmentPadding = linePadding
		
		// Header view
		self.headerView = NSTextView(
			frame: NSRect(x: self.pageStyle.marginLeft - linePadding * 2,
						  y: self.pageStyle.marginTop,
						  width: size.width - self.pageStyle.marginLeft,
						  height: BeatRenderer2.lineHeight())
		)
		self.headerView.textContainerInset = NSSize(width: 0, height: 0)
		self.headerView.drawsBackground = true
		self.headerView.backgroundColor = NSColor.white
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		self.addSubview(textView)
		self.addSubview(headerView)
		
		// Force white background
		self.wantsLayer = true
		self.layer?.backgroundColor = NSColor.white.cgColor
		
		// Add page number
		headerView.textStorage?.append(self.pageNumberBlock())
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func clear() {
		self.textView.string = ""
	}
		
	var height:CGFloat { get {
		return self.textView.textStorage?.height(containerWidth: self.textView.textContainer?.size.width ?? 0) ?? 0
	} }
	
	// MARK: Get items represented by this page
	var lines:[Line] { get {
		var lines:[Line] = []
		for block in self.blocks {
			lines.append(contentsOf: block.lines)
		}
		
		return lines
	} }
	
	var representedRange:NSRange { get {
		let representedLines = self.lines
		
		let loc = representedLines.first?.position ?? NSNotFound
		let len = NSMaxRange(representedLines.last?.range() ?? NSMakeRange(0, 0)) - Int(representedLines.first?.position ?? 0)
		
		print("Represented range for page: ", NSRange(location: loc, length: len))
		
		return NSRange(location: loc, length: len)
	} }
	
	
	// MARK: Calculate remaining space
	var remainingSpace:CGFloat { get {
		let _ = self.textView.layoutManager!.glyphRange(for: textView.textContainer!)
		let bounds = self.textView.layoutManager!.usedRect(for: textView.textContainer!)
		let space = maxHeight - bounds.height
		
		return space
	} }
		
	var count:Int {
		get { return self.blocks.count }
	}
	
	// Does this block fit on current page?
	/*
	func fitsOnPage(_ block:BeatPageBlock) -> Bool {
		let height = block.height
		
		if height <= self.remainingSpace {
			return true
		} else {
			return false
		}
	}
	*/
	 
	// Add a whole block
	func addBlock(_ block:BeatPageBlock) {
		if self.blocks.count == 0 {
			// No top margin for this block
			block.setTopMargin(0)
		}
		
		self.blocks.append(block)
		self.textView.textStorage!.append(block.attributedString)
	}
	
	func pageNumberBlock() -> NSAttributedString {
		if self.delegate == nil { print("Page number: No delegate set"); return NSAttributedString(string: "n/a"); }
		
		let pageIndex = self.delegate!.pages.firstIndex(of: self) ?? NSNotFound
		var pageNumber = 0
										
		if pageIndex != NSNotFound {
			pageNumber = pageIndex + 1
		} else {
			pageNumber = self.delegate!.pages.count
		}
		
		let table = NSTextTable()
		//table.hidesEmptyCells = false
		//table.setContentWidth(500, type: .absoluteValueType)
		
		let leftCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
		let headerCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 1, columnSpan: 1)
		let rightCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 2, columnSpan: 1)
		
//		leftCell.backgroundColor = NSColor.red
//		headerCell.backgroundColor = NSColor.green
//		rightCell.backgroundColor = NSColor.blue
		
		leftCell.setContentWidth(15, type: .percentageValueType)
		headerCell.setContentWidth(70, type: .percentageValueType)
		rightCell.setContentWidth(15, type: .percentageValueType)
				
		let leftStyle = NSMutableParagraphStyle()
		leftStyle.textBlocks = [leftCell]
		
		let headerStyle = NSMutableParagraphStyle()
		headerStyle.alignment = .center
		headerStyle.textBlocks = [headerCell]
		
		let rightStyle = NSMutableParagraphStyle()
		rightStyle.alignment = .right
		rightStyle.textBlocks = [rightCell]
		
		let leftContent = NSMutableAttributedString(string: " \n", attributes: [
			NSAttributedString.Key.paragraphStyle: leftStyle
		])
		
		let headerContent = NSMutableAttributedString(string: delegate!.settings.header + "\n", attributes: [
			NSAttributedString.Key.font: self.fonts.courier,
			NSAttributedString.Key.foregroundColor: NSColor.black,
			NSAttributedString.Key.paragraphStyle: headerStyle
		])
		
		// No page number for the first page
		let pageNumberContent = NSMutableAttributedString(string: (pageNumber > 0) ? "\(pageNumber)." : "  ", attributes: [
			NSAttributedString.Key.font: self.fonts.courier,
			NSAttributedString.Key.foregroundColor: NSColor.black,
			NSAttributedString.Key.paragraphStyle: rightStyle
		])
		
		leftContent.append(headerContent)
		leftContent.append(pageNumberContent)
		
		return leftContent
	}
}


// Layout manager for displaying revisions

class BeatRenderLayoutManager:NSLayoutManager {
	override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
		super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
				
		let container = self.textContainers.first!
	
		NSGraphicsContext.saveGraphicsState()
		
		self.enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, range, stop in
			let markerRect = NSMakeRect(container.size.width - 50, usedRect.origin.y, 15, rect.size.height)
			
			var highestRevision = ""
			self.textStorage?.enumerateAttribute(NSAttributedString.Key(BeatRevisions.attributeKey()), in: range, using: { obj, attrRange, stop in
				if (obj == nil) { return }
				
				let revision = obj as! String
				
				if highestRevision == "" {
					highestRevision = revision
				}
				else if BeatRevisions.isNewer(revision, than: highestRevision) {
					highestRevision = revision
				}
			})
			
			if highestRevision == "" { return }
			
			let marker:NSString = BeatRevisions.revisionMarkers()[highestRevision]! as NSString
			let font = BeatFonts.shared().courier
			marker.draw(at: markerRect.origin, withAttributes: [
				NSAttributedString.Key.font: font,
				NSAttributedString.Key.foregroundColor: NSColor.black
			])
		}
		
		NSGraphicsContext.restoreGraphicsState()
	}
}


// MARK: - Rendered elements

// MARK: Line element

/// A representation of a single line of screenplay, rendered as `NSAttributedString`
class BeatPageElement:NSObject {
	var line:Line
	var paperSize:BeatPaperSize
	var renderedString:NSMutableAttributedString?
	var dualDialogue = false
	
	weak var styles:Styles?
	weak var delegate:BeatPageViewDelegate?
	
	init(line:Line, delegate:BeatPageViewDelegate?, dualDialogue:Bool) {
		self.line = line
		self.paperSize = delegate?.settings.paperSize ?? .A4
		self.delegate = delegate
		self.styles = delegate?.styles ?? Styles.shared
		self.dualDialogue = dualDialogue
				
		if delegate == nil { print("Warning: Page delegate missing") }
	}
	
	convenience init(line:Line, delegate:BeatPageViewDelegate?) {
		self.init(line: line, delegate: delegate, dualDialogue: false)
	}
	
	/// Forces the top margin
	func setTopMargin(_ margin:CGFloat) {
		let attrStr = self.attributedString
		let result = NSMutableAttributedString(attributedString: attrStr)
		
		attrStr.enumerateAttribute(NSAttributedString.Key.paragraphStyle, in: attrStr.range) { value, range, stop in
			if (value == nil) { return }
			let pStyle = value as! NSMutableParagraphStyle
			
			pStyle.paragraphSpacingBefore = margin
			result.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: range)
		}
		
		self.renderedString = result
	}
	
	var attributedString:NSAttributedString { get {
		if (self.renderedString != nil) {
			return self.renderedString!
		} else {
			return self.render()
		}
	} }
	
	var topMargin:CGFloat { get {
		var topMargin = 0.0
		let pStyle = self.attributedString.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
		topMargin = pStyle.paragraphSpacingBefore
		
		return topMargin
	} }
	
	var height:CGFloat { get {
		// NOTE: The container width here is quite arbitrary.
		// Elements should have a width set, and if not, they inherit the default width for their paper size.
		// We are using the wider US Letter here just in case.
		
		var attrStr = self.attributedString
		if attrStr.string.last! == Character("\n") {
			attrStr = attrStr.attributedSubstring(from: NSMakeRange(0, attrStr.length - 1))
		}
		return attrStr.height(containerWidth: 612) + self.topMargin
	} }
	
	func render() -> NSAttributedString {
		var attrStr = NSMutableAttributedString(attributedString: line.attributedStringForFDX())
		
		let styleName = line.typeAsString() ?? "action"
		var style = styles!.forElement(styleName)
		
		// Make the string uppercase if needed
		if style.uppercase { attrStr = NSMutableAttributedString(attributedString: attrStr.uppercased()) }
		
		// If this is part of a dual dialogue block, we'll use dual dialogue styles for both sides.
		// In parser, the first block dialogue is always "normal" dialogue.
		if (self.dualDialogue) {
			if (line.isAnyCharacter()) { style = styles!.forElement("DD Character") }
			else if (line.isAnyParenthetical()) { style = styles!.forElement("DD Parenthetical") }
			else if (line.isAnyDialogue()) { style = styles!.forElement("DD Dialogue") }
			else if (line.type == .more || line.type == .dualDialogueMore) { style = styles!.forElement("DD More") }
		}
		
		// Set element width
		var width = (paperSize == .A4) ? style.widthA4 : style.widthLetter
		if width == 0 {
			width = (paperSize == .A4) ? styles!.page().defaultWidthA4 : styles!.page().defaultWidthLetter
		}

		// Tag the line with corresponding element
		attrStr.addAttribute(NSAttributedString.Key("RepresentedLine"), value: line, range: attrStr.range)
		
		// Add a line break at the end when rendering
		attrStr.append(NSAttributedString(string: "\n"))
		
		// Stylize
		let fonts = BeatFonts.shared()
		var font = fonts.courier
		
		// Block width. Dual dialogue blocks DO NOT get the page indent
		var blockWidth = width + style.marginLeft
		if (!dualDialogue) { blockWidth += styles!.page().contentPadding }
		
		// Create the block
		let textBlock = BeatRenderer2.createTextBlock(width: blockWidth)
		
		if style.italic && style.bold { font = fonts.boldCourier }
		else if style.italic { font = fonts.italicCourier }
		else if style.bold { font = fonts.boldCourier }
				
		attrStr.addAttribute(NSAttributedString.Key.font, value: font, range: attrStr.range)
		
		attrStr.enumerateAttributes(in: attrStr.range) { attrs, range, stop in
			let styleStr:String = attrs[NSMutableAttributedString.Key("Style")] as? String ?? ""
			let styleNames = styleStr.components(separatedBy: ",")
			
			if styleNames.contains("Bold") {
				attrStr.applyFontTraits(.boldFontMask, range: range)
			}
			if styleNames.contains("Italic") {
				attrStr.applyFontTraits(.italicFontMask, range: range)
			}
			if styleNames.contains("Underline") {
				attrStr.addAttribute(NSAttributedString.Key.underlineStyle, value: NSNumber(value: 1), range: range)
				attrStr.addAttribute(NSAttributedString.Key.underlineColor, value: NSColor.black, range: range)
			}
		}
		
		let pStyle = NSMutableParagraphStyle()
		
		pStyle.maximumLineHeight = BeatRenderer2.lineHeight()
		pStyle.paragraphSpacingBefore = style.marginTop
		pStyle.paragraphSpacing = style.marginBottom
		pStyle.tailIndent = -1 * style.marginRight // Negative value
		
		if !dualDialogue {
			pStyle.firstLineHeadIndent = style.marginLeft + styles!.page().contentPadding
			pStyle.headIndent = style.marginLeft + styles!.page().contentPadding
		} else {
			pStyle.firstLineHeadIndent = style.marginLeft
			pStyle.headIndent = style.marginLeft
		}
		
		
		pStyle.textBlocks = [textBlock]
		
		// Text alignment
		if style.textAlign == "center" {
			pStyle.alignment = .center
		}
		else if style.textAlign == "right" {
			pStyle.alignment = .right
		}
		
		// Special rules for some blocks
		if (line.type == .lyrics || line.type == .centered) && !line.beginsNewVisualBlock {
			pStyle.paragraphSpacingBefore = 0
		}
		
		attrStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: attrStr.range)
		
		// Remove any invisible ranges
		let contentRanges:NSMutableIndexSet = NSMutableIndexSet(indexSet: line.contentRanges())
		contentRanges.add([attrStr.length - 1]) // Add the last index to include the newly-added line break
		var lineStr = NSMutableAttributedString(string: "")
		
		contentRanges.enumerateRanges { range, stop in
			if range.length == 0 { return }
			
			let content = attrStr.attributedSubstring(from: range)
			lineStr.append(content)
		}
		
		// Render heading block
		if line.type == .heading {
			lineStr = renderHeading(line: line, content: lineStr, styles: styles!)
		}
		
		self.renderedString = lineStr
		return lineStr
	}
	
	func renderHeading(line:Line, content:NSMutableAttributedString, styles:Styles) -> NSMutableAttributedString {
		let printSceneNumbers = self.delegate!.settings.printSceneNumbers
		
		let attrStr = NSMutableAttributedString(string: "")
		let table = NSTextTable()
		table.collapsesBorders = true
		
		let leftCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
		let contentCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 1, columnSpan: 1)
		let rightCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 2, columnSpan: 1)
		
		let width = (paperSize == .A4) ? styles.forElement(line.typeAsString()).widthA4 : styles.forElement(line.typeAsString()).widthLetter
		
		leftCell.setContentWidth(styles.page().contentPadding, type: .absoluteValueType)
		contentCell.setContentWidth(width, type: .absoluteValueType)
		rightCell.setContentWidth(styles.page().contentPadding - 12, type: .absoluteValueType)
		
//		leftCell.backgroundColor = NSColor.red
//		contentCell.backgroundColor = NSColor.green
//		rightCell.backgroundColor = NSColor.blue
		
		let contentPStyle:NSMutableParagraphStyle = content.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as! NSMutableParagraphStyle
		contentPStyle.headIndent = 0
		contentPStyle.firstLineHeadIndent = 0
		contentPStyle.textBlocks = [contentCell]
		content.addAttribute(NSAttributedString.Key.paragraphStyle, value: contentPStyle, range: content.range)
				
		let sceneNumberLeft = NSMutableAttributedString(string: ((printSceneNumbers) ? line.sceneNumber : " ") + "\n", attributes: [
			NSAttributedString.Key.font: BeatFonts.shared().courier,
			NSAttributedString.Key.foregroundColor: NSColor.black,
		])
		let sceneNumberRight = NSMutableAttributedString(attributedString: sceneNumberLeft)
		
		let sceneNumberLeftStyle = contentPStyle.mutableCopy() as! NSMutableParagraphStyle
		let sceneNumberRightStyle = contentPStyle.mutableCopy() as! NSMutableParagraphStyle
		
		sceneNumberLeftStyle.textBlocks = [leftCell]
		sceneNumberLeftStyle.paragraphSpacingBefore = contentPStyle.paragraphSpacingBefore
		sceneNumberLeftStyle.firstLineHeadIndent = 12.0
		
		sceneNumberRightStyle.textBlocks = [rightCell]
		sceneNumberRightStyle.paragraphSpacingBefore = contentPStyle.paragraphSpacingBefore
		sceneNumberRightStyle.alignment = .right
				
		sceneNumberLeft.addAttribute(NSAttributedString.Key.paragraphStyle, value: sceneNumberLeftStyle, range: sceneNumberLeft.range)
		sceneNumberRight.addAttribute(NSAttributedString.Key.paragraphStyle, value: sceneNumberRightStyle, range: sceneNumberRight.range)
		
		attrStr.append(sceneNumberLeft)
		attrStr.append(content)
		attrStr.append(sceneNumberRight)
		
		return attrStr
	}
}

// MARK: Block element

/// Represents a **block** of elements, such as dialogue, dual dialogue (the whole two-column block, divided into sub-blocks) or single action paragraphs
class BeatPageBlock:NSObject {
	var elements = [BeatPageElement]()
	var dualDialogueElement = false
	var dualDialogueBlock = false
	var lines = [Line]()
	var renderedString:NSAttributedString?
	var styles:Styles
	
	// Dual dialogue blocks
	var leftColumn:NSMutableAttributedString?
	var rightColumn:NSMutableAttributedString?
	
	weak var delegate:BeatPageViewDelegate?
	
	
	convenience init(block:[Line], delegate:BeatPageViewDelegate?) {
		self.init(block: block, isDualDialogueElement: false, delegate:delegate)
	}
	
	init(block:[Line], isDualDialogueElement:Bool, delegate:BeatPageViewDelegate?) {
		self.lines = block
		self.dualDialogueElement = isDualDialogueElement
		self.styles = Styles.shared
		self.delegate = delegate
		
		// Is this a dual dialogue block?
		if (!isDualDialogueElement) {
			for line in block {
				if line.type == .dualDialogueCharacter {
					dualDialogueBlock = true;
					break;
				}
			}
		}
		
		//_ = self.render()
	}
	
	var height:CGFloat { get {
		// NOTE: The container width here is quite arbitrary.
		// Elements should have a width set, and if not, they inherit the default width for their paper size.
		// We are using the wider US Letter here just in case.
		
		// Remove last newline to get the accurate height
		var str = self.attributedString
		if str.string.last == Character("\n") {
			str = self.attributedString.attributedSubstring(from: NSMakeRange(0, str.length - 1))
		}
		
		return str.height(containerWidth: 612)
	} }
	
	var attributedString:NSAttributedString { get {
		if (renderedString == nil) {
			return render()
		} else {
			return renderedString!
		}
	} }
	
	/// Force top margin for this element and invalidate the rendered string
	func setTopMargin(_ margin:CGFloat) {
		if self.elements.count == 0 { return }
		
		if !self.dualDialogueBlock {
			self.elements.first!.setTopMargin(0)
			refresh()
		}
	}
	
	/// Create and render the individual line elements
	func render() -> NSAttributedString {
		if self.delegate == nil {
			print("DELEGATE MISSING")
		}
		
		// Nil dual dialogue stuff
		self.leftColumn = nil
		self.rightColumn = nil
				
		let attributedString = NSMutableAttributedString(string: "")
		self.elements = []

		if dualDialogueBlock {
			self.renderedString = renderDualDialogue()
			return self.renderedString!
		}
		
		for line in self.lines {
			let element = BeatPageElement(line: line, delegate: self.delegate, dualDialogue: self.dualDialogueElement)
			self.elements.append(element)
			attributedString.append(element.attributedString)
		}
		
		// Store the rendered string
		self.renderedString = attributedString
		return attributedString
	}
	
	/// This only refreshes the attributed string without flushing the elements
	func refresh() {
		let attrStr = NSMutableAttributedString(string: "")
		for element in elements {
			attrStr.append(element.attributedString)
		}
		
		self.renderedString = attrStr
	}
	
	/// Render a block with left/right columns. This block will know the contents of both columns.
	func renderDualDialogue() -> NSAttributedString {
		// Dread lightly
		
		let left = self.leftColumnLines
		let right = self.rightColumnLines
				
		let leftBlock = BeatPageBlock(block: left, isDualDialogueElement: true, delegate: self.delegate)
		let rightBlock = BeatPageBlock(block: right, isDualDialogueElement: true, delegate: self.delegate)
		
		self.elements = []
		self.elements.append(contentsOf: leftBlock.elements)
		self.elements.append(contentsOf: rightBlock.elements)
		
		// Initialize table
		let table = NSTextTable()
		let width = (delegate?.settings.paperSize ?? .A4 == .A4) ? styles.page().defaultWidthA4 : styles.page().defaultWidthLetter
				
		table.setContentWidth(width + styles.page().contentPadding, type: .absoluteValueType)
		table.numberOfColumns = 2
		
		// Create cells
		let leftCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
		let rightCell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 1, columnSpan: 1)
		leftCell.setContentWidth(55.0, type: .percentageValueType)
		rightCell.setContentWidth(45.0, type: .percentageValueType)
		
		// Render content for left/right cells
		var leftContent = NSMutableAttributedString(attributedString: leftBlock.attributedString)
		let rightContent = NSMutableAttributedString(attributedString: rightBlock.attributedString)
		
		// If there is nothing in the left column, we need to create a placeholder
		if leftContent.length == 0 {
			let p = NSMutableParagraphStyle()
			leftContent = NSMutableAttributedString(string: " \n")
			leftContent.addAttribute(NSAttributedString.Key.paragraphStyle, value: p, range: leftContent.range)
		}
		
		// Create new styles for cells
		let leftStyle = NSMutableParagraphStyle()
		let rightStyle = NSMutableParagraphStyle()
		leftStyle.textBlocks = [leftCell]
		rightStyle.textBlocks = [rightCell]
		
//		leftCell.backgroundColor = NSColor.red
//		rightCell.backgroundColor = NSColor.blue
		
		// Enumerate the paragraph styles inside left/right column content, and set the cell as their text block
		leftContent.enumerateAttribute(NSAttributedString.Key.paragraphStyle, in: leftContent.range) { val, range, stop in
			let paragraphStyle = val as? NSMutableParagraphStyle ?? nil
			if paragraphStyle == nil { return }
			
			paragraphStyle?.headIndent += styles.page().contentPadding
			paragraphStyle?.firstLineHeadIndent += styles.page().contentPadding
			paragraphStyle?.textBlocks = [leftCell]
		}
		rightContent.enumerateAttribute(NSAttributedString.Key.paragraphStyle, in: rightContent.range) { val, range, stop in
			let paragraphStyle = val as? NSMutableParagraphStyle ?? nil
			if paragraphStyle == nil { return }
			
			paragraphStyle?.textBlocks = [rightCell]
		}

		// Store the rendered strings
		self.leftColumn = NSMutableAttributedString(attributedString: leftContent)
		self.rightColumn = NSMutableAttributedString(attributedString: rightContent)
		
		// Join the attributed strings
		leftContent.append(rightContent)
		
		return leftContent
	}
	
	// TODO: Join these into one
	var leftColumnLines:[Line] { get {
		var leftColumn = [Line]()
		for line in lines {
			if line.isDialogue() {
				leftColumn.append(line)
			}
			else if line.type == .dualDialogueCharacter {
				break
			}
		}
		
		return leftColumn
	} }
	
	var rightColumnLines:[Line] { get {
		var rightColumn = [Line]()
		for line in lines {
			if !line.isDualDialogue() {
				continue
			} else {
				rightColumn.append(line)
			}
		}
		return rightColumn
	} }
	
	
	// MARK: Convenience methods
	
	func elementAt(y:CGFloat) -> BeatPageElement? {
		var height:CGFloat = 0.0
		
		for element in elements {
			height += element.height
			if height >= y { return element }
		}
		
		return nil
	}
	
	func elementFor(line:Line) -> Line? {
		for element in elements {
			if element.line == line { return element.line }
		}
		return nil
	}
	
	
	func heightUntil(line:Line) -> CGFloat {
		var height = 0.0

		for element in self.elements {
			if element.line == line {
				break
			}
			height += element.height
		}
		
		return height
	}
	
	// MARK: Find spiller
	func findSpiller(atHeight height:CGFloat) -> BeatPageElement? {
		var h = 0.0
		
		for element in elements {
			h += element.height
			if h >= height {
				return element
			}
		}
		
		return nil
	}
	
	func layoutManagerForCalculation(string:NSAttributedString) -> NSLayoutManager {
		let textStorage = NSTextStorage(attributedString: string)
		let layoutManager = NSLayoutManager()
		let textContainer = NSTextContainer()
		
		textContainer.size = NSSize(width: 612.0, height: .greatestFiniteMagnitude)
		textContainer.lineFragmentPadding = 0
		
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		
		// Calculate size
		layoutManager.glyphRange(for: textContainer)
		
		return layoutManager
	}
}

// MARK: - Extension for breaking dialogue across pages
extension BeatPageBlock {
	func splitDualDialogueBlock(remainingSpace:CGFloat) -> ([Line], [Line]) {
		print("### BEGIN DUAL DIALOGUE PAGE BREAK ###")
		
		// Get the lines for each column
		let left = self.leftColumnLines
		let right = self.rightColumnLines
		
		// Create the elements for them (we could remove the overlapping creation by caching these, save some milliseconds)
		let leftBlock = BeatPageBlock(block: left, isDualDialogueElement: true, delegate: self.delegate!)
		let rightBlock = BeatPageBlock(block: right, isDualDialogueElement: true, delegate: self.delegate!)
		
		// Split the blocks
		let splitLeft = leftBlock.splitBlock(remainingSpace: remainingSpace)
		let splitRight = rightBlock.splitBlock(remainingSpace: remainingSpace)
		
		var onThisPage:[Line] = []
		var onNextPage:[Line] = []
		
		// Both sides need to have something left for us to paginate this
		if splitLeft.0.count > 0 && splitRight.0.count > 0 {
			onThisPage.append(contentsOf: splitLeft.0)
			onThisPage.append(contentsOf: splitRight.0)
			
			if splitLeft.1.count > 0 {
				onNextPage.append(contentsOf: splitLeft.1)
			}
			if splitRight.1.count > 0 {
				onNextPage.append(contentsOf: splitRight.1)
			}
		}
		
		// Otherwise, just push the whole block on next page
		else {
			onNextPage.append(contentsOf: left)
			onNextPage.append(contentsOf: right)
		}
				
		return (onThisPage, onNextPage)
	}
	
	/// Splits the block based on remaining space. Returns `[thisPage], [nextPage], pageBreak`
	func splitBlock(remainingSpace:CGFloat) -> ([Line], [Line]) {
		// This doesn't work unless we've rendered the line
		if (self.renderedString == nil) { _ = self.render() }
		
		// Dual dialogue requires a different logic
		if self.dualDialogueBlock {
			return splitDualDialogueBlock(remainingSpace: remainingSpace)
		}
		
		// Actual elements that point to screenplay objects
		var onThisPage:[Line] = []
		var onNextPage:[Line] = []
		
		// Temporary elements created while paginating, such as (MORE) and CHARACTER (CONT'D)
		var tmpThisPage:[Line] = []
		var tmpNextPage:[Line] = []
				
		let removedIndices = NSMutableIndexSet()
		
		// Find out the indices in which we can break the block apart.
		// When breaking a dual dialogue element, it's possible that the other side fits,
		// which means we don't get a valid index. In that case, let's suggest that we
		// leave this dialogue block on the original page.
		let splittableIndex = self.splittableIndex(remainingSpace: remainingSpace)
		if splittableIndex == NSNotFound {
			return (self.lines, [])
		}
		
		// Get the element that overlows
		// let spiller = self.elements[splittableIndex]
		
		// The element at this index
		let el = self.elements[splittableIndex]
				
		// Actions and dialogue lines can be be broken in two
		if el.line.type == .action {
			// Break paragraphs in two (if possible)
			let split = splitParagraph(element: el, remainingSpace: remainingSpace - self.heightUntil(line: el.line))
			
			// Make a note that this element was replaced with something else
			removedIndices.add(splittableIndex)
			
			if (split.0!.length > 0) {
				tmpThisPage = [split.0!]
			}
			if (split.1!.length > 0) {
				tmpNextPage = [split.1!]
			}
		}
		else if el.line.isDialogueElement() || el.line.isDualDialogueElement() {
			// Break dialogue blocks in two.
			// This code is horrible and overlaps itself, but at this point I just want to get it working.
			// I'll figure out the rest later.
			// TODO: Clean up the branching if statements
			
			if el.line.isAnyDialogue() {
				// A line of dialogue
				// print("..... Remaining space", remainingSpace, " / height until spiller", self.heightUntil(line: el.line), " full height ", self.height)
				let split = self.splitDialogueElement(element: el, remainingSpace: remainingSpace - self.heightUntil(line: el.line))
				
				// Something was left on the current page
				if (split.0!.length > 0) {
					// Make a note that the spiller was replaced with something else
					removedIndices.add(splittableIndex)
					
					tmpThisPage.append(split.0!) 										// First part of the line
					
					// Add a character cue on next page if the dialogue line spans over there, OR if there are subsequent elements
					if (split.1!.length > 0 || splittableIndex < self.elements.count-1 ) {
						let originalCue = self.characterCue()							// Create a new character cue
						
						tmpThisPage.append(BeatRenderer2.moreLine(for: el.line))		// (MORE)
						tmpNextPage.append(BeatRenderer2.contdLine(for: originalCue)) 	// CHARACTER (CONT'D)
						if split.1!.length > 0 { tmpNextPage.append(split.1!) }			// Second part of the line, if applicable
					}
					
				} else {
					// Nothing was left, break the element on next page.
					// Check that the previous element is OK for us to split here. Otherwise we'll need to find a better spot.
					if self.possiblePageBreakIndices().contains(splittableIndex-1) {
						let range = splittableIndex..<self.lines.count
						removedIndices.add(in: NSMakeRange(splittableIndex, self.lines.count - splittableIndex))
						
						let originalCue = self.characterCue()
						
						tmpThisPage.append(BeatRenderer2.moreLine(for: el.line))		// (MORE)
						tmpNextPage.append(BeatRenderer2.contdLine(for: originalCue)) 	// CHARACTER (CONT'D)
						tmpNextPage.append(contentsOf: Array(self.lines[range]))		// Remainder of the block
					} else {
						let betterIndex = self.possiblePageBreakIndices().indexLessThanOrEqual(to: splittableIndex-1)
						if betterIndex == 0 { onNextPage = Array(self.lines) }
						else {
							let range = betterIndex..<self.lines.count
							removedIndices.add(in: NSMakeRange(betterIndex, self.lines.count - betterIndex))
							
							let originalCue = self.characterCue()
							
							tmpThisPage.append(BeatRenderer2.moreLine(for: el.line))		// (MORE)
							tmpNextPage.append(BeatRenderer2.contdLine(for: originalCue)) 	// CHARACTER (CONT'D)
							tmpNextPage.append(contentsOf: Array(self.lines[range]))		// Remainder of the block
						}
					}
				}

			} else {
				// Any other dialogue element (meaning parenthetical or character cue)
				if splittableIndex == 0 {
					// Move the whole block on next page
					removedIndices.add(in: NSMakeRange(0, self.lines.count - 1))
					tmpNextPage = Array(self.lines)
				} else {
					// Cut off at some other element, which means that there should be stuff left on the next page
					removedIndices.add(in: NSMakeRange(splittableIndex, self.lines.count - splittableIndex))
					
					let range = splittableIndex..<self.lines.count
					if range.count > 0 {
						let originalCue = self.characterCue()
						tmpThisPage.append(BeatRenderer2.moreLine(for: el.line)) 		// (MORE)
						tmpNextPage.append(BeatRenderer2.contdLine(for: originalCue)) 	// CHARACTER (CONT'D)
						tmpNextPage.append(contentsOf: Array(self.lines[range]))		// Remaining lines
					}
				}
			}
		}
		else {
			// Any other element will be thrown on the next page
			if splittableIndex == 0 {
				onNextPage = self.lines
			} else {
				onThisPage.append(contentsOf: self.lines[0..<splittableIndex-1])
				if self.lines.count-1 > splittableIndex {
					onNextPage.append(contentsOf: self.lines[splittableIndex+1..<self.lines.count])
				}
			}
		}
		
		// If we haven't predetermined the content for the pages, figure out what to put where
		if onNextPage.count == 0 && onThisPage.count == 0 {
			// Things that will be left on this page
			for i in 0..<splittableIndex+1 {
				if !removedIndices.contains(i) {
					onThisPage.append(self.lines[i])
				}
			}
			// Add temporarily created objects on this page
			onThisPage.append(contentsOf: tmpThisPage)
			
			// Add temporarily created objects on next page
			onNextPage.append(contentsOf: tmpNextPage)
			// Add rest of the stuff in this block on next page
			for i in splittableIndex..<self.lines.count {
				if !removedIndices.contains(i) {
					onNextPage.append(self.lines[i])
				}
			}
		}
		
		return (onThisPage, onNextPage)
	}
	
	func splittableIndex(remainingSpace:CGFloat) -> Int {
		let indices = self.possiblePageBreakIndices()
		let element = self.findSpiller(atHeight: remainingSpace)
		if (element == nil) { return NSNotFound }
		
		let idx = self.elements.firstIndex(of: element!) ?? 0
		
		let splittable = indices.indexLessThanOrEqual(to: idx)
		return splittable
	}
	
	func characterCue() -> Line {
		for element in self.elements {
			if element.line.isAnyCharacter() {
				return element.line
			}
		}
		
		return Line(string: "", type: self.lines.last!.isDualDialogue() ? .dualDialogueCharacter : .character, pageSplit: true)
	}

	// MARK: Break paragraph
	func splitParagraph(element:BeatPageElement, remainingSpace:CGFloat) -> (Line?, Line?, CGFloat) {
		// TODO: Return page break
		
		let attrStr = element.attributedString
		let remainingSpace = remainingSpace
		let lm = layoutManagerForCalculation(string: attrStr)
		
		var pageBreakPos:CGFloat = 0.0
		var length:Int = 0
		var height:CGFloat = 0.0
		
		lm.enumerateLineFragments(forGlyphRange: NSMakeRange(0, lm.numberOfGlyphs)) { rect, usedRect, container, range, stop in
			height += rect.height
			if height > remainingSpace {
				stop.pointee = true
				return
			} else {
				let charRange = lm.characterRange(forGlyphRange: range, actualGlyphRange: nil)
				length += charRange.length
				pageBreakPos += usedRect.height
			}
		}
		
		// Why do we do this? Well, mostly because of legacy reasons...... but also because....... I don't know.
		// I'll make some sense to the system after I get it working.
		let split:[Line] = element.line.splitAndFormatToFountain(at: length)
		return (split[0], split[1], pageBreakPos)
	}
	
	// MARK: Break a line of dialogue
	func splitDialogueElement(element:BeatPageElement, remainingSpace:CGFloat) -> (Line?, Line?, CGFloat) {
		print("Remaining space", remainingSpace)
		
		let regex = try! NSRegularExpression(pattern: "(.+?[\\.\\?\\!]+\\s*)")
		let attrStr = element.line.attrString!
		let matches:[NSTextCheckingResult] = regex.matches(in: attrStr.string, range: attrStr.range)
		var sentences:[String] = []
		
		// Gather the matches (is there a sensible way to do this in Swift, pre-macOS 13.0?)
		var length = 0
		for match in matches {
			let str = attrStr.string.substring(range: match.range)
			length += str.count
			sentences.append(str)
		}
		
		// Make sure we are not missing anything
		if length < element.attributedString.length {
			let str = attrStr.string.substring(range: NSMakeRange(length, attrStr.length - length))
			sentences.append(str)
		}
		
		var text = ""
		var breakLength = 0
		var breakPosition = 0.0
		
		for rawSentence in sentences {
			let sentence = String(rawSentence)
			text.append(sentence)
			
			let tmpLine = Line(string: text, type: .dialogue)
			let tmpElement = BeatPageElement(line: tmpLine!, delegate: self.delegate)
			if tmpElement.height < remainingSpace {
				breakLength = tmpLine!.length
				breakPosition += tmpElement.height
			} else {
				break
			}
		}
		
		let p = element.line.splitAndFormatToFountain(at: breakLength)!
		return (p[0], p[1], breakPosition)
	}
	
	func possiblePageBreakIndices() -> NSIndexSet {
		// We can *always* break at the first index
		var indices = NSMutableIndexSet(index: 0)
		
		let firstLine = self.elements.first!
		let unallowedIndices = NSMutableIndexSet()
		
		if firstLine.line.type == .heading || firstLine.line.type == .shot {
			// Can't break at the 2nd element
			unallowedIndices.add(1)
		}
		
		for i in 1..<self.elements.count {
			let element = self.elements[i]
			
			// Skip any unallowed index. In practice this is only the 2nd line after
			// a shot or scene heading but I'm just being future-proof.
			if (unallowedIndices.contains(i)) {
				continue
			}
			
			// Dialogue
			if (element.line.isAnyParenthetical() && i > 1) ||
				element.line.isAnyDialogue() {
				indices.add(i)
			}
			
			// Any other element
			else if !element.line.isDialogue() && !element.line.isDualDialogue() && element.line.type != .transitionLine {
				indices.add(i)
			}
		}
		
		return indices
	}
}

/**
 An intermediate object for pagination. Sometimes we'll want to group some blocks together
 and measure their total height, but still treat them as separate layout elements.
 Mostly this happens with blocks preceded by `heading` or `shot`
 */
class BeatBlockGroup {
	var blocks:[BeatPageBlock]
	
	init(blocks:[BeatPageBlock]) {
		self.blocks = blocks
	}
	
	var height:CGFloat { get {
		var h = 0.0
		for block in blocks {
			h += block.height
		}
		
		return h
	}}
	
	func splitGroup(remainingSpace:CGFloat) -> ([Line], [Line]) {
		var space = remainingSpace
		var passedBlocks:[BeatPageBlock] = []
		
		var onThisPage:[Line] = []
		var onNextPage:[Line] = []
		
		var idx = 0
		for block in self.blocks {
			let h = block.height
			
			if h < space {
				// This block fits
				passedBlocks.append(block)
				space -= h
				idx += 1
				continue
				
			} else {
				// Following block doesn't fit
				let pageBreak = block.splitBlock(remainingSpace: remainingSpace)
				
				if pageBreak.0.count > 0 {
					for passedBlock in passedBlocks { onThisPage.append(contentsOf: passedBlock.lines) }
					onThisPage.append(contentsOf: pageBreak.0)
				}
				
				if pageBreak.1.count > 0 {
					onNextPage.append(contentsOf: pageBreak.1)
				}
				
				if (block != blocks.last!) {
					for i in idx+1..<blocks.count {
						let b = blocks[i]
						onNextPage.append(contentsOf: b.lines)
					}
				}
				
				break
			}
		}
		
		return (onThisPage, onNextPage)
	}
}

struct BeatPageBreak {
	var y:Float
	var element:Line
	var reason:String = "None"
}


