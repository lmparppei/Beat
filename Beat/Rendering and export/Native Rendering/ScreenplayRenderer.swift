//
//  RenderView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

protocol PageViewDelegate:NSObject {
	var styles:Styles { get }
	var fonts:BeatFonts { get }
	var pageSize:CGSize { get }
	var settings:BeatExportSettings! { get }
}

class ScreenplayRenderer:NSObject, PageViewDelegate {
	var settings:BeatExportSettings!
	var pages:[[Line]]
	var pageSize:CGSize
	var fonts: BeatFonts = BeatFonts.shared()
	var styles:Styles = Styles.shared
	var paginator:BeatPaginator
	var numberOfPages:UInt = 0
	
	//#define PAPER_A4 595.0, 842.0
	//#define PAPER_USLETTER 612.0, 792.0

	
	@objc init(settings: BeatExportSettings, screenplay:BeatScreenplay) {
		self.settings = settings
		
		// Paginate contents (in sync, for now)
		paginator = BeatPaginator.init(script: screenplay.lines, settings: settings)
		numberOfPages = paginator.numberOfPages
		self.pages = paginator.pages as? Array<[Line]> ?? []
		
		// Set page size
		self.pageSize = BeatPaperSizing.size(for: settings.paperSize)
		
		super.init()
		
		createPDF()
	}
	
	func createPDF() {
		//var pageViews:[NSView] = []
		let pdf = PDFDocument()
		
		for i in 0...pages.count-1 {
			let pageView = PageView(size: pageSize, elements: pages[i], delegate: self)
			pageView.display()
			
			let data = pageView.dataWithPDF(inside: NSMakeRect(0, 0, pageSize.width, pageSize.height))
			let pdfPage = PDFPage(image: NSImage(data: data)!)!
			pdf.insert(pdfPage, at: pdf.pageCount)
			
			/*
			 pdfView.document = pdfDocument
			 */
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
}

class RenderStyle:NSObject {
	@objc var bold:Bool = false
	@objc var italic:Bool = false
	@objc var underline:Bool = false
	
	@objc var textAlign:String = "left"
	
	@objc var marginTop:CGFloat = 0
	@objc var marginLeft:CGFloat = 0
	@objc var paddingLeft:CGFloat = 0

	@objc var widthA4:CGFloat = 0
	@objc var widthLetter:CGFloat = 0
	
	init(rules:[String:Any]) {
		super.init()
		
		for key in rules.keys {
			let value = rules[key]!
			let property = styleNameToProperty(name: key)
			
			self.setValue(value, forKey: property)
		}
	}
	
	func styleNameToProperty (name:String) -> String {

		switch name.lowercased() {
		case "width-a4":
			return "widthA4"
		case "width-us":
			return "widthLetter"
		case "margin-top":
			return "marginTop"
		case "margin-left":
			return "marginLeft"
		default:
			return name
		}
	}
	
	override class func setValue(_ value: Any?, forUndefinedKey key: String) {
		print("RenderStyle: Unknown key: ", key)
	}
}

class PageContainer:NSView {
	override var isFlipped: Bool { get { return true } }
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
}

class PageView:NSView {
	var fonts = BeatFonts.shared()
	var elements:[Line]
	var container:PageContainer
	weak var delegate:PageViewDelegate?
	var styles:Styles { get { return delegate!.styles } }
	override var isFlipped: Bool { get { return true } }
	
	init(size: CGSize, elements: [Line], delegate:PageViewDelegate) {
		self.elements = elements
		self.delegate = delegate
		self.container = PageContainer(frame: NSRect(x: delegate.styles.page().marginLeft, y: delegate.styles.page().marginTop, width: size.width - delegate.styles.page().marginLeft, height: size.height - delegate.styles.page().marginTop))
		
		super.init(frame: NSMakeRect(0, 0, size.width, size.height))
		
		self.addSubview(container)
		renderPage()
	}
	
	required init?(coder: NSCoder) {
		self.elements = []
		self.container = PageContainer()
		super.init(coder: coder)
	}
	
	var currentY:CGFloat {
		get {
			if container.subviews.count > 0 {
				return container.subviews.last!.frame.height + container.subviews.last!.frame.origin.y
			} else {
				return 0.0
			}
		}
	}
	
	func renderPage() {
		for line in elements {
			//let style = delegate.styles.forElement(name: line.typeAsString())
			let element = Element(line: line, styles: styles, y: self.currentY, dualDialogue: line.isDualDialogueElement(), parent: self)
			addElement(element: element)
		}
	}
	
	func addElement(element: Element) {
		container.addSubview(element)
	}
	
}

class RenderBlock:NSView {
	weak var parent:PageView?
	var lines:[Line]
	var style:RenderStyle?
	override var isFlipped: Bool { get { return true } }
	
	init(lines:[Line], y:CGFloat, contentWidth:CGFloat, parent:PageView) {
		self.lines = lines
		super.init(frame: NSZeroRect)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class Element:NSTextView {
	weak var parent:PageView?
	var line:Line
	var style:RenderStyle!
	
	override var isFlipped: Bool { get { return true } }
	
	init(line:Line, styles:Styles, y:CGFloat, dualDialogue:Bool, parent:PageView) {
		self.line = line
		self.parent = parent
		
		// Get correct style
		self.style = parent.styles.forElement(line.typeAsString())
		
		let width = (parent.delegate!.settings.paperSize == .A4) ? self.style.widthA4 : self.style.widthLetter
				
		let textView = NSTextView(frame: NSMakeRect(0, y, width, 13))
		super.init(frame: textView.frame, textContainer: textView.textContainer)
		
		self.isSelectable = false
		self.isEditable = false
		self.isRichText = true
		
		// Get page style
		let pageStyle = self.parent!.styles.page()
		
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
		
		let x = CGFloat(self.style!.marginLeft)
		
		let origin = NSPoint(x: x + pageStyle.paddingLeft, y: self.style!.marginTop + y)
		let size = NSSize(width: width, height: self.frame.height)
		self.frame = NSRect(origin: origin, size: size)
		
		// Calculate correct height and set frame
		self.layoutManager!.ensureLayout(for: self.textContainer!)
		let rect = self.layoutManager?.usedRect(for: self.textContainer!) ?? NSZeroRect
		self.frame = NSRect(origin: origin, size: NSSize(width: width, height: rect.height))
	}
	
	func displayedString(line:Line) -> NSAttributedString {
		// Create the attributed string
		let attrStr = line.attributedStringForFDX() ?? NSAttributedString(string: "[error]")
		let result = NSMutableAttributedString()
		
		// Strip formatting
		let contentIndices = line.contentRanges() as NSIndexSet
		contentIndices.enumerateRanges { range, stop in
			result.append(attrStr.attributedSubstring(from: range))
		}
		
		// Create the actual string we're going to display
		let displayStr = NSMutableAttributedString(attributedString: result)
		
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
		result.enumerateAttributes(in: NSMakeRange(0, result.length)) { attrs, range, stop in
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
		
		// Calculate size
		/*
		var chrWidth = 0.0
		if (result.length > 0) {
			let testStr = attrStr.attributedSubstring(from: NSMakeRange(0, 1))
			chrWidth = testStr.size().width
			print("Chr width", chrWidth)
		}
		 */
						
		return displayStr
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
		
}

// MARK: Stylesheet

class Styles {
	static let shared = Styles()
	var styles:[String:RenderStyle] = [:]
	
	private init() {
		reloadStyles()
	}
	
	func reloadStyles() {
		let url = Bundle.main.url(forResource: "Styles", withExtension: "beatCSS")
		do {
			let stylesheet = try String(contentsOf: url!)
			let parser = CssParser()
			styles = parser.parse(fileContent: stylesheet)
		} catch {
			print("Loading stylesheet failed")
		}
	}
	
	func page() -> RenderStyle {
		return styles["Page"]!
	}
	
	func forElement(_ name:String) -> RenderStyle {
		return styles[name] ?? RenderStyle(rules: ["width-a4": "59ch", "width-us": "61ch"])
	}
}


