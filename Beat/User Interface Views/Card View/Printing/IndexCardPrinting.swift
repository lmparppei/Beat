//
//  IndexCardPrinting.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 19.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatParsing
import BeatPagination2

// MARK: - Data Model

/// A single screenplay index card
@objc public class IndexCard: NSObject {
	
	@objc public let sceneNumber:String
	@objc public let heading:String
	
	@objc public var snippet:String?
	@objc public let notes: [String]
	@objc public let synopses: [String]
	@objc public let colorName:String?
	
	@objc public var eights:[Int]?
	
	@objc public init(scene:OutlineScene, snippet:String? = nil, eights:[Int]? = nil) {
		self.sceneNumber = scene.sceneNumber ?? ""
		self.heading = scene.stringForDisplay() ?? ""
		
		// These values need to be manually computed by gathering stuff from the parser and document. Sorry.
		self.snippet = snippet
		self.eights = eights
		
		var notes:[String] = []
		for note in scene.notes as? [BeatNoteData] ?? [] {
			notes.append(note.content)
		}
		
		self.notes = notes
		
		var synopses:[String] = []
		for synopsis in scene.synopsis as? [Line] ?? [] {
			synopses.append(synopsis.stringForDisplay())
		}
		
		self.synopses = synopses
		self.colorName = scene.color
	}
	
	/// Creates card content string
	func cardText() -> NSAttributedString {
		let text = NSMutableAttributedString()
		let list = NSTextList(markerFormat: .disc, options: 0)

		let pStyle = NSMutableParagraphStyle()
		pStyle.paragraphSpacing = 3.0
		
		if synopses.count > 0 {
			let listStr = NSMutableAttributedString()
			
			let listParagraph = NSMutableParagraphStyle()
			listParagraph.textLists = [list]
			
			listParagraph.defaultTabInterval = 5.0
			listParagraph.tabStops = [NSTextTab(type: .leftTabStopType, location: 0), NSTextTab(type: .leftTabStopType, location: 0)]
			listParagraph.headIndent = 15
			listParagraph.firstLineHeadIndent = 0
			listParagraph.paragraphSpacing = 2.0

			let synopsisMarker = list.marker(forItemNumber: 0)
			
			for synopsis in synopses {
				let synopsis = "\(synopsisMarker)\t\(synopsis)\n"
				
				let str = NSAttributedString(string: synopsis, attributes: [
					.font: IndexCardLayout.synopsisFont,
					.paragraphStyle: listParagraph
					])

				listStr.append(str)
			}
		
			
			text.append(listStr)
			
		} else {
			text.append(NSAttributedString(string: self.snippet ?? "", attributes: [
				.font: IndexCardLayout.bodyFont,
				.foregroundColor: NSColor.black,
				.paragraphStyle: pStyle
			]))
		}
		
		return text
	}
}

// MARK: - Layout Constants

private enum IndexCardLayout {
	static let columns = 3
	static let rows = 3
	static let cardsPerPage = columns * rows
	
	static let pageMargin:CGFloat = 0.0
	
	static let cardSpacing:CGFloat = 0.0
	
	static let innerPadding:CGFloat = 10
	
	static let sceneNumberSize:CGFloat = 20
	
	static let sceneNumberFontSize:CGFloat = 6.5
	static let fontSize:CGFloat = 10.0
	static let headingFontSize:CGFloat = 11.0
	
	static let headingFont = NSFont(name: "Courier-Bold", size: IndexCardLayout.headingFontSize) ?? NSFont.boldSystemFont(ofSize: IndexCardLayout.headingFontSize)
	static let bodyFont = NSFont(name: "Helvetica", size: IndexCardLayout.fontSize) ?? NSFont.systemFont(ofSize: IndexCardLayout.fontSize)
	static let synopsisFont = NSFont(name: "Helvetica-Oblique", size: IndexCardLayout.fontSize) ?? NSFont.systemFont(ofSize: IndexCardLayout.fontSize)
	static let sceneNumberFont = NSFont.boldSystemFont(ofSize: IndexCardLayout.sceneNumberFontSize)
	static let pageCountFont = NSFont.systemFont(ofSize: IndexCardLayout.sceneNumberFontSize)
	
	static let contentMargin = IndexCardLayout.innerPadding + sceneNumberSize + IndexCardLayout.innerPadding
}


// MARK: - Card settings

public enum IndexCardPrinterSettings:CaseIterable {
	case colored
	case notes
	
	var localizedTitle: String {
		switch self {
		case .colored: return BeatLocalization.localizedString(forKey: "indexCards.settings.colored")
		case .notes: return BeatLocalization.localizedString(forKey: "indexCards.settings.notes")
		}
	}
}


// MARK: - IndexCardPrintView

/// A paginated NSView for natively printing index cards. NOT FOR DISPLAYING ANYTHING, only for printing
final class IndexCardPrintView: NSView {
	
	override var isFlipped: Bool { true }

	/// Card to be printed
	private let cards:[IndexCard]

	private let cardSize:NSSize
	private let pageSize:NSSize
	private let numberOfPages:Int
	
	let flags:[IndexCardPrinterSettings]
	
	// MARK: Init
	
	init(cards: [IndexCard], printInfo: NSPrintInfo, flags:[IndexCardPrinterSettings]) {
		self.cards = cards
		self.flags = flags
		
		// Resolve landscape page size regardless of how NSPrintInfo reports paperSize.
		// NSPrintInfo.paperSize always returns portrait-order dimensions on macOS,
		// so we enforce landscape by taking max/min.
		// Let's also use imageable bounds to avoid any other weirdness.
		let paper = printInfo.imageablePageBounds
		let printWidth = max(paper.width, paper.height)   // e.g. 792 pt for US Letter
		let printHeight = min(paper.width, paper.height)   // e.g. 612 pt for US Letter
		self.pageSize = NSSize(width: printWidth, height: printHeight)
		
		let count = cards.count
		self.numberOfPages = count == 0 ? 1
		: Int(ceil(Double(count) / Double(IndexCardLayout.cardsPerPage)))
		
		// Divide the usable area evenly into a grid. There's margin & spacing modifiers avoilable, though they are unused for now.
		let usableWidth = printWidth - IndexCardLayout.pageMargin * 2 - IndexCardLayout.cardSpacing * CGFloat(IndexCardLayout.columns - 1)
		let usableHeight = printHeight - IndexCardLayout.pageMargin * 2 - IndexCardLayout.cardSpacing * CGFloat(IndexCardLayout.rows - 1)
		
		self.cardSize = NSSize(width:  floor(usableWidth / CGFloat(IndexCardLayout.columns)),
							   height: floor(usableHeight / CGFloat(IndexCardLayout.rows)))
				
		// The whole view is as tall as all pages stacked — NSPrintOperation clips each page
		let totalH = CGFloat(numberOfPages) * printHeight
		super.init(frame: NSRect(x: 0, y: 0, width: printWidth, height: totalH))
	}
	
	required init?(coder: NSCoder) {
		fatalError("Use init(cards:printInfo:) instead")
	}
	   
	
	// MARK: Pagination
	
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		range.pointee = NSRange(location: 1, length: numberOfPages)
		return true
	}
	
	override func rectForPage(_ page: Int) -> NSRect {
		let y = CGFloat(page - 1) * pageSize.height
		return NSRect(x: 0, y: y, width: pageSize.width, height: pageSize.height)
	}
	
	
	// MARK: Drawing
	
	override func draw(_ dirtyRect: NSRect) {
		NSColor.white.setFill()
		dirtyRect.fill()
		
		// We have actually laid out all cards in a single view, so we'll only show pages which fall into the dirty rect
		let firstPage = max(1, Int(floor(dirtyRect.minY / pageSize.height)) + 1)
		let lastPage  = min(numberOfPages, Int(ceil(dirtyRect.maxY  / pageSize.height)))
		
		guard firstPage <= lastPage else { return }
		
		(firstPage...lastPage).forEach(drawPage(_:))
	}
	
	
	// MARK: Page Layout
	
	private func drawPage(_ page: Int) {
		let pageRect  = rectForPage(page)
		let firstCard = (page - 1) * IndexCardLayout.cardsPerPage
		
		for row in 0..<IndexCardLayout.rows {
			for col in 0..<IndexCardLayout.columns {
				let idx = firstCard + row * IndexCardLayout.columns + col
				guard idx < cards.count else { continue }
				
				let x = pageRect.minX + IndexCardLayout.pageMargin + CGFloat(col) * (cardSize.width  + IndexCardLayout.cardSpacing)
				let y = pageRect.minY + IndexCardLayout.pageMargin + CGFloat(row) * (cardSize.height + IndexCardLayout.cardSpacing)
				
				let rect = NSRect(x: x, y: y, width: cardSize.width, height: cardSize.height)
				drawCard(cards[idx], in: rect)
			}
		}
	}
	
	
	// MARK: Card Drawing
	
	private func drawCard(_ card: IndexCard, in rect: NSRect) {
		NSGraphicsContext.saveGraphicsState()
		defer { NSGraphicsContext.restoreGraphicsState() }
		
		// We'll fill the background with white (just in case)
		let cardPath = NSBezierPath(roundedRect: rect, xRadius: 0.0, yRadius: 0.0)
		NSColor.white.setFill()
		cardPath.fill()
		cardPath.addClip() // Ensure we'll only draw inside the card
		
		if let colorName = card.colorName, let color = BeatColors.color(colorName) {
			color.withAlphaComponent(0.05).setFill()
			cardPath.fill()
		}
		
		// Draw the border
		NSColor.black.setStroke()
		cardPath.lineWidth = 0.75
		cardPath.stroke()
		
		
		// Draw the scene number
		let sceneNumberY = rect.minY + IndexCardLayout.sceneNumberSize / 2
		let sceneNumberRect = NSRect(x: rect.minX + IndexCardLayout.innerPadding - 2.0,
							   y: sceneNumberY,
							   width:  IndexCardLayout.sceneNumberSize,
							   height: IndexCardLayout.sceneNumberSize)
		
		// Scene number badge. First draw a white background, then the stroke.
		let circlePath = NSBezierPath(ovalIn: sceneNumberRect)
		NSColor.white.setFill()
		circlePath.fill()
		NSColor.black.setStroke()
		circlePath.lineWidth = 1
		circlePath.stroke()
		
		// Scene number centred inside the circle
		let numAttrs: [NSAttributedString.Key: Any] = [
			.font: IndexCardLayout.sceneNumberFont,
			.foregroundColor: NSColor.black
		]
		
		let sceneNumber = card.sceneNumber as String
		let numSize = sceneNumber.size(withAttributes: numAttrs)
		
		sceneNumber.draw(at: NSPoint(x: sceneNumberRect.midX - numSize.width  / 2,
								y: sceneNumberRect.midY - numSize.height / 2),
					withAttributes: numAttrs)
		
		
		// Scene heading text
		let headingString = NSAttributedString(string: card.heading.uppercased() as String, attributes: [
			.font: IndexCardLayout.headingFont,
			.foregroundColor: NSColor.black
		])
		
		let maxWidth = rect.size.width - IndexCardLayout.contentMargin - IndexCardLayout.innerPadding

		var headingRect = headingString.boundingRect(
			with: NSSize(width: maxWidth, height: 1_000),
			options: [.usesLineFragmentOrigin, .usesFontLeading]
		)

		headingRect.origin.x = rect.origin.x + IndexCardLayout.contentMargin
		headingRect.origin.y = rect.minY + IndexCardLayout.innerPadding
		
		headingString.draw(in: headingRect)
		
		// Body
		let bodyRect = NSRect(x: rect.origin.x + IndexCardLayout.contentMargin,
							  y: rect.minY + IndexCardLayout.innerPadding * 2.5 + headingRect.height - 5.0,
							  width:  rect.width - IndexCardLayout.innerPadding - IndexCardLayout.contentMargin,
							  height: rect.minY + rect.height - headingRect.maxY - 20.0)
		
		var content = card.cardText()
		let fittingRange = fittingRange(for: content, textRect: bodyRect)
		
		if fittingRange.length < content.length {
			let fittingContent = NSMutableAttributedString(attributedString: content.attributedSubstring(from: fittingRange))
			if fittingContent.string.suffix(1) != "." {
				fittingContent.append(NSAttributedString(string: "...", attributes: [.foregroundColor: NSColor.black, .font: IndexCardLayout.bodyFont]))
			}
			content = fittingContent
		}
				
		content.draw(in: bodyRect)
		
		// Draw the scene length at bottom
		if let eights = card.eights, eights.count == 2 {
			var eightsString = ""
			if eights[0] > 0 { eightsString += "\(eights[0])" }
			if eights[1] > 0 { eightsString += " \(eights[1])/8" }
			if eights[0] == 0 && eights[1] == 0 { eightsString = "1/8" }
			
			let eightsStyle = NSMutableParagraphStyle()
			eightsStyle.alignment = .right
			let eightsAttrStr = NSAttributedString(string: eightsString, attributes: [
				.foregroundColor: NSColor.black,
				.font: IndexCardLayout.pageCountFont,
				.paragraphStyle: eightsStyle
			])
			
			let eightsRect = CGRect(x: bodyRect.origin.x, y: rect.maxY - 15, width: bodyRect.width, height: 15)
			eightsAttrStr.draw(in: eightsRect)
		}
	}
	
	func fittingRange(for string:NSAttributedString, textRect:CGRect) -> NSRange {
		let textStorage = NSTextStorage(attributedString: string)
		let container = NSTextContainer(containerSize: NSSize(width: textRect.width + 10.0, height: CGFloat.greatestFiniteMagnitude))
		let lm = NSLayoutManager()
		
		lm.addTextContainer(container)
		textStorage.addLayoutManager(lm)
		
		let fullRange = NSMakeRange(0, textStorage.length)
		lm.ensureLayout(for: container)
		
		let glyphRange = lm.glyphRange(forCharacterRange: fullRange, actualCharacterRange: nil)
		
		var length:Int = 0
		var height:CGFloat = 0.0
		
		lm.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, container, range, stop in
			height += rect.height

			if height > textRect.height - 13.0 {
				stop.pointee = true
				return
			}
			
			let charRange = lm.characterRange(forGlyphRange: range, actualGlyphRange: nil)
			length += NSMaxRange(charRange)
		}
		
		return NSMakeRange(0, length)
	}
}

// MARK: - IndexCardPrinter (available for plugins)

@objc public final class IndexCardPrinter:NSObject {
	
	// MARK: Print
	
	@objc public static func print(with delegate:BeatPluginDelegate) {
		
		let window = delegate.documentWindow
		
		var cards:[IndexCard] = []
		
		// Gather text snippets and other data
		for scene in delegate.parser.scenes() {
			guard !scene.omitted else { continue }
			
			var snippet:String?
			
			// We'll need to create the content manually if there are no synopses
			if scene.synopsis.count == 0 {
				let lines = delegate.parser.lines(for: scene) ?? []
				
				var text = ""
				for line in lines {
					let string = line.stripFormatting() ?? ""
					guard line.type == LineType.action, string.count > 0 else { continue }
					
					text += string + " " //+ "\n"
					
					if (delegate.styles.document.significantUnits == 0 && text.count > 150) || text.count > 450 { break }
				}
				
				snippet = text
			}
			
			// We'll also need the printed length
			let eights = delegate.pagination().sceneLengthInEights(scene)
			
			cards.append(IndexCard(scene: scene, snippet: snippet, eights: eights))
		}
		
		IndexCardPrinter.print(cards, attachedTo: window)
	}
	
	/// Presents the system Print dialog for the given cards.
	/// - Parameters:
	///   - cards:  Cards to print, in order
	///   - window: If provided, the panel runs as a sheet, otherwise standalone
	public static func print(_ cards: [IndexCard], attachedTo window: NSWindow? = nil, flags:[IndexCardPrinterSettings] = [.colored]) {
		let info = makePrintInfo()
		let view = IndexCardPrintView(cards: cards, printInfo: info, flags:flags)
		let op   = NSPrintOperation(view: view, printInfo: info)
		op.showsPrintPanel    = true
		op.showsProgressPanel = true
		
		if let window {
			op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
		} else {
			op.run()
		}
	}
	
	// MARK: PDF Export
	
	/// Exports cards directly to a PDF file — no dialog shown.
	/// - Parameters:
	///   - cards: Cards to export.
	///   - url:   Destination file URL (typically ending in `.pdf`).
	/// - Throws: `CocoaError(.fileWriteUnknown)` if the operation fails.
	public static func exportPDF(_ cards: [IndexCard], to url: URL, flags:[IndexCardPrinterSettings] = [.colored]) throws {
		let info = makePrintInfo()
		
		info.dictionary().addEntries(from: [
			NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
			NSPrintInfo.AttributeKey.jobSavingURL:   url
		])
		
		let view = IndexCardPrintView(cards: cards, printInfo: info, flags: flags)
		let op = NSPrintOperation(view: view, printInfo: info)
		op.showsPrintPanel    = false
		op.showsProgressPanel = false
		
		guard op.run() else {
			throw CocoaError(.fileWriteUnknown)
		}
	}
	
	
	// MARK: Dialog
	
	public static func settingsDialog(window:NSWindow?) -> [IndexCardPrinterSettings]? {
		
		
		
		return nil
	}
	
	
	// MARK: Private
	
	/// Returns a landscape NSPrintInfo with zero margins.
	/// Always copies NSPrintInfo.shared to avoid mutating global state.
	private static func makePrintInfo() -> NSPrintInfo {
		let info = NSPrintInfo.shared.copy() as! NSPrintInfo
		
		info.orientation  = .landscape
		
		// We manage our own visual margins inside IndexCardPrintView,
		// so tell the print system to give us the full paper area.
		info.topMargin = 0
		info.bottomMargin = 0
		info.leftMargin = 0
		info.rightMargin = 0
		
		info.isHorizontallyCentered = false
		info.isVerticallyCentered = false
		info.scalingFactor = 1.0
				
		return info
	}
}
