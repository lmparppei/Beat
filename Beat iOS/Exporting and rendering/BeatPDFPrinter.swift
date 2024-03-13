//
//  BeatPDFPrinter.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 29.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class  provides a native `UIView`-based  printing component for iOS version of Beat.
 
 You need to provide export settings, and a window which owns this operation. If you specify a delegate, screenplay content will be automatically requested from there. Otherwise you need to send a `BeatScreenplay` object.
 
 Note that the pages are created asynchronously, so you need to **retain** this class when printing.
 
 */

import UIKit
import PDFKit
import BeatCore
import BeatPagination2

class BeatPDFPrinter:NSObject {
	var delegate:BeatEditorDelegate?
	var settings:BeatExportSettings

	var renderer:BeatRenderer
	var screenplays:[BeatScreenplay]
	var callback:(Data?) -> ()
	
	var pageViews:[BeatPaginationPageView] = []
	var url:URL?
	
	weak var temporaryView:UIView?
	
	var paginations:[BeatPaginationManager] = []
	
	/**
	 Begins a print operation. **Note**: the operation is run asynchronously, so this virtual view has to be owned by another object for the duration of the process.
	 - parameter settings: Export settings
	 - parameter delegate: Optional document delegate. If set, `screenplay` object will be requested from the parser of current document.
	 - parameter screenplays: An array of screenplay objects (containing title page and lines). If you have a delegate set, this can be `nil`.
	 - parameter callback: Closure run after printing is done
	 */
	@objc init(settings:BeatExportSettings, delegate:BeatEditorDelegate?, temporaryView:UIView?, screenplays:[BeatScreenplay]?, callback: @escaping (Data?) -> ()) {
		self.delegate = delegate
		self.temporaryView = temporaryView
		
		// If we have a delegate connected, let's gather the screenplay from there, otherwise we'll use the ones provided at init
		if delegate != nil, let screenplay = BeatScreenplay.from(delegate?.parser, settings: settings) {
			self.screenplays = [screenplay]
		} else {
			self.screenplays = screenplays ?? [BeatScreenplay()]
		}
		
		// Store the escaping block
		self.callback = callback
		
		self.renderer = BeatRenderer(settings: settings)
		self.settings = settings

		// Create a pagination for each of these screenplays
		for _ in self.screenplays {
			let pagination = BeatPaginationManager(settings: settings, delegate: nil, renderer: renderer, livePagination: false)
			paginations.append(pagination)
		}
		
		super.init()
		
		// Render the screenplay
		paginateAndRender()
	}
	
	@objc convenience init(delegate:BeatEditorDelegate, temporaryView:UIView?, callback:@escaping (Data?) -> ()) {
		self.init(settings: delegate.exportSettings, delegate: delegate, temporaryView:temporaryView, screenplays: nil, callback: callback)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
		
	/// Paginates all the screenplays in queue and renders them onto screen
	func paginateAndRender() {
		DispatchQueue.global(qos: .userInteractive).async {
			for i in 0 ..< self.screenplays.count {
				let pagination = self.paginations[i]
				pagination.newPagination(screenplay: self.screenplays[i])
			}
			
			DispatchQueue.main.sync {
				// Create page views and PDF
				self.createPageViews()
				let data = self.createPDF()
				
				self.callback(data)
			}
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
					let pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: nil)
					pageViews.append(pageView)
				}
			}
		}
	}
	
	func createPDF() -> Data {
		let pdfMetaData = [
			kCGPDFContextCreator: "(beat)"
		]
		
		let format = UIGraphicsPDFRendererFormat()
		format.documentInfo = pdfMetaData as [String: Any]
		
		let pageSize = BeatPaperSizing.size(for: settings.paperSize)
		let pageRect = CGRectMake(0.0, 0.0, pageSize.width, pageSize.height)
		
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
		
		let data = renderer.pdfData { (context) in
			for page in self.pageViews {
				temporaryView?.addSubview(page)
				page.setNeedsLayout()
				page.setNeedsDisplay()
				
				context.beginPage()
				
				let cgContext = context.cgContext
				
				// Iterate through each text view on page
				for textView in page.textViews {
					
					guard let location = textView.textLayoutManager?.documentRange.location else {
						// This view probably uses TextKit 1, in which case all hope is lost
						continue
					}
					
					textView.textLayoutManager?.enumerateTextLayoutFragments(from: location, options: [.ensuresLayout, .estimatesSize, .ensuresExtraLineFragment], using: { fragment in
						
						let frame = fragment.layoutFragmentFrame
						var origin = textView.frame.origin
						
						origin.x += textView.textContainerInset.left
						origin.y += textView.textContainerInset.top
						
						var actualFrame = frame
						actualFrame.origin.x += origin.x
						actualFrame.origin.y += origin.y
												
						// Draw text attachment
						if let provider = fragment.textAttachmentViewProviders.first, let view = provider.view {
							let attachmentFrame = fragment.frameForTextAttachment(at: fragment.rangeInElement.location)
							actualFrame.origin.y += attachmentFrame.origin.y
							
							cgContext.saveGState()
							cgContext.translateBy(x: actualFrame.origin.x, y: actualFrame.origin.y)
							view.layer.render(in: cgContext)
							cgContext.restoreGState()
							
							return true
						}
						
						if let paragraph = fragment as? BeatRenderingTextFragment {
							// Draw Beat fragments
							paragraph.draw(at: frame.origin, origin: origin, in: cgContext)
						} else {
							// Draw plain fragments
							fragment.draw(at: actualFrame.origin, in: cgContext)
						}
						return true
					})
				}
				
				page.removeFromSuperview()
			}
		}

		return data
	}
		
}
