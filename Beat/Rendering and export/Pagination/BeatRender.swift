//
//  BeatRenderPaginator.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatRenderer:NSObject, BeatPageViewDelegate {
	var lines = [Line]()
	var titlePageLines = [Line]()
	var livePagination = false
	var fonts = BeatFonts.shared()
	var settings:BeatExportSettings
	var styles:Styles = Styles.shared
	
	var titlePage:BeatPageView?
	var pages = [BeatPageView]()
	var currentPage:BeatPageView? = nil
	
	@objc init(document:Document, screenplay:BeatScreenplay, settings:BeatExportSettings, livePagination:Bool) {
		self.livePagination = livePagination
		self.lines = screenplay.lines
		self.titlePageLines = screenplay.titlePage
		self.settings = settings
		
		super.init()
	}
	
	var numberOfPages:Int {
		get {
			if pages.count == 0 { paginate() }
			return pages.count
		}
	}

	@objc func paginate() {
		paginate(fromIndex: 0)
	}
	
	@objc func pdf() {
		let pdf = PDFDocument()
		
		for page in pages {
			page.display()
			let data = page.dataWithPDF(inside: NSMakeRect(0, 0, page.frame.width, page.frame.height))
			let pdfPage = PDFPage(image: NSImage(data: data)!)!
			pdf.insert(pdfPage, at: pdf.pageCount)
		}
		
		let url = tempURL()
		pdf.write(to: url)
		NSWorkspace.shared.open(url)
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
		
		var tmpElements:[Line] = []
		
		if fromIndex == 0 {
			pages = []
			currentPage = BeatPageView(delegate: self)
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
			
			// Get the paragraph for current line and add it to temp element queue
			tmpElements = getBlockFor(itemAtIndex: i)

			let block = BeatBlock(lines: tmpElements, renderer: self, page: currentPage!, frame: NSZeroRect)
			
			if block.fitsOnPage(currentPage!) {
				// The block fits nicely on this page!
				currentPage!.addBlock(block)
				continue
			} else {
				// Later, we'll split this like in our previous life, but right now, let's just
				// drop the non-fitting block on next page.
				
				addPage(currentPage!, onCurrentPage: [], onNextPage: tmpElements)
				//... also add a page break here
			}
		}
		
		// The loop has ended.
		pages.append(currentPage!)
	}
	
	func addPageBreak(element:Line, position:Int, type:String) {
		print("Implement live pagination page breaks")
	}
		
	func addPage(_ page:BeatPageView, onCurrentPage:[Line], onNextPage:[Line]) {
		let paragraph = BeatBlock(lines: onCurrentPage, renderer: self, page: currentPage!, frame: NSZeroRect)
		page.addBlock(paragraph)
		pages.append(page)
		
		currentPage = BeatPageView(delegate: self)
		let newParagraph = BeatBlock(lines: onNextPage, renderer: self, page: currentPage!, frame: NSZeroRect)
		currentPage!.addBlock(newParagraph)
	}
	
	// MARK: Line lookup
	func getBlockFor(itemAtIndex idx:Int) -> [Line] {
		let line = lines[idx]
		let dualDialogue = line.nextElementIsDualDialogue
		var dualDialogueCharacters = 1
		
		var block = [Line]()
		block.append(line)
		
		// Some line types don't create a block
		if line.type == .transitionLine || line.type == .action || line.type == .lyrics {
			return block
		}
		
		for i in idx+1...lines.count-1 {
			let l = lines[i]
			
			if dualDialogue {
				if l.isDialogue() {
					if l.type == .character && dualDialogueCharacters < 1 {
						dualDialogueCharacters += 1
					}
					if (dualDialogueCharacters > 1) { break }
					block.append(l)
				}
				else if l.isDualDialogue() {
					if l.type == .dualDialogueCharacter { dualDialogueCharacters += 1 }
					if dualDialogueCharacters > 2 { break }
					block.append(l)
				} else {
					break
				}
			}
			else {
				if line.type == .character {
					if l.isDialogueElement() { block.append(l) }
					else { break }
				}
				else if line.type == .dualDialogueCharacter {
					if l.isDualDialogueElement() { block.append(l) }
					else { break }
				}
				else if line.type == .heading {
					if l != lines.last {
						block.append(contentsOf: getBlockFor(itemAtIndex: i))
						break;
					} else {
						break
					}
				}
			}
		}
		
		return block
	}
	
	
	// MARK: Live/Preview pagination helpers
	
	func pageAtIndex(_ idx:Int) -> BeatPageView? {
		if pages.count == 0 { paginate() }
		if pages.count == 0 || idx > pages.count - 1 {
			return nil
		}
		
		return pages[idx]
	}
	
	func findPageForPosition(position:Int) -> BeatPageView? {
		for page in pages {
			if NSLocationInRange(position, page.representedRange) {
				return page
			}
		}
		return nil
	}
	
	/// Returns `(page index, index of element on page)`
	func findSafePageFrom(position:Int, actualIndex:UnsafeMutablePointer<Int>) -> (Int, Int) {
		let currentPage = findPageForPosition(position: position)
		
		// No safe page found
		if (currentPage == nil) { return (NSNotFound, NSNotFound) }
		
		let pageIndex = pages.firstIndex(of: currentPage!)
		if pageIndex == NSNotFound { return (NSNotFound, NSNotFound) }
		
		for p in pageIndex!...0 {
			let page = pages[p]
			
			let firstLine = page.lines.first
			if firstLine == nil { return (NSNotFound, NSNotFound) }
			
			if !firstLine!.unsafeForPageBreak && p > 0 {
				let prevPage = pages[p - 1]
				var lastIndex = prevPage.count - 1
				
				while lastIndex >= 0 {
					let lastLine = prevPage.lines[lastIndex]
					if lastLine.type != .more && lastLine.type != .dualDialogueMore {
						return (p, NSMaxRange(lastLine.range()))
					}
					lastIndex -= 1
				}
			}
		}
		
		return (NSNotFound, NSNotFound)
	}
}


// MARK: - Rendered page

class BeatPageView:NSView {
	var fonts = BeatFonts.shared()
	var container:PageContainer
	var pageStyle:RenderStyle
	weak var delegate:BeatPageViewDelegate?
	
	var styles:Styles { get { return delegate!.styles } }
	override var isFlipped: Bool { get { return true } }
	
	init(delegate:BeatPageViewDelegate) {
		self.delegate = delegate
		
		let pageStyles = delegate.styles.page()
		let size:CGSize
		if delegate.settings.paperSize == .A4 { size = BeatPaperSizing.a4() }
		else { size = BeatPaperSizing.usLetter() }
		
		// Create a container inside the page
		self.container = PageContainer(
			frame: NSRect(x: pageStyles.marginLeft,
						  y: pageStyles.marginTop,
						  width: size.width - pageStyles.marginLeft,
						  height: size.height - pageStyles.marginTop - pageStyles.marginBottom)
		)
		
		// Create header for page numbers etc
		// ...
		self.pageStyle = self.delegate!.styles.forElement("page")
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		self.addSubview(container)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func clear() {
		for v in self.container.subviews {
			v.removeFromSuperview()
		}
	}
	
	var y:CGFloat { get {
		if self.container.subviews.count > 0 {
			let frame = self.container.subviews.last!.frame
			return frame.origin.y + frame.height
		} else {
			return 0.0
		}
	} }
	
	// MARK: Get items represented by this page
	var lines:[Line] { get {
		var lines:[Line] = []
		
		for block in self.subviews as! [BeatBlock] {
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
	func remainingSpace() -> CGFloat {
		var space = self.container.frame.height - y
		if self.container.subviews.count > 0 {
			space -= pageStyle.lineHeight
		}
		return space
	}
	
	func remainingSpace(withBlock block:BeatBlock) -> CGFloat {
		var space = self.container.frame.height - self.y - block.frame.height
		
		// Remove top margin of the block from remaining space,
		// if there are elements on the page. Otherwise top margin is 0.
		if self.container.subviews.count > 0 && block.elements.count > 0 {
			space -= block.marginTop
		}
		return space
	}
	
	var count:Int {
		get { return self.container.subviews.count }
	}
	
	// Add a whole block

	func addBlock(_ block:BeatBlock) {
		var frame = block.frame
		
		if (container.subviews.count > 0 && block.elements.count > 0) {
			// Add top margin if needed
			let topMargin = block.elements.first!.style.marginTop
			frame.origin.y += topMargin
		}
		
		frame.origin.y += self.y
		block.frame = frame
		
		container.addSubview(block)
	}
}

// MARK: - Rendered block

/// A single block (either a paragraph or a larger block of stuff
class BeatBlock:NSView {
	weak var renderer:BeatRenderer?
	weak var page:BeatPageView?
	weak var style:RenderStyle?
	var lines:[Line]
	var styles:Styles { get { return renderer!.styles } }
	var settings:BeatExportSettings { get { return renderer!.settings } }
	var fonts:BeatFonts = BeatFonts.shared()
	var dualDialogue = false
	
	var columnView = false
	var leftColumn:BeatBlockColumn?
	var rightColumn:BeatBlockColumn?
	
	override var isFlipped: Bool { get { return true } }
	
	/// Returns elements which represent an actual screenplay line, so scene numbers, revision markers etc. are excluded
	var elements:[BeatElement] { get {
		var items:[BeatElement] = []
		for subview in self.subviews {
			if subview is BeatElement {
				items.append(subview as! BeatElement)
			}
		}
		return items
	} }
	
	var marginTop:CGFloat { get {
		if lines.count == 0 { return 0.0 }
		else {
			return self.renderer!.styles.forElement(lines.first!.typeAsString()).marginTop
		}
	} }
	
	init(lines:[Line], renderer:BeatRenderer, page:BeatPageView, frame:NSRect) {
		self.lines = lines
		self.page = page
		self.renderer = renderer
		
		if self.lines.first?.nextElementIsDualDialogue ?? false { dualDialogue = true }
		
		// Make the initial width be either full size of the container, or the given rect
		let initialFrame = (frame != NSZeroRect) ? frame : NSRect(x: 0, y: 0, width:page.frame.size.width - page.pageStyle.paddingLeft , height: 0)
		super.init(frame: initialFrame)
		
		setupBlock()
	}
	
	func setupBlock() {
		for line in lines {
			addItem(line: line)
		}
		
		// Create the two columns if needed
		if dualDialogue {
			let dialogues = splitDualDialogueToSides(lines)
			
			leftColumn = BeatBlockColumn(lines: dialogues.0, forBlock: self)
			//leftColumn!.addItems(lines: dialogues.0)
			addSubview(leftColumn!)
			
			rightColumn =  BeatBlockColumn(lines: dialogues.1, forBlock: self)
			addSubview(rightColumn!)
		}
		
		var rect = self.frame
		rect.origin.x = page!.pageStyle.paddingLeft
		rect.size.height = self.y // set the height
		
		self.frame = rect
	}
	
	override init(frame frameRect: NSRect) {
		self.lines = []
		super.init(frame: frameRect)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	/// Returns the next `y` position inside the block (ie. the height of the contents at this point)
	var y:Double { get {
		if self.subviews.count > 0 {
			return self.subviews.last!.frame.height + self.subviews.last!.frame.origin.y
		} else {
			return 0.0
		}
	} }
	
	/// Adds all Line items as printable elements
	func addItem(line:Line) {
		let element = BeatElement(line: line, block: self)
		
		// Add any associated views
		for associatedView in element.associatedViews {
			addSubview(associatedView)
		}
		
		addSubview(element)
	}
	
	/// Adds multiple lines
	func addItems(lines:[Line]) {
		for line in lines {
			addItem(line: line)
		}
		
		var frame = self.frame
		frame.size.height = self.y
		self.frame = frame
	}
	
	/// Returns the `Element` which represents given line
	func elementForLine(_ line:Line) -> BeatElement? {
		for element in elements {
			if element.line == line {
				return element
			}
		}
		
		return nil
	}
	
	/// Test if this block fits on given page
	func fitsOnPage(_ page:BeatPageView) -> Bool {
		let remainingSpace = page.remainingSpace(withBlock: self)
		
		if (remainingSpace >= 0) {
			return true
		} else {
			return false
		}
	}
	
	func splitDualDialogueToSides(_ lines:[Line]) -> ([Line], [Line]) {
		var left = [Line]()
		var right = [Line]()
		
		for line in lines {
			if line.isDialogue() {
				left.append(line)
			} else {
				right.append(line)
			}
		}
		
		return (left, right)
	}
}

class BeatBlockColumn:BeatBlock {
	var block:BeatBlock
	override var renderer: BeatRenderer? { get { return block.renderer } set { block.renderer = newValue } }
	override var page: BeatPageView?  { get { return block.page } set { block.page = newValue } }
	
	init(lines:[Line], forBlock block:BeatBlock) {
		let frame = NSRect(x: 0, y: 0, width: block.frame.size.width / 2, height: 0)
		
		self.block = block
		super.init(frame:frame)
		self.lines = lines
		
		addItems(lines: lines)
	}
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: - Single element

class BeatElement:NSTextView {
	weak var parent:BeatBlock?
	var line:Line
	var style:RenderStyle!
	var associatedViews:[NSTextView] = []
	
	override var isFlipped: Bool { get { return true } }
	
	init(line:Line, block parent:BeatBlock) {
		self.line = line
		self.parent = parent
		
		// Get correct style
		self.style = parent.styles.forElement(line.typeAsString())
		
		// Actual width
		let width = (parent.settings.paperSize == .A4) ? self.style.widthA4 : self.style.widthLetter
				
		let textView = NSTextView(frame: NSMakeRect(0, parent.y, width, 13))
		super.init(frame: textView.frame, textContainer: textView.textContainer)
		
		// Setup the text view
		self.isSelectable = false
		self.isEditable = false
		self.isRichText = true
				
		let displayStr = displayedString(line: line)
		self.textStorage?.setAttributedString(displayStr)
		
		// Paragraph styles
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.lineHeightMultiple = 0.925
		paragraphStyle.lineHeightMultiple = 0.9
		
		if (self.style?.textAlign.count ?? 0 > 0) {
			let align = self.style!.textAlign.lowercased()
			
			if align == "center" { paragraphStyle.alignment = .center }
			else if align == "right" { paragraphStyle.alignment = .right }
		}
		if line.centered() { paragraphStyle.alignment = .center }
		
		// Apply styles
		self.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, self.string.count))
				
		// Only apply top margin if the block already has items
		var marginTop = 0.0
		if parent.elements.count > 0 { marginTop = self.style!.marginTop }
		
		let pageStyle = self.parent!.renderer!.styles.page()
		let origin = NSPoint(x: self.style!.marginLeft + pageStyle.paddingLeft, y: marginTop + parent.y)
		let size = NSSize(width: width, height: self.frame.height)
		self.frame = NSRect(origin: origin, size: size)
		
		// Calculate correct height and set frame
		self.layoutManager!.ensureLayout(for: self.textContainer!)
		let rect = self.layoutManager?.usedRect(for: self.textContainer!) ?? NSZeroRect
		self.frame = NSRect(origin: origin, size: NSSize(width: width, height: rect.height))
	}
	
	func displayedString(line:Line) -> NSAttributedString {
		// Fetch the attributed string. If it hasn't been created yet, line will handle it for us.
		let attrStr = line.attrString ?? NSAttributedString(string: "")
		// Create the actual string we're going to display
		let displayStr = NSMutableAttributedString(attributedString: attrStr)
		
		// Set default font face
		var baseFont = parent!.fonts.courier

		if (self.style != nil) {
			if self.style!.bold && self.style!.italic {
				baseFont = parent!.fonts.boldItalicCourier
			}
			else if self.style!.italic {
				baseFont = parent!.fonts.italicCourier
			}
			else if self.style!.bold {
				baseFont = parent!.fonts.boldCourier
			}
		}
		displayStr.addAttribute(.font, value: baseFont, range: NSMakeRange(0, displayStr.length))
		
		// Apply stylization
		attrStr.enumerateAttributes(in: attrStr.range) { attrs, range, stop in
			let attributeNames = attrs[NSAttributedString.Key.init(rawValue: "Style")] as? String
			if (attributeNames == nil) { return }
			
			if (attributeNames!.count > 0 && range.length > 0) {
				let styleArray:[String] = attributeNames!.components(separatedBy: ",")
				
				if (styleArray.contains("Bold") && styleArray.contains("Italic")) {
					displayStr.addAttribute(.font, value: parent!.fonts.boldItalicCourier, range: range)
				}
				else if (styleArray.contains("Italic")) {
					displayStr.addAttribute(.font, value: parent!.fonts.italicCourier, range: range)
				}
				else if (styleArray.contains("Bold")) {
					displayStr.addAttribute(.font, value: parent!.fonts.boldCourier, range: range)
				}
				
				if (styleArray.contains("Underline")) {
					displayStr.addAttribute(.underlineColor, value: NSColor.black, range: range)
					displayStr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single, range: range)
				}
			}
		}
						
		return displayStr
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

/*
class BeatAssociatedElement:BeatElement {
	enum BeatAssistingElementStyle:Int {
		case sceneNumber = 0, revisionMarker
	}
}
 */

