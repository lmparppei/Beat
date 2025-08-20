//
//  BeatRenderingViews.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 Views used to render screenplays both on screen and in PDF.
 
 */

public struct BeatPDFDestination {
    public var label:String
    public var pageIndex:Int
    public var point:CGPoint
    public var pageSize:CGSize
    
    public init(label: String, pageIndex: Int, point: CGPoint, pageSize: CGSize) {
        self.label = label
        self.pageIndex = pageIndex
        self.point = point
        self.pageSize = pageSize
    }
}

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

import BeatCore
import UXKit

// MARK: - Basic page view for rendering the screenplay

/// Base view for both iOS and macOS
@objc public class BeatPagePrintView:UXView {
    #if os(macOS)
        override public var isFlipped: Bool { return true }
    #endif
	weak public var previewController:BeatPreviewManager?
}

/// Single page view
@objc open class BeatPaginationPageView:UXView {
    #if os(macOS)
        override public var isFlipped: Bool { return true }
    #endif
	weak public var previewController:BeatPreviewManager?
	
    /// The attributed string content of this page
	public var attributedString:NSAttributedString?
    /// Page data from pagination
    public var page:BeatPaginationPage?
    /// Main text view
    public var textView:BeatPageTextView?
    
    /// List of all text views on this page. Remember to add them.
    public var textViews:[UXTextView] = []
    
    /// Master page style
    var pageStyle:RenderStyle
    /// Title page style
    var titlePageStyle:RenderStyle?
    /// Export settings
    var settings:BeatExportSettings
	
	/// Actual frame of the page
    var size:CGSize
    /// Paper size tag
    var paperSize:BeatPaperSize
    
    var fonts = BeatFontManager.shared.defaultFonts
    var linePadding = 0.0
	
    /// Set `true` by subclass if needed
    var isTitlePage = false
    
    public weak var textViewDelegate:UXTextViewDelegate? {
        didSet { self.textView?.delegate = self.textViewDelegate }
    }
    
    /// Page can take in either a `BeatPaginationPage` or a pure `NSAttributedString`. The page is rendered automatically if the pagination has a renderer connected to it.
    @objc public init(page:BeatPaginationPage?, content:NSAttributedString? = nil, settings:BeatExportSettings, previewController: BeatPreviewManager?, textViewDelegate:UXTextViewDelegate? = nil) {
		self.size = BeatPaperSizing.size(for: settings.paperSize)

		self.attributedString = content
		self.previewController = previewController
		self.settings = settings
		self.paperSize = settings.paperSize
        
        // Set page content
		self.page = page
        if (page != nil && page?.delegate?.renderer != nil) {
            // Pagination has a renderer attached to it
			self.attributedString = page!.attributedString()
		} else {
            // No pagination, we'll use the provided content
			self.attributedString = content ?? NSAttributedString(string: "")
		}
		
        // Load styles
		let styles = self.settings.styles as? BeatStylesheet
		self.pageStyle = styles?.page() ?? RenderStyle(rules: [:])
		
		super.init(frame: CGRectMake(0, 0, size.width, size.height))
		
        #if os(macOS)
		self.canDrawConcurrently = true
		self.wantsLayer = true
		self.layer?.backgroundColor = .white
		
		// Force light appearance to get highlights show up correctly
		self.appearance = NSAppearance(named: .aqua)
        #else
        self.backgroundColor = .white
        #endif
		
		// Create text views and set attributed string
		createTextView()
        self.textViewDelegate = textViewDelegate
        
        // Set initial content. We have to guard this because of differing nullability on macOS and iOS.
        if let textStorage = self.textView?.textStorage {
            textStorage.setAttributedString(self.attributedString ?? NSAttributedString(string: ""))
        }
	}
	
	@objc func setContent(attributedString:NSAttributedString, settings:BeatExportSettings) {
        // We have to guard this because of different nullability settings on iOS and macOS
        guard let textStorage = self.textView?.textStorage else { return }
        textStorage.setAttributedString(attributedString)
	}
	
	func createTextView() {
		self.textView = BeatPageTextView(frame: self.textViewFrame())
        guard let textView = self.textView else {
            return
        }
        
        textViews.append(textView)
        
        textView.previewController = self.previewController
		textView.isEditable = false
        textView.backgroundColor = .white
        //self.textView?.font = fonts.regular
        
        #if os(macOS)
            textView.textContainerInset = CGSizeZero
            textView.linkTextAttributes = [
                NSAttributedString.Key.font: fonts.regular,
                NSAttributedString.Key.cursor: NSCursor.pointingHand
            ]
        #else
            textView.textContainerInset = UIEdgeInsets.zero
            textView.linkTextAttributes = [.foregroundColor: UIColor.black]
        #endif
        
        #if os(macOS)
            textView.displaysLinkToolTips = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.textContainer?.lineFragmentPadding = linePadding
            textView.textContainerInset = NSSize(width: 0, height: 0)
            textView.drawsBackground = true
        #endif
		        
		
        #if os(macOS)
            // Let's force TextKit 1 on macOS
            let layoutManager = BeatRenderLayoutManager()
            layoutManager.pageView = self

            textView.textContainer?.replaceLayoutManager(layoutManager)
            textView.textContainer?.lineFragmentPadding = linePadding
        #else
            // iOS uses TextKit 2
            textView.textLayoutManager?.delegate = self
        #endif
				
		self.addSubview(textView)
	}
	
	func textViewFrame() -> CGRect {
        // Title page frame is a bit different
        if isTitlePage { return titlePageTextViewFrame() }
        
		let size = BeatPaperSizing.size(for: settings.paperSize)
		let marginOffset = (settings.paperSize == .A4) ? pageStyle.marginLeftA4 : pageStyle.marginLeftLetter
		
		let textFrame = CGRect(x: pageStyle.marginLeft - linePadding + marginOffset,
							   y: pageStyle.marginTop,
							   width: size.width - pageStyle.marginLeft - pageStyle.marginRight,
							   height: size.height - pageStyle.marginTop)
		
		return textFrame
	}
    
    /// Title page doesn't need to take line fragment padding etc. into account
    func titlePageTextViewFrame() -> CGRect {
        let size = BeatPaperSizing.size(for: settings.paperSize)
        let offset = 20.0
        
        let pageStyle = (self.isTitlePage && self.titlePageStyle != nil) ? self.titlePageStyle! : self.pageStyle
        let textFrame = CGRect(x: pageStyle.marginLeft + offset,
                               y: pageStyle.marginTop,
                               width: size.width - pageStyle.marginLeft - pageStyle.marginRight - offset * 2,
                               height: size.height - pageStyle.marginTop)
        
        return textFrame
    }
	
	func updateContainerSize() {
		paperSize = settings.paperSize
		self.textView?.frame = self.textViewFrame()
	}
	
	/// Update content to an existing page
	public func update(page:BeatPaginationPage, settings:BeatExportSettings) {
		self.settings = settings
		self.page = page
		
		// Update container frame if paper size has changed
		if (self.settings.paperSize != self.paperSize) {
			updateContainerSize()
			page.invalidateRender()
		}
        if let textStorage = self.textView?.textStorage {
            textStorage.setAttributedString(page.attributedString())
        }
	}
	
    #if os(macOS)
	override public func cancelOperation(_ sender: Any?) {
        // Esc was pressed, forward it to superview
		superview?.cancelOperation(sender)
	}
    #endif
	
    /// Returns intermediate placeholder PDF destinations for this page. They are later appended to the actual PDF.
    public func pdfDestinations(withPageIndex pageIndex:Int) -> [BeatPDFDestination] {
        var outline:[BeatPDFDestination] = []
        // Gah. macOS and iOS have different nullabilities in these text view properties.
        #if os(macOS)
        guard let attrString = self.attributedString, let textView = textView, let textContainer = textView.textContainer, let layoutManager = textView.layoutManager else { return [] }
        #else
        guard let attrString = self.attributedString, let textView = textView else { return [] }
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        #endif
    
        attrString.enumerateAttribute(NSAttributedString.Key(rawValue: "HEADING"), in: attrString.range) { value, range, stop in
            if let string = value as? String {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                let point = CGPoint(x: rect.origin.x + textView.frame.origin.x, y: self.frame.height - rect.origin.y)
                let outlineItem = BeatPDFDestination(label: string, pageIndex: pageIndex, point: point, pageSize: self.frame.size)
                outline.append(outlineItem)
            }
        }

        return outline
    }
    
	required public init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}


