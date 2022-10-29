//
//  BeatRenderer2.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatRenderer2:NSObject, BeatPageViewDelegate {
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
		
		let block = NSTextBlock()
		
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
	
}

class BeatPageView2:NSView {
	var fonts = BeatFonts.shared()
	var textView:NSTextView
	var pageStyle:RenderStyle
	var elements:[BeatPageElement] = []
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
		
		self.textView = NSTextView(
			frame: NSRect(x: pageStyles.marginLeft,
						  y: pageStyles.marginTop,
						  width: size.width - pageStyles.marginLeft,
						  height: size.height - pageStyles.marginTop - pageStyles.marginBottom)
		)
		
		// Create header for page numbers etc
		// ...
		self.pageStyle = self.delegate!.styles.forElement("page")
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		self.addSubview(textView)
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
		for el in self.elements {
			lines.append(el.line)
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
		var space = self.textView.textContainer!.size.height - self.height
		return space
	} }
	
	func remainingSpace(withBlock block:BeatBlock) -> CGFloat {
		var space = self.remainingSpace - block.frame.height
		
		// Remove top margin of the block from remaining space,
		// if there are elements on the page. Otherwise top margin is 0.
		if self.elements.count > 0 && block.elements.count > 0 {
			space -= block.marginTop
		}
		return space
	}
	
	var count:Int {
		get { return self.elements.count }
	}
	
	// Add a whole block

	func addBlock(_ block:BeatBlock2) {
		/*
		var frame = block.frame
		
		if (container.subviews.count > 0 && block.elements.count > 0) {
			// Add top margin if needed
			let topMargin = block.elements.first!.style.marginTop
			frame.origin.y += topMargin
		}
		
		frame.origin.y += self.y
		block.frame = frame
		
		container.addSubview(block)
		 */
		for line in block.lines {
			let position = self.textView.string.count
			let element = BeatPageElement(line: line, range: NSMakeRange(position, line.stripFormatting().count))
			
		}
	}
}


// MARK: - Rendered block

struct BeatPageElement {
	var line:Line
	var range:NSRange
}

/// A single block (either a paragraph or a larger block of stuff
struct BeatBlock2 {
	var lines:[Line]
	var dualDialogue = false
	
	var leftColumn:[Line] = []
	var rightColumn:[Line] = []
}
