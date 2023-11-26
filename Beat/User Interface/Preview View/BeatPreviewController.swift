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

@objc protocol BeatNativePreviewDelegate:BeatEditorDelegate {
	@objc func paginationFinished(_ operation:BeatPagination, indices:NSIndexSet)
	@objc func previewVisible() -> Bool
}

final class BeatPreviewController:NSObject, BeatPaginationManagerDelegate {
		
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var delegate:BeatNativePreviewDelegate?
	@IBOutlet weak var scrollView:CenteringScrollView?
	@IBOutlet weak var spinner:NSProgressIndicator?
	@IBOutlet weak var quickLookView:NSView?
	
	@objc var pagination:BeatPaginationManager?
	var renderer:BeatRenderer?
	@objc var timer:Timer?
	var paginationUpdated = false
	var lastChangeAt = NSMakeRange(0, 0)
	
	/// Returns export settings from editor
	var settings:BeatExportSettings {
		guard let settings = self.delegate?.exportSettings else {
			// This shouldn't ever happen, but if the delegate fails to return settings, we'll just create our own.
			return BeatExportSettings.operation(.ForPrint, document: nil, header: "", printSceneNumbers: true)
		}

		return settings
	}
	
	var exportSettings:BeatExportSettings {
		return self.delegate?.exportSettings ?? BeatExportSettings()
	}
	
	// MARK: - Initialization
	
	override init() {
		super.init()
			
		// Create render manager
		self.renderer = BeatRenderer(settings: settings)
		self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer, livePagination: true)
	}
	
	override func awakeFromNib() {
		if settings.operation != .ForQuickLook {
			self.scrollView?.magnification = 1.2;
		}
		
		self.pagination?.editorDelegate = self.delegate
	}
	
	
	// MARK: - Pagination delegation
	
	/// When pagination has finished, we'll inform the host document and mark our pagination as done
	func paginationDidFinish(_ operation:BeatPagination) {
		self.paginationUpdated = true
		
		// Let's tell the delegate this, too
		self.delegate?.paginationFinished(operation, indices: self.changedIndices)
		
		//  Clear changed indices
		self.changedIndices.removeAllIndexes()
		
		// Return to main thread and render stuff on screen if needed
		DispatchQueue.main.async { [weak self] in
			if self?.delegate?.previewVisible() ?? false {
				self?.renderOnScreen()
			}
		}
	}

	
	// MARK: - Delegate methods (delegated from delegate)
	@objc var parser: ContinuousFountainParser? { return delegate?.parser }
	
	
	// MARK: - Creating  preview data
	
	var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
	
	/// Preview data can be created either in background (async) or in main thread (sync).
	/// - note: This method doesn't create the actual preview yet, just paginates it and prepares the data ready for display.
	@objc func createPreview(changedRange range:NSRange, sync:Bool) {
		// Add index to changed indices
		let changedRange = (range.length > 0) ? range : NSMakeRange(range.location, 1);
		changedIndices.add(in: changedRange)
		
		// Let's invalidate the timer (if it exists)
		self.timer?.invalidate()
		self.paginationUpdated = false
		self.lastChangeAt = changedRange
		
		guard let parser = delegate?.parser else { return }
		
		if (sync) {
			// Store revisions into lines
			self.delegate?.bakeRevisions()
			
			// Create pagination
			if let screenplay = BeatScreenplay.from(parser, settings: self.settings) {
				pagination?.newPagination(screenplay: screenplay, settings: self.settings, forEditor: true, changeAt: changedIndices.firstIndex)
			}
		} else {
			// Paginate and create preview with 1 second delay
			self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
				// Store revisions into lines in sync
				self.delegate?.bakeRevisions()

				// Dispatch pagination to a background thread after one second
				DispatchQueue.global(qos: .utility).async { [weak self] in
					if let screenplay = BeatScreenplay.from(parser, settings: self?.settings) {
						self?.pagination?.newPagination(screenplay: screenplay,
														settings: self?.settings ?? BeatExportSettings(),
														forEditor: true,
														changeAt: self?.changedIndices.firstIndex ?? 0)
					}
				}
			})
		}
	}
	
	/// Creates a new preview based on change in given range
	@objc func invalidatePreview(at range:NSRange) {
		self.createPreview(changedRange: range, sync: false)
	}
	
	/// Rebuilds the whole preview
	@objc func resetPreview() {
		if !Thread.isMainThread {
			print("WARNING: resetPreview() should only be called from main thread.")
		}
		
		// Reset styles
		self.renderer?.reloadStyles()
		
		self.previewView?.clear()
		
		self.pagination?.finishedPagination = nil
		self.paginationUpdated = false
		
		if self.delegate?.previewVisible() ?? false {
			// If the preview was cleared when in preview mode, let's create it in sync
			self.renderOnScreen()
		} else {
			self.createPreview(changedRange: NSMakeRange(0, self.delegate?.text().count ?? 0), sync: false)
		}
	}
	

	/// Renders pages on screen
	@objc func renderOnScreen() {
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
			createPreview(changedRange: NSMakeRange(self.changedIndices.firstIndex, 0), sync: true)
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

