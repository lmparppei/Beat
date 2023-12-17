//
//  BeatPreviewView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class handles previews and pagination in editor.
 It's a mess and I apologize.
 
 */

import AppKit
import BeatCore.BeatEditorDelegate
import BeatPagination2

class BeatPreviewController:BeatPreviewManager {

	var renderer:BeatRenderer?
	
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var scrollView:CenteringScrollView?
	@IBOutlet weak var spinner:NSProgressIndicator?
	@IBOutlet weak var quickLookView:NSView?
		
	
	// MARK: - Initialization
	
	override init() {
		super.init()
			
		// Create renderer and pagination manager
		self.renderer = BeatRenderer(settings: settings)
		self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer, livePagination: true)
	}
	
	override func awakeFromNib() {
		if settings.operation != .ForQuickLook {
			self.scrollView?.magnification = 1.2;
		}
		
		self.pagination?.editorDelegate = self.delegate
	}
	
	
	// MARK: - Creating  preview data
	
	var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
	
	/// Rebuilds the whole preview
	@objc override func resetPreview() {
		if !Thread.isMainThread {
			print("WARNING: resetPreview() should only be called from main thread.")
		}
						
		super.resetPreview()
		
		// Reset styles
		self.renderer?.reloadStyles()
		self.previewView?.clear()
		
		if self.delegate?.previewVisible() ?? false {
			// If the preview was cleared when in preview mode, let's create it in sync
			self.renderOnScreen()
		} else {
			self.createPreview(withChangedRange: NSMakeRange(0, self.delegate?.text().count ?? 0), sync: false)
		}
	}
	

	/// Renders pages on screen
	@objc override func renderOnScreen() {
		// Show spinner while loading
		self.spinner?.isHidden = false
		self.spinner?.startAnimation(nil)
			
		guard let previewView = self.previewView,
			  let pagination = self.pagination
		else {
			print("Preview / pagination failed")
			return
		}
		
		// Hide pages
		for page in self.previewView?.pageViews ?? [] {
			page.alphaValue = 0.5
		}
		
		// Check if pagination is up to date
		if !paginationUpdated {
			var firstIndex = self.changedIndices.firstIndex
			if firstIndex == NSNotFound || firstIndex < 0 { firstIndex = 0 }
			
			createPreview(withChangedRange: NSMakeRange(firstIndex, 0), sync: true)
		}
		
		// Create page strings in background
		// At least some of the pages are usually cached, so this should be pretty fast.
		DispatchQueue.global(qos: .userInitiated).async {
			// If pagination is nil and/or the result has no page (and no title page), we'll just return without doing anything.
			if pagination.pages.count == 0 && !pagination.hasTitlePage { return }
			
			let pages = pagination.pages
			
			// Add strings into an array (surprisingly slow in Swift)
			var strings:[NSAttributedString] = []
			for p in pages {
				strings.append(p.attributedString())
			}
			
			DispatchQueue.main.async {
				// Back in main thread, create (or reuse) page content
				let finishedPagination = self.pagination?.finishedPagination
				
				// Iterate through paginated pages
				for i in 0 ..< pages.count {
					let page = pages[i]
					if page.delegate == nil { page.delegate = finishedPagination as? BeatPageDelegate }
					
					var pageView:BeatPaginationPageView
					if i < previewView.pageViews.count {
						// If a page view already exist in the given page number, let's reuse it.
						pageView = previewView.pageViews[i]
						
						var s = pageView.textView!.string
						if (s.count > 150) { s = s.substring(range: NSMakeRange(0, 150)) }
						
						pageView.update(page: page, settings: self.settings)
					} else {
						// .. and if not, create a new page view.
						pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: self)
						previewView.addPage(page: pageView)
					}
					
					pageView.alphaValue = 1.0
				}
				
				// Remove excess views
				let pageCount = pages.count
				while previewView.pageViews.count > pageCount {
					previewView.removePage(at: previewView.pageViews.count - 1)
				}
				
				// Add title page if needed
				previewView.updateTitlePage(content: pagination.titlePage)
				
				// Update container size
				previewView.updateSize()
				
				// Scroll view to the last edited position
				if (self.settings.operation != .ForQuickLook) {
					self.scrollToRange(self.delegate?.selectedRange ?? NSMakeRange(0, 0))
				} else {
					self.scrollToRange(NSMakeRange(0, 0))
				}
				
				// Hide animation
				self.spinner?.stopAnimation(nil)
			}
		}
	}
	
	@objc func scrollToRange(_ range:NSRange) {
		guard let scrollView = self.scrollView, let previewView = self.previewView else { return }
		
		// First find the actual page view
		for pageView in previewView.pageViews {
			guard let page = pageView.page,
				let textView = pageView.textView
			else { continue }
			
			// If the range is not represented by this page, continue
			if !NSLocationInRange(range.location, page.representedRange()) {
				continue
			}
			
			let range = page.range(forLocation: range.location) // Ask for the range in current attributed string
			
			if range.location != NSNotFound {
				guard let lm = textView.layoutManager else { return }

				let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
				let rect = lm.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
				
				let linePosition = pageView.frame.origin.y + textView.frame.origin.y + rect.origin.y
				let viewPortHeight = scrollView.contentView.frame.height * (1 / scrollView.magnification)
				
				let point = NSPoint(x: 0, y: linePosition + rect.size.height - viewPortHeight / 2)
				scrollView.contentView.setBoundsOrigin(point)
				
				return
			}
		}
	}
	
	/// Closes preview and selects the given range
	func closeAndJumpToRange(_ range:NSRange) {
		delegate?.returnToEditor?()
		self.delegate?.selectedRange = range
		self.delegate?.scroll(to: range, callback: {})
	}
}

