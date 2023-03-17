//
//  BeatNativePrinting.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class  provides a native `NSView`-based  printing component for macOS version of Beat, replacing the old `KWWebView`-based `PrintView`.
 You need to provide export settings, and a window which owns this operation. If you specify a delegate, screenplay content will be automatically requested from there. Otherwise you need to send a `BeatScreenplay` object.
 
 */

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
	var operation:BeatPrintingOperation = .toPrint
	
	var pageViews:[BeatPaginationPageView] = []
	var url:URL?
	
	/**
	 Begins a print operation. **Note**: the operation is run asynchronously, so this virtual view has to be owned by another object for the duration of the process.
	 - parameter window: The window which owns this operation
	 - parameter operation: Either `.toPreview` (temporary PDF file), `.toPDF` (save result into a PDF)  or `.toPrint` (sends the result to macOS printing panel)
	 - parameter settings: Export settings
	 - parameter delegate: Optional document delegate. If set, `screenplay` object will be requested from the parser of current document.
	 - parameter screenplay: Screenplay object (containing title page and lines). If you have a delegate set, this can be `nil`
	 - parameter callback: Closure run after printing is done
	 */
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
		self.operation = operation
		
		let size = BeatPaperSizing.size(for: self.settings.paperSize)
		let frame = NSMakeRect(0, 0, size.width, size.height)
		super.init(frame: frame)
		
		// Render the screenplay
		paginateAndRender()
	}
	
	@objc convenience init(window:NSWindow, operation:BeatPrintingOperation, delegate:BeatEditorDelegate, callback:@escaping (BeatNativePrinting, AnyObject?) -> ()) {
		self.init(window: window, operation: operation, settings: delegate.exportSettings, delegate: delegate, screenplay: nil, callback: callback)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		// NOTE: Page numbers begin from 1
		var pageCount = self.pagination.pages.count
		if (self.pagination.hasTitlePage) { pageCount += 1 }
		
		range.pointee = NSMakeRange(1, pageCount)
		
		return true
	}
	
	override func rectForPage(_ page: Int) -> NSRect {
		self.subviews.removeAll()

		let pageView = self.pageViews[page - 1] // -1 because this is an array index
		self.addSubview(pageView)
		
		return NSMakeRect(0, 0, self.frame.width, self.frame.height)
	}
	
	var data:NSMutableData = NSMutableData()
	func paginateAndRender() {
		DispatchQueue.global(qos: .userInteractive).async {
			self.pagination.newPagination(screenplay: self.screenplay, settings: self.settings, forEditor: false, changeAt: 0)
			
			DispatchQueue.main.sync {
				self.createPageViews()
				
				if self.operation == .toPreview {
					// Our URL will be a random, temp url
					self.url = self.tempURL()
				}
				else if self.operation == .toPDF {
					// Request URL from user
					self.getURLforPDF()
				}
				
				// No URL set for PDF operations, just exit this bowling alley
				if (self.url == nil && self.operation == .toPDF) {
					print(self.className, "- no URL set")
					self.printOperationDidRun(nil, success: false, contextInfo: nil)
					return
				}
								
				let printInfo = NSPrintInfo()
				printInfo.horizontalPagination = .fit
				printInfo.verticalPagination = .fit

				printInfo.leftMargin = 0.0
				printInfo.rightMargin = 0.0
				printInfo.topMargin = 0.0
				printInfo.bottomMargin = 0.0
				printInfo.jobDisposition = .spool
				
				if (self.operation != .toPrint) {
					printInfo.jobDisposition = .save
					printInfo.dictionary().setObject(NSURL(fileURLWithPath: self.url!.absoluteString), forKey: NSPrintInfo.AttributeKey.jobSavingURL as NSCopying)
				}
				
				let printOperation = NSPrintOperation(view: self, printInfo: printInfo)
				printOperation.showsProgressPanel = (self.operation != .toPreview)
				printOperation.showsPrintPanel = (self.operation == .toPrint)
				
				// Run print operation
				printOperation.runModal(for: self.host, delegate: self, didRun: #selector(self.printOperationDidRun), contextInfo: nil)
			}
		}
	}
	
	
	/// Called after the operation has finished
	@objc func printOperationDidRun(_ operation:Any?, success:Bool, contextInfo:Any?) {
		guard let _ = operation as? NSPrintOperation
		else { return }
		
		if (self.operation != .toPrint) {
			print("PDF operation finished")
			guard let url = self.url else {
				print("ERROR: No PDF file found")
				return
			}
			callback(self, NSURL(fileURLWithPath: url.relativePath))
		} else {
			// Inform that the printing was successful
			callback(self, nil)
		}
	}

	func createPageViews() {
		self.pageViews = []
		
		if pagination.hasTitlePage {
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
	
	
	// MARK: - Alternative way of printing
	
	/// This is a super-low-performance alternative for `paginateAndRender`
	func render() {
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
	
	
	// MARK: - File access
	
	/// Returns a temporary URL for PDF preview
	func tempURL() -> URL {
		
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("beatPreview")
			.appendingPathExtension("pdf")
		return url
	}
	
	func getURLforPDF() {
		var filename = "Untitled"
		if self.delegate != nil {
			filename = self.delegate!.fileNameString()
		}

		let saveDialog = NSSavePanel()
		saveDialog.allowedFileTypes = ["pdf"]
		saveDialog.nameFieldStringValue = filename
		
		if (self.window != nil) {
			saveDialog.beginSheetModal(for: self.window!) { value in
				let response = value as NSApplication.ModalResponse
				
				if (response == .OK) {
					self.url = saveDialog.url
				}
				else {
					self.url = nil
				}
			}
		} else {
			let response = saveDialog.runModal()
			if (response == .OK) {
				self.url = saveDialog.url
			} else {
				self.url = nil
			}
		}
	}
	
}
