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

@objc protocol BeatNativePreviewDelegate:BeatEditorDelegate {
	@objc func paginationFinished(_ pages:[BeatPaginationPage])
	var contdString: String { get }
	var moreString: String { get }
}

final class BeatPreviewController:NSObject, BeatPaginationManagerDelegate {
		
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var delegate:BeatNativePreviewDelegate?
	@IBOutlet weak var scrollView:CenteringScrollView?
	@IBOutlet weak var spinner:NSProgressIndicator?
	
	@objc var pagination:BeatPaginationManager?
	var renderer:BeatRendering?
	var timer:Timer?
	var paginationUpdated = false
	var lastChangeAt = 0
	
	/// Returns export settings from editor
	var settings:BeatExportSettings {
		if self.delegate?.exportSettings == nil {
			// This shouldn't ever happen, but if the delegate fails to return settings, we'll just create our own.
			return BeatExportSettings.operation(.ForPrint, document: nil, header: "", printSceneNumbers: true)
		} else {
			return self.delegate!.exportSettings
		}
	}
	
	var exportSettings:BeatExportSettings? {
		return self.delegate?.exportSettings
	}
	
	var contdString: String { return self.delegate?.contdString ?? "" }
	var moreString: String { return self.delegate?.moreString ?? "" }
	
	
	// MARK: - Initialization
	
	override init() {
		super.init()
			
		// Create render manager
		self.renderer = BeatRendering(settings: settings)
		self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer, livePagination: true)
	}
	
	override func awakeFromNib() {
		self.scrollView?.magnification = 1.2;
	}
	
	
	// MARK: - Pagination delegation
	
	/// When pagination has finished, we'll inform the host document and mark our pagination as done
	func paginationDidFinish(pages: [BeatPaginationPage]) {
		self.paginationUpdated = true
		self.delegate?.paginationFinished(pages)
	}

	
	// MARK: - Delegate methods (delegated from delegate)
	@objc var parser: ContinuousFountainParser? { return delegate?.parser }
	
	
	// MARK: - Creating  preview data
	
	/// Preview data can be created either in background (async) or in main thread (sync).
	/// - note: This method doesn't create the actual preview yet, just paginates it.
	@objc func createPreview(changeAt index:Int, sync:Bool) {
		// Let's invalidate the timer (if it exists)
		self.timer?.invalidate()
		self.paginationUpdated = false
		self.lastChangeAt = index
		
		guard let parser = delegate?.parser else { return }
		if (sync) {
			pagination?.newPagination(screenplay: parser.forPrinting(), settings: self.settings, forEditor: true, changeAt: index)
		} else {
			timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
				// Dispatch pagination to a background thread after one second
				DispatchQueue.global(qos: .utility).async {
					self.pagination?.newPagination(screenplay: parser.forPrinting(), settings: self.settings, forEditor: true, changeAt: index)
				}
			})
		}
	}
	
	@objc func clearPreview() {
		self.previewView?.clear()
	}
	
	/// Renders pages on screen
	@objc func renderOnScreen() {
		// Show spinner while loading
		self.spinner?.isHidden = false
		self.spinner?.startAnimation(nil)
		
		guard let previewView = self.previewView,
			  let pagination = self.pagination
		else { return }
		
		// Check if pagination is up to date
		if !paginationUpdated {
			createPreview(changeAt: self.lastChangeAt, sync: true)
		}
				
		// Create page strings in background
		// At least some of the pages are usually cached, so this should be pretty fast.
		DispatchQueue.global(qos: .userInteractive).async {
			guard let pages = self.pagination?.pages
			else { return }
			
			// Add strings into an array (surprisingly slow in Swift)
			var strings:[NSAttributedString] = []
			for p in pages {
				strings.append(p.attributedString())
			}
			
			DispatchQueue.main.async {
				// Back in main thread, create (or reuse) page content
				
				// Iterate through paginated pages
				for i in 0 ..< pages.count {
					let page = pages[i]
					
					var pageView:BeatPaginationPageView
					if i < previewView.pageViews.count {
						// If a page view already exist in the given page number, let's reuse it.
						pageView = previewView.pageViews[i]
						pageView.update(page: page, settings: self.settings)
					} else {
						// .. and if not, create a new page view.
						pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: self)
						previewView.addPage(page: pageView)
					}
				}
				
				// Add title page
				if pagination.titlePage.count > 0 {
					previewView.addTitlePage(titlePageContent: pagination.titlePage)
				}
				
				// Remove excess views
				let pageCount = pages.count + ((pagination.titlePage.count > 0) ? 1 : 0)
				while previewView.pageViews.count > pageCount {
					previewView.removePage(at: previewView.pageViews.count - 1)
				}
				
				// Update container size
				previewView.updateSize()
				
				// Scroll view to the last edited position
				self.scrollToRange(self.delegate?.selectedRange() ?? NSMakeRange(0, 0))
				
				// Hide animation
				self.spinner?.stopAnimation(nil)
			}
		}
	}
	
	@objc func scrollToRange(_ range:NSRange) {
		guard let scrollView = self.scrollView else { return }
		
		// First find the actual page view
		for pageView in previewView!.pageViews {
			guard let page = pageView.page,
				let textView = pageView.textView
			else { continue }
			
			// The range is not represented by this page
			if !NSLocationInRange(range.location, page.representedRange()) { continue }
			
			// Get range in *attributed string* for given location in editor text
			let range = page.range(forLocation: range.location)
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
		delegate?.returnToEditor()
		self.delegate?.setSelectedRange(range)
		self.delegate?.scroll(to: range, callback: {})
	}
}

/// This view holds the pages
final class BeatPreviewView:NSView {
	override var isFlipped: Bool { return true }
	var pageViews:[BeatPaginationPageView] = []
	var bottomSpacing = 10.0
	var titlePage:BeatTitlePageView?
	
	@IBOutlet weak var previewController:BeatPreviewController?
		
	func clear() {
		pageViews.removeAll()
		
		for pageView in self.subviews {
			pageView.removeFromSuperview()
		}
	}

	/// Update container size based on page count
	func updateSize() {
		let pageSize = self.pageViews.first?.frame.size ?? NSSize(width: 0, height: 0)
		let height = (self.pageViews.last?.frame.height ?? 0.0) + (self.pageViews.last?.frame.origin.y ?? 0.0) + self.bottomSpacing
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, pageSize.width, height)
		self.frame = NSMakeRect(0, 0, pageSize.width, height)
	}
	
	func updatePagePositions() {
		var y = bottomSpacing
		for pageView in pageViews {
			pageView.frame = NSMakeRect(0, y, pageView.frame.width, pageView.frame.height)
			y += pageView.frame.height + bottomSpacing
		}
	}
	
	func insertPage(page:BeatPaginationPageView, atIndex index:Int) {
		self.addSubview(page)
		pageViews.insert(page, at: index)
		updatePagePositions()
	}
	
	/// Adds a page view onto the page
	func addPage(page:BeatPaginationPageView) {
		var y = (self.pageViews.last?.frame.height ?? 0.0) + (self.pageViews.last?.frame.origin.y ?? 0.0)
		y += self.bottomSpacing
		
		let frame = NSMakeRect(0, y, page.frame.width, page.frame.height)
		page.frame = frame
		
		self.addSubview(page)
		self.pageViews.append(page)
	}
	
	func addTitlePage(titlePageContent:[[String: [Line]]]) {
		if (self.previewController == nil) { return }
		
		if (self.titlePage != nil) {
			print("Updating title page...")
			// Update title page
			self.titlePage?.updateTitlePage(titlePageContent)
		} else {
			self.titlePage = BeatTitlePageView(previewController: self.previewController, titlePage: titlePageContent, settings: self.previewController!.settings)
			insertPage(page: self.titlePage!, atIndex: 0)
		}
	}
	func removeTitlePage() {
		if (self.titlePage == nil) { return }
		else {
			self.titlePage = nil
			removePage(at: 0)
		}
	}
	
	func removePage(at idx:Int) {
		let pageView = self.pageViews[idx]
		pageView.removeFromSuperview()
		
		self.pageViews.remove(at: idx)
		
		// If we didn't remove the last page, update page positions
		if (idx != pageViews.count) {
			updatePagePositions()
		}
			
	}
}

final class CenteringClipView: NSClipView {
	// Stolen from Victor Gama, https://vito.io/articles/2021-12-04-centered-nsscrollview
	
	// Force the event value, works only when pinch method stops
	override func setFrameSize(_ newSize: NSSize) {
		var fixedSize = newSize
		fixedSize.width = floor(newSize.width)
		
		super.setFrameSize(fixedSize)
	}
	
	// Force the event value, works only when pinch method stops
	override func setBoundsOrigin(_ newOrigin: NSPoint) {
		let documentViewFrame = documentView!.frame
		var clampedOrigin = newOrigin
		
		clampedOrigin.x = (bounds.width - documentViewFrame.width) / -2
		super.setBoundsOrigin(clampedOrigin)
	}
		
	override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
		var constrainedClipViewBounds = super.constrainBoundsRect(proposedBounds)
		guard let documentView = documentView else {
			return constrainedClipViewBounds
		}
		
		let documentViewFrame = documentView.frame
		
		// If proposed clip view bounds width is greater than document view frame width, center it horizontally.
		if documentViewFrame.width < proposedBounds.width {
			constrainedClipViewBounds.origin.x = floor((proposedBounds.width - documentViewFrame.width) / -2.0)
		}
		
		// If proposed clip view bounds height is greater than document view frame height, center it vertically.
		if documentViewFrame.height < proposedBounds.height {
			constrainedClipViewBounds.origin.y = floor((proposedBounds.height - documentViewFrame.height) / -2.0)
		}
		
		return constrainedClipViewBounds
	}
}

final class FlippedView:NSView {
	override var isFlipped: Bool { return true }
}

final class CenteringScrollView: NSScrollView {
	override func scrollWheel(with event: NSEvent) {
		let fixedEvent = event.cgEvent!.copy()!
		fixedEvent.setDoubleValueField(CGEventField.scrollWheelEventDeltaAxis2, value: 0.0)
		
		let newEvent = NSEvent.init(cgEvent: fixedEvent)
		super.scrollWheel(with: newEvent!)
	}
}
