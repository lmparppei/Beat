//
//  BeatPaginationElements.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationElements.h"
#import "BeatFonts.h"

@protocol BeatPageDelegate <NSObject>
@property (nonatomic, readonly) BeatFonts *fonts;
@end

@interface BeatPaginationView ()
@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) NSMutableArray<BeatPaginationBlock*>* blocks;
@end

@implementation BeatPaginationView

@end

@implementation BeatPaginationBlock

@end

/*class BeatPagePrintView:NSView {
 override var isFlipped: Bool { return true }
	weak var previewController:BeatPreviewController?

}
class BeatPageView:NSObject {
	weak var delegate:BeatPageViewDelegate?
	
	var fonts = BeatFonts.shared()
	var textView:BeatPageTextView?

	var pageStyle:RenderStyle
	var paperSize:BeatPaperSize
	var maxHeight = 0.0
	var blocks:[BeatPageBlock] = []
	
	@objc var pageBreak:BeatPageBreak?
	
	var linePadding = 10.0
	var size:CGSize
	
	var titlePage = false
	var rendered = false
	
	var pageView:BeatPagePrintView?
	
	var styles:Styles { return delegate!.styles }
	
	convenience init(delegate:BeatPageViewDelegate) {
		self.init(delegate: delegate, titlePage: false)
	}
	
	init(delegate:BeatPageViewDelegate, titlePage:Bool) {
		self.delegate = delegate
		self.pageStyle = delegate.styles.page()
		self.titlePage = titlePage
				
		// Paper size flag
		self.paperSize = delegate.settings.paperSize
				
		// Actual paper size in points
		if delegate.settings.paperSize == .A4 { self.size = BeatPaperSizing.a4() }
		else { self.size = BeatPaperSizing.usLetter() }
		
		// Max height for content. Subtract two lines to make space for page number and header.
		self.maxHeight = size.height - self.pageStyle.marginTop - self.pageStyle.marginBottom - BeatRenderer.lineHeight() * 2
		
		super.init()
	}
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func clearUntil(line:Line) {
		let i = self.lines.firstIndex(of: line) ?? NSNotFound
		if i == NSNotFound { print("Renderer error: Line not found on page"); return; }
		
		var blocks:[BeatPageBlock] = []
		
		for block in self.blocks {
			if block.lines.contains(line) {
				break
			}
			blocks.append(block)
		}
		
		self.blocks = blocks
		self.invalidate()
	}
	
	func invalidate() {
		self.rendered = false
	}
	
	func forDisplay(previewController:BeatPreviewController?) -> BeatPagePrintView {
		autoreleasepool {
			self.render()
			
			let pageView = self.pageView!
			if (previewController != nil) { self.textView!.previewController = previewController }
			return pageView
		}
	}
	
	func forDisplay() -> BeatPagePrintView {
		return forDisplay(previewController: nil)
	}
	
	func render() {
		// Do nothing, if this page is already rendered
		if rendered { return }
		
		// Create view if needed
		if self.pageView == nil {
			self.pageView = BeatPagePrintView(frame: NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
			self.pageView?.canDrawConcurrently = true
			
			// Force white background
			self.pageView?.wantsLayer = true
			self.pageView?.layer?.backgroundColor = NSColor.white.cgColor
		}
		
		// Create a text view inside the page if needed
		if self.textView == nil {
			self.textView = BeatPageTextView(
				frame: NSRect(x: self.pageStyle.marginLeft - linePadding * 2,
							  y: self.pageStyle.marginTop,
							  width: size.width - self.pageStyle.marginLeft,
							  height: self.maxHeight)
			)
			self.textView!.drawsBackground = true
			self.textView!.backgroundColor = NSColor.white
			self.textView?.linkTextAttributes = [
				NSAttributedString.Key.font: self.delegate!.fonts.courier,
				NSAttributedString.Key.foregroundColor: NSColor.black,
				NSAttributedString.Key.cursor: NSCursor.pointingHand
			]
			self.textView?.displaysLinkToolTips = false
			self.textView?.isAutomaticLinkDetectionEnabled = false
			
			self.textView?.font = delegate!.fonts.courier
			
			self.textView!.textContainer!.lineFragmentPadding = linePadding
			self.textView!.textContainerInset = NSSize(width: 0, height: 0)
			
			let layoutManager = BeatRenderLayoutManager()
			self.textView!.textContainer?.replaceLayoutManager(layoutManager)
			self.textView!.textContainer?.lineFragmentPadding = linePadding
			
			textView?.backgroundColor = .white
			textView?.drawsBackground = true
			
			self.pageView?.addSubview(textView!)
		}
	
		// Clear text view
		textView?.string = ""
		
		let textStorage = self.textView!.textStorage
		
		// Header view
		if !titlePage {
			// Add page number
			textStorage?.append(self.pageNumberBlock())
		}
		
		// Render blocks on page
		for block in blocks {
			autoreleasepool {
				if block != blocks.first! {
					self.textView!.textStorage!.append(block.render())
				} else {
					self.textView!.textStorage!.append(block.render(firstElementOnPage: true))
				}
			}
		}
						
		self.rendered = true
	}
	
	func clear() {
		self.textView!.string = ""
	}
	
	// MARK: Add block on page
	
	// Add a whole block
	func addBlock(_ block:BeatPageBlock) {
		if self.pageBreak == nil && block.lines.first != nil {
			// No page break set, let's make it the first object
			let line = block.lines.first!
			if !line.unsafeForPageBreak { self.pageBreak = BeatPageBreak(y: 0, element: line) }
		}
		
		self.blocks.append(block)
	}
		
	// MARK: Get items represented by this page
	var lines:[Line] {
		var lines:[Line] = []
		for block in self.blocks {
			lines.append(contentsOf: block.lines)
		}
		
		return lines
	}
		
	// MARK: Convenience methods
	
	var renderedContentHeight:CGFloat {
		self.render()
		let _ = self.textView!.layoutManager!.glyphRange(for: textView!.textContainer!)
		let bounds = self.textView!.layoutManager!.usedRect(for: textView!.textContainer!)
		return bounds.height

		//return self.textView!.textStorage?.height(containerWidth: self.textView!.textContainer?.size.width ?? 0) ?? 0
	}
	
	var representedRange:NSRange {
		let representedLines = self.lines
		
		let loc = representedLines.first?.position ?? NSNotFound
		let len = NSMaxRange(representedLines.last?.range() ?? NSMakeRange(0, 0)) - Int(representedLines.first?.position ?? 0)
		
		return NSRange(location: loc, length: len)
	}
	
	
	// MARK: Calculate remaining space
	var numberOfGlyphs:Int = 0
	var remainingSpace:CGFloat {
		// You can use renderedContentHeight below for calculating the **ACTUAL** content height.
		// Use only for double-checking values when debugging.
		// let actualSpace = maxHeight - self.renderedContentHeight

		var h = 0.0
		for block in blocks {
			let blockHeight = block.height
			h += blockHeight
		}
		
		return maxHeight - h
	}
		
	var count:Int {
		get { return self.blocks.count }
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
		
		leftCell.backgroundColor = NSColor.red
		headerCell.backgroundColor = NSColor.green
		rightCell.backgroundColor = NSColor.blue
		
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
		rightStyle.paragraphSpacing = BeatRenderer.lineHeight()
		
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
	
	// MARK: Finding elements on page
	
	func indexForLine(at position:Int) -> Int {
		// Iterate elements backwards
		var lineIdx = self.lines.count - 1
		while lineIdx >= 0 {
			let l = self.lines[lineIdx]
			
			if NSLocationInRange(position, l.range()) || position > NSMaxRange(l.range()) {
				return lineIdx
			}
			else if lineIdx == 0 {
				return 0
			}
			
			lineIdx -= 1
		}
		
		return NSNotFound
	}
	
	func findSafeLineFromIndex(_ index:Int) -> Int {
		var lineIdx = index
		let line = self.lines[lineIdx]
		
		// This is unsafe, return no index found
		if line.unsafeForPageBreak {
			return NSNotFound
		}
		
		// Find out where the block starts
		if line.isDialogueElement() || line.isDualDialogueElement() {
			while (lineIdx >= 0) {
				let l = self.lines[lineIdx]
				
				if !l.isDialogue() && !l.isDualDialogue() { break }
				if l.type == .character { break }
				lineIdx -= 1
			}
		}
		
		if lineIdx > 0 {
			// We need to look one more line behind to see if we're at a heading
			let precedingLine = self.lines[lineIdx - 1]
			if precedingLine.type == .heading || precedingLine.type == .shot {
				lineIdx -= 1
			}
		}
		
		return lineIdx
	}
}*/
