//
//  BeatTitlePageView.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 8.8.2025.
//

import UXKit

// MARK: - Title page

@objc public class BeatTitlePageView:BeatPaginationPageView {
	var leftColumn:UXTextView?
	var rightColumn:UXTextView?
	var titlePageLines:[[String:[Line]]]
	
	@objc public init(previewController: BeatPreviewManager? = nil, titlePage:[[String:[Line]]], settings:BeatExportSettings) {
        self.titlePageLines = titlePage
		super.init(page: nil, content: NSMutableAttributedString(string: ""), settings: settings, previewController: previewController)

        // Load title page styles
        let styles = settings.styles as? BeatStylesheet
        self.titlePageStyle = styles?.titlePage
        
		createViews()
		createTitlePage()
		
		isTitlePage = true
	}
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    /// Override page render method for title pages
    func createViews() {
        // Use title page style if applicable
        let pageStyle = (self.titlePageStyle != nil) ? self.titlePageStyle! : self.pageStyle
        
        let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let textViewFrame = CGRect(x: pageStyle.marginLeft,
                                   y: pageStyle.marginTop,
                                   width: frame.size.width - pageStyle.marginLeft - pageStyle.marginRight,
                                   height: 400)
        textView?.frame = frame
        
        // Placeholder frame
        let columnFrame = CGRect(x: pageStyle.marginLeft + 10.0,
                                 y: textViewFrame.origin.y + textViewFrame.height,
                                 width: 0.0,
                                 height: frame.height - textViewFrame.size.height - pageStyle.marginBottom - BeatPagination.lineHeight() * 4)
        
        // Specific calculations for the
        let columnFrameLeft = CGRect(x: columnFrame.origin.x, y: columnFrame.origin.y, width: textViewFrame.width * 0.65 - 10, height: columnFrame.height)
        let columnFrameRight = CGRect(x: columnFrameLeft.maxX, y: columnFrame.origin.y, width: textViewFrame.width * 0.35 - 10, height: columnFrame.height)
        
        if (leftColumn == nil) {
            leftColumn = UXTextView(frame: columnFrameLeft)
            leftColumn?.isEditable = false
            #if os(macOS)
                leftColumn?.drawsBackground = false
            #else
                leftColumn?.backgroundColor = .clear
            #endif
            
            leftColumn?.isSelectable = false
            
            self.addSubview(leftColumn!)
            self.textViews.append(leftColumn!)
        }

        if (rightColumn == nil) {
            rightColumn = UXTextView(frame: columnFrameRight)
            rightColumn?.isEditable = false
            #if os(macOS)
                rightColumn?.drawsBackground = false
            #else
                rightColumn?.backgroundColor = .clear
            #endif
            
            rightColumn?.isSelectable = false
            
            self.addSubview(rightColumn!)
            self.textViews.append(rightColumn!)
        }
    }

	/// Creates title page content and places the text snippets into correct spots
	public func createTitlePage() {

		guard let leftColumn = self.leftColumn,
			  let rightColumn = self.rightColumn,
			  let textView = self.textView,
              let textStorage = self.textView?.textStorage,
              let leftTextStorage = self.leftColumn?.textStorage,
              let rightTextStorage = self.rightColumn?.textStorage
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
		textStorage.append(topContent)
		
		// Draft date on right side
		if let draftDate = titlePageElement("draft date") {
			let attrStr = NSMutableAttributedString()
			_ = draftDate.map { attrStr.append(renderer.renderLine($0)) }
			rightTextStorage.append(attrStr)
		}
		
		if let contact = titlePageElement("contact") {
			let attrStr = NSMutableAttributedString()
			_ = contact.map { attrStr.append(renderer.renderLine($0)) }
			leftTextStorage.append(attrStr)
		}
				
		// Add the rest of the elements on left side
		for dict in self.titlePageLines {
            // Make sure we have a value and that it's not a metadata key
            guard let key = dict.keys.first?.lowercased(), key.prefix(2) != "x-" else {
                continue
            }
                    
			if let element = titlePageElement(dict.keys.first ?? "") {
				let attrStr = NSMutableAttributedString()
				_ = element.map { attrStr.append(renderer.renderLine($0)) }
				leftTextStorage.append(attrStr)
			}
		}
		
		// Remove backgrounds
        #if os(macOS)
		leftColumn.drawsBackground = false
		rightColumn.drawsBackground = false
		textView.drawsBackground = true
        #endif
		
		// Layout manager doesn't handle newlines too well, so let's trim the column content
		leftTextStorage.setAttributedString(leftTextStorage.trimmedAttributedString(set: .newlines))
		rightTextStorage.setAttributedString(rightTextStorage.trimmedAttributedString(set: .newlines))

		// Once we've set the content, let's adjust top inset to align text to bottom
        #if os(macOS)
            leftColumn.textContainerInset = CGSize(width: 0, height: 0)
            rightColumn.textContainerInset = CGSize(width: 0, height: 0)
        #else
            leftColumn.textContainerInset = UIEdgeInsets.zero
            rightColumn.textContainerInset = UIEdgeInsets.zero
        #endif
		
        #if os(macOS)
            _ = leftColumn.layoutManager!.glyphRange(for: leftColumn.textContainer!)
            _ = rightColumn.layoutManager!.glyphRange(for: rightColumn.textContainer!)
            let leftRect = leftColumn.layoutManager!.usedRect(for: leftColumn.textContainer!)
            let rightRect = rightColumn.layoutManager!.usedRect(for: rightColumn.textContainer!)
        #else
            // Avoid using TextKit 1
            let leftRect = leftColumn.attributedText.boundingRect(with: CGSize(width: leftColumn.frame.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            let rightRect = rightColumn.attributedText.boundingRect(with: CGSize(width: rightColumn.frame.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        #endif
				
		// We'll calculate correct insets for the boxes, so the content will be bottom-aligned
		let insetLeft = leftColumn.frame.height - leftRect.height
		let insetRight = rightColumn.frame.height - rightRect.height
		
        #if os(macOS)
            leftColumn.textContainerInset = CGSize(width: 0, height: insetLeft)
            rightColumn.textContainerInset = CGSize(width: 0, height: insetRight)
        #else
            leftColumn.textContainerInset = UIEdgeInsets(top: insetLeft, left: 0.0, bottom: 0.0, right: 0.0)
            rightColumn.textContainerInset = UIEdgeInsets(top: insetRight, left: 0.0, bottom: 0.0, right: 0.0)
        #endif
        
        textView.frame = self.titlePageTextViewFrame()
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
	@objc public func updateTitlePage(_ titlePageContent: [[String:[Line]]]) {
        self.titlePageLines = []
		self.titlePageLines = titlePageContent
		createTitlePage()
	}
}

