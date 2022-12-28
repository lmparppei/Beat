//
//  BeatNativePrinting.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatNativePrinting:NSView {
	@objc enum BeatPrintingOperation:NSInteger {
		case toPreview, toPDF, toPrint
	}
	
	var delegate:BeatEditorDelegate?
	
	var settings:BeatExportSettings
	var pagination:BeatPaginationManager
	var renderer:BeatRendering
	var screenplay:BeatScreenplay
	var callback:(BeatNativePrinting, AnyObject?) -> ()
	var progressPanel:NSPanel = NSPanel(contentRect: NSMakeRect(0, 0, 350, 30), styleMask: [.docModalWindow], backing: .buffered, defer: false)
	var host:NSWindow
	
	var pageViews:[BeatPaginationPageView] = []
	var url:URL?
	
	@objc init(window:NSWindow, operation:BeatPrintingOperation, settings:BeatExportSettings, delegate:BeatEditorDelegate?, screenplay:BeatScreenplay?, callback: @escaping (BeatNativePrinting, AnyObject?) -> ()) {
		self.delegate = delegate
		
		if (delegate != nil) {
			self.screenplay = delegate!.parser.forPrinting()
		} else {
			self.screenplay = screenplay ?? BeatScreenplay()
		}
		
		self.host = window
		self.callback = callback
		self.renderer = BeatRendering(settings: settings)
		self.settings = settings
		self.pagination = BeatPaginationManager(settings: settings, delegate: nil, renderer: renderer, livePagination: false)
		
		let size = BeatPaperSizing.size(for: self.settings.paperSize)
		let frame = NSMakeRect(0, 0, size.width, size.height)
		super.init(frame: frame)
		
		// Render the screenplay
		paginateAndRender(operation: operation)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		// NOTE: Page numbers begin from 1
		range.pointee = NSMakeRange(1, self.pagination.pages.count)
		
		return true
	}
	
	override func rectForPage(_ page: Int) -> NSRect {
		self.subviews.removeAll()
		
		let pageView = self.pageViews[page]
		self.addSubview(pageView)
		
		return NSMakeRect(0, 0, self.frame.width, self.frame.height)
	}
	
	var data:NSMutableData = NSMutableData()
	func paginateAndRender(operation:BeatPrintingOperation) {
		DispatchQueue.global(qos: .userInteractive).async {
			self.pagination.newPagination(screenplay: self.screenplay, settings: self.settings, forEditor: false, changeAt: 0)
			
			DispatchQueue.main.sync {
				self.createPageViews()
				
				self.url = self.tempURL()
				
				let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
				
				printInfo.dictionary().addEntries(from: [
					NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
					NSPrintInfo.AttributeKey.jobSavingURL: NSURL(fileURLWithPath: self.url!.absoluteString)
				])
				
				/*
				let printOperation = NSPrintOperation.pdfOperation(with: self, inside: self.frame, to: self.data)
				printOperation.runModal(for: self.host, delegate: self, didRun: #selector(self.printOperationDidRun), contextInfo: nil)
				*/
				
				let printOperation = NSPrintOperation(view: self, printInfo: printInfo)
				printOperation.showsPrintPanel = false
				
				printOperation.runModal(for: self.host, delegate: self, didRun: #selector(self.printOperationDidRun), contextInfo: nil)
			}
		}
	}
	
	@objc func printOperationDidRun(_ operation:Any?, success:Bool, contextInfo:Any?) {
		guard let _ = operation as? NSPrintOperation,
			  let url = self.url
		else { return }
		
		callback(self, NSURL(fileURLWithPath: url.relativePath))
	}
	//- (void)printOperationDidRun:(id)operation success:(bool)success contextInfo:(nullable void *)contextInfo {
	
	func render(operation:BeatPrintingOperation) {
		let pdf = renderPages()
		
		if (operation == .toPreview) {
			let url = tempURL()
			pdf.write(to: url)
			
			// Send the result to callback
			callback(self, url as NSURL)
		}
		
		if (operation == .toPDF) {
			callback(self, pdf)
		}
	}
	
	func createPageViews() {
		self.pageViews = []
		
		if pagination.titlePage.count > 0 {
			// Add title page
			let titlePageView = BeatTitlePageView(titlePage: pagination.titlePage, settings: self.pagination.settings)
			pageViews.append(titlePageView)
		}
		
		for page in pagination.pages {
			autoreleasepool {
				let pageView = BeatPaginationPageView(page: page, content: nil, settings: self.pagination.settings, previewController: nil, titlePage: false)
				pageViews.append(pageView)
			}
		}
	}
	
	/// Renders pages according to export settings and returns a `PDFDocument`.
	func renderPages() -> PDFDocument {
		let pdf = PDFDocument()
				
		if pagination.titlePage.count > 0 {
			// Add title page
			let titlePageView = BeatTitlePageView(titlePage: pagination.titlePage, settings: self.pagination.settings)
			let data = titlePageView.dataWithPDF(inside: NSMakeRect(0, 0, titlePageView.frame.width, titlePageView.frame.height))
			let pdfPage = PDFPage(image: NSImage(data: data)!)!
			pdf.insert(pdfPage, at: 0)
		}
				
		for page in pagination.pages {
			autoreleasepool {
				let pageView = BeatPaginationPageView(page: page, content: nil, settings: self.pagination.settings, previewController: nil, titlePage: false)
				let data = pageView.dataWithPDF(inside: NSMakeRect(0, 0, pageView.frame.width, pageView.frame.height))
				let pdfPage = PDFPage(image: NSImage(data: data)!)!
				
				pdf.insert(pdfPage, at: pdf.pageCount)
			}
		}
		
		return pdf
	}
	
	/// Returns a temporary URL for PDF preview
	func tempURL() -> URL {
		
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("beatPreview")
			.appendingPathExtension("pdf")
		return url
	}
}
