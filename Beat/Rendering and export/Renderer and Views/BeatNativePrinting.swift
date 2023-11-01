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
import BeatCore

class BeatNativePrinting:NSView {
	@objc enum BeatPrintingOperation:NSInteger {
		case toPreview, toPDF, toPrint
	}
	
	var delegate:BeatEditorDelegate?
	
	var settings:BeatExportSettings
	//var pagination:BeatPaginationManager
	var renderer:BeatRenderer
	var screenplays:[BeatScreenplay]
	var callback:(BeatNativePrinting, AnyObject?) -> ()
	var progressPanel:NSPanel = NSPanel(contentRect: NSMakeRect(0, 0, 350, 30), styleMask: [.docModalWindow], backing: .buffered, defer: false)
	var host:NSWindow
	var operation:BeatPrintingOperation = .toPrint
	
	var pageViews:[BeatPaginationPageView] = []
	var url:URL?
	
	
	var paginations:[BeatPaginationManager] = []
	
	/**
	 Begins a print operation. **Note**: the operation is run asynchronously, so this virtual view has to be owned by another object for the duration of the process.
	 - parameter window: The window which owns this operation
	 - parameter operation: Either `.toPreview` (temporary PDF file), `.toPDF` (save result into a PDF)  or `.toPrint` (sends the result to macOS printing panel)
	 - parameter settings: Export settings
	 - parameter delegate: Optional document delegate. If set, `screenplay` object will be requested from the parser of current document.
	 - parameter screenplays: An array of screenplay objects (containing title page and lines). If you have a delegate set, this can be `nil`.
	 - parameter callback: Closure run after printing is done
	 */
	@objc init(window:NSWindow, operation:BeatPrintingOperation, settings:BeatExportSettings, delegate:BeatEditorDelegate?, screenplays:[BeatScreenplay]?, callback: @escaping (BeatNativePrinting, AnyObject?) -> ()) {
		self.delegate = delegate
		
		if let screenplay = BeatScreenplay.from(delegate?.parser, settings: settings) {
			self.screenplays = [screenplay]
		} else {
			self.screenplays = screenplays ?? [BeatScreenplay()]
		}
		
		self.host = window
		self.callback = callback
		
		self.renderer = BeatRenderer(settings: settings)
		self.settings = settings

		// Create a pagination for each of these screenplays
		for _ in self.screenplays {
			let pagination = BeatPaginationManager(settings: settings, delegate: nil, renderer: renderer, livePagination: false)
			paginations.append(pagination)
		}
		
		//self.pagination = BeatPaginationManager(settings: settings, delegate: nil, renderer: renderer, livePagination: false)
		self.operation = operation
		
		let size = BeatPaperSizing.size(for: self.settings.paperSize)
		let frame = NSMakeRect(0, 0, size.width, size.height)
		super.init(frame: frame)
		
		// Render the screenplay
		paginateAndRender()
	}
	
	@objc convenience init(window:NSWindow, operation:BeatPrintingOperation, delegate:BeatEditorDelegate, callback:@escaping (BeatNativePrinting, AnyObject?) -> ()) {
		self.init(window: window, operation: operation, settings: delegate.exportSettings, delegate: delegate, screenplays: nil, callback: callback)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	var numberOfPages:Int {
		var pageCount = 0
		for pagination in self.paginations {
			pageCount += pagination.pages.count
			
			// Add title page to page count if needed
			pageCount += (pagination.hasTitlePage) ? 1 : 0
		}
		
		return pageCount
	}
	
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		// NOTE: Page numbers begin from 1
		range.pointee = NSMakeRange(1, self.numberOfPages)
		return true
	}
	
	override func rectForPage(_ page: Int) -> NSRect {
		self.subviews.removeAll()

		let pageView = self.pageViews[page - 1] // -1 because this is an array index
		self.addSubview(pageView)
		
		return NSMakeRect(0, 0, self.frame.width, self.frame.height)
	}
	
	var data:NSMutableData = NSMutableData()
	/// Paginates all the screenplays in queue and renders them onto screen
	func paginateAndRender() {
		DispatchQueue.global(qos: .userInteractive).async {
			for i in 0 ..< self.screenplays.count {
				let pagination = self.paginations[i]
				pagination.newPagination(screenplay: self.screenplays[i])
			}
			
			DispatchQueue.main.sync {
				// PDF operations require a URL. Temporary one for preview, user-selected for export.
				if self.operation == .toPreview {
					self.url = self.tempURL()
				}
				else if self.operation == .toPDF {
					// Request URL from user
					self.url = self.getURLforPDF()
					if (!(self.url?.startAccessingSecurityScopedResource() ?? false)) {
						print("ERROR")
						return
					}
				}
				
				// No URL set for PDF operations, just exit this bowling alley
				if (self.url == nil && self.operation == .toPDF) {
					print(self.className, "- no URL set")
					self.printOperationDidRun(nil, success: false, contextInfo: nil)
					return
				}
				
				// Create page views
				self.createPageViews()
				
				let printInfo = NSPrintInfo()
				printInfo.horizontalPagination = .fit
				printInfo.verticalPagination = .fit

				// We don't want *any* margins (they are drawn on page)
				printInfo.leftMargin = 0.0
				printInfo.rightMargin = 0.0
				printInfo.topMargin = 0.0
				printInfo.bottomMargin = 0.0
				printInfo.jobDisposition = .spool
								
				// Special rules for PDF export
				if (self.operation != .toPrint) {
					// Convert URL to NSURL
					let url:NSURL = NSURL(fileURLWithPath: self.url!.path)
					
					printInfo.paperSize = BeatPaperSizing.size(for: self.settings.paperSize)
					printInfo.jobDisposition = .save
					printInfo.dictionary().setObject(url, forKey: NSPrintInfo.AttributeKey.jobSavingURL as NSCopying)
				}
				
				// Create the actual print operation with specific settings for preview and printing options
				let printOperation = NSPrintOperation(view: self, printInfo: printInfo)
				printOperation.showsProgressPanel = (self.operation != .toPreview)
				printOperation.showsPrintPanel = (self.operation == .toPrint)
				
				// Run print operation
				if self.operation == .toPrint {
					printOperation.runModal(for: self.host, delegate: self, didRun: nil, contextInfo: nil)
				} else {
					// PDF operations have to run asynchronously
					printOperation.runModal(for: self.host, delegate: self, didRun: #selector(self.printOperationDidRun), contextInfo: nil)
				}
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
			
			self.url?.stopAccessingSecurityScopedResource()
			
			callback(self, NSURL(fileURLWithPath: url.relativePath))
		} else {
			// Inform that the printing was successful
			callback(self, nil)
		}
	}

	/// Creates all page views in memory
	func createPageViews() {
		self.pageViews = []
		
		for pagination in self.paginations {
			if pagination.hasTitlePage {
				// Add title page
				let titlePageView = BeatTitlePageView(titlePage: pagination.titlePage, settings: self.settings)
				pageViews.append(titlePageView)
			}
			
			for page in pagination.pages {
				autoreleasepool {
					let pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: nil, titlePage: false)
					pageViews.append(pageView)
				}
			}
		}
	}
	
	
	// MARK: - File access
	
	/// Returns a temporary URL for PDF preview
	func tempURL() -> URL {
		
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("beatPreview")
			.appendingPathExtension("pdf")
		return url
	}
	
	func getURLforPDF() -> URL? {
		var filename = "Untitled"
		if self.delegate != nil {
			filename = self.delegate!.fileNameString()
		}

		let saveDialog = NSSavePanel()
		saveDialog.allowedFileTypes = ["pdf"]
		saveDialog.nameFieldStringValue = filename
		
		if (self.window != nil) {
			// If we are running this from a document, let's use a sheet
			saveDialog.beginSheetModal(for: self.window!) { value in
				let response = value as NSApplication.ModalResponse
				
				if (response == .OK) {
					self.url = saveDialog.url
				}
				else {
					self.url = nil
				}
			}
			return self.url
			
		} else {
			// Else, we're using a normal modal
			let response = saveDialog.runModal()
			if (response == .OK) {
				return saveDialog.url
			} else {
				return nil
			}
		}
	}
	
}
