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
	var renderer:BeatRendering?
	@objc var timer:Timer?
	var paginationUpdated = false
	var lastChangeAt = NSMakeRange(0, 0)
	
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
	
	// MARK: - Initialization
	
	override init() {
		super.init()
			
		// Create render manager
		self.renderer = BeatRendering(settings: settings)
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
	}

	
	// MARK: - Delegate methods (delegated from delegate)
	@objc var parser: ContinuousFountainParser? { return delegate?.parser }
	
	
	// MARK: - Creating  preview data
	
	var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
	
	/// Preview data can be created either in background (async) or in main thread (sync).
	/// - note: This method doesn't create the actual preview yet, just paginates it and prepares the data ready for display.
	@objc func createPreview(changedRange range:NSRange, sync:Bool) {
		// Add index to changed indices
		changedIndices.add(in: range)
		
		// Let's invalidate the timer (if it exists)
		self.timer?.invalidate()
		self.paginationUpdated = false
		self.lastChangeAt = range
		
		guard let parser = delegate?.parser else { return }
		
		if (sync) {
			// Store revisions into lines
			self.delegate?.bakeRevisions()
			
			// Create pagination
			pagination?.newPagination(screenplay: parser.forPrinting(), settings: self.settings, forEditor: true, changeAt: range.location)
			
			if self.delegate?.previewVisible() ?? false {
				renderOnScreen()
			}
			
		} else {
			// Paginate and create preview with 1 second delay
			timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
				// Store revisions into lines in sync
				self.delegate?.bakeRevisions()

				// Dispatch pagination to a background thread after one second
				DispatchQueue.global(qos: .utility).async { [weak self] in
					self?.pagination?.newPagination(screenplay: parser.forPrinting(),
													settings: self?.settings ?? BeatExportSettings(),
													forEditor: true,
													changeAt: self?.changedIndices.firstIndex ?? 0)
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
	
	@objc func reloadStyles() {
		self.renderer?.reloadStyles()
		
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
		
		// Check if pagination is up to date
		if !paginationUpdated {
			createPreview(changedRange: NSMakeRange(self.changedIndices.firstIndex, 0), sync: true)
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
						
						var s = pageView.textView!.string
						if (s.count > 150) { s = s.substring(range: NSMakeRange(0, 150)) }
						
						pageView.update(page: page, settings: self.settings)
					} else {
						// .. and if not, create a new page view.
						pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: self)
						previewView.addPage(page: pageView)
					}
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
		
		self.titlePage = nil
	}

	/// Update container size based on page count
	func updateSize() {
		let pageSize = self.pageViews.first?.frame.size ?? NSSize(width: 0, height: 0)
		let height = (self.pageViews.last?.frame.height ?? 0.0) + (self.pageViews.last?.frame.origin.y ?? 0.0) + self.bottomSpacing
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, pageSize.width, height)
		self.frame = NSMakeRect(0, 0, pageSize.width, height)
	}
	
	func updatePagePositions() {
		var views = [BeatPaginationPageView]()
		if self.titlePage != nil {
			views.append(self.titlePage!)
		}
		views.append(contentsOf: self.pageViews)
		
		var y = bottomSpacing
		for pageView in views {
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
	
	func updateTitlePage(content:[[String: [Line]]]) {
		// If no title page data is provided, let's try to remove any existing title page
		if content.count == 0 {
			guard let titlePage = self.titlePage else { return }
			
			// Remove from superview and nil
			titlePage.removeFromSuperview()
			self.titlePage = nil
			updatePagePositions()
			
			return
		}
		
		// Update or create title page
		if (self.titlePage != nil) {
			// Update title page
			self.titlePage?.updateTitlePage(content)
		} else {
			// Create title page
			self.titlePage = BeatTitlePageView(previewController: self.previewController, titlePage: content, settings: self.previewController!.settings)
			self.addSubview(self.titlePage!)
		}
		
		updatePagePositions()
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
	
	override func cancelOperation(_ sender: Any?) {
		guard let owner = window?.windowController?.owner as? AnyObject else { return }
		if owner.responds(to: #selector(cancelOperation)) {
			owner.cancelOperation(sender)
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
		
		clampedOrigin.x = floor((bounds.width - documentViewFrame.width) / -2)

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

class CenteringScrollView: NSScrollView {
	override func scrollWheel(with event: NSEvent) {
		let fixedEvent = event.cgEvent!.copy()!
		fixedEvent.setDoubleValueField(CGEventField.scrollWheelEventDeltaAxis2, value: 0.0)
		
		let newEvent = NSEvent.init(cgEvent: fixedEvent)
		super.scrollWheel(with: newEvent!)
	}
	
	override func cancelOperation(_ sender: Any?) {
		guard let owner = window?.windowController?.owner as? NSResponder else {
			print("No owner")
			return
		}
		owner.cancelOperation(sender)
	}
}
