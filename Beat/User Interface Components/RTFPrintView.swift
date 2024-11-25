//
//  RTFPrintView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

/**

 A simple view for printing RTF strings. Pages can be split using RTF page breaks (`\u{0c}`).
 - note: Runs in async, store a reference to the object before calling `pdf()`
 
 */
class RTFPrintView:NSView {
	var margin = 0.0
	var textViews:[NSTextView] = []
	var pageTexts:[NSAttributedString] = []
	
	init(text:NSAttributedString) {
		let size = NSPrintInfo.shared.paperSize
		super.init(frame: CGRectMake(0.0, 0.0, size.width, size.height))
		
		// Separate attributed string
		let pages = text.string.components(separatedBy: "\u{0c}")
		var i = 0
		for page in pages {
			let attributedString = text.attributedSubstring(from: NSMakeRange(i, page.count))
			pageTexts.append(attributedString)
			
			i += page.count + ((page != pages.last) ? 1 : 0)
		}
	}
	
	func pdf() {
		let size = self.frame.size
		let margin = 10.0
		var pdfs:[PDFDocument] = []
		
		for pageText in pageTexts {
			let frame = CGRectMake(0, 0, size.width, size.height)
			
			let textView = NSTextView(frame: frame)
			textView.textContainerInset = CGSizeMake(margin, margin)
			textView.textStorage?.setAttributedString(pageText)
			
			// Calculate page height
			let bounds = pageText.boundingRect(with: CGSizeMake(textView.frame.width, .greatestFiniteMagnitude), options: .usesLineFragmentOrigin)
			textView.frame.size.height = max(bounds.height, size.height)
						
			textViews.append(textView)

			let data = textView.dataWithPDF(inside: textView.bounds)
			if let doc = PDFDocument(data: data) {
				pdfs.append(doc)
			}
		}
		
		let fullPDF = PDFDocument()
		for singlePDF in pdfs {
			for i in 0..<singlePDF.pageCount {
				if let page = singlePDF.page(at: i) {
					fullPDF.insert(page, at: fullPDF.pageCount)
				}
			}
		}
		
		let operation = fullPDF.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: false)
		operation?.run()
	}
	
	override var isFlipped: Bool { return true }
		
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
