//
//  BeatPreviewView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 29.10.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatParsing
import BeatPagination2

/// This view holds the pages
final class BeatPreviewView:NSView, BeatPreviewPageView {
	
	override var isFlipped: Bool { return true }
	var pageViews:[BeatPaginationPageView] = []
	var bottomSpacing = 10.0
	var titlePage:BeatTitlePageView?
	
	// This is unused for now. Look at how iOS version handles this.
	weak var dataSource: BeatPreviewPageViewDataSource?
	
	@IBOutlet weak var progressIndicator:NSProgressIndicator?
	
	@IBOutlet weak var previewController:BeatPreviewController?
	
	/// Clears the whole view
	func clear() {
		pageViews.removeAll()
		
		for pageView in self.subviews {
			pageView.removeFromSuperview()
		}
		
		self.titlePage = nil
	}

	/// Update container size based on page count
	func updateSize() {
		let views = self.allPageViews()
		
		guard let firstView = views.first, let lastView = views.last else {
			self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, 0, 0)
			self.frame = NSMakeRect(0, 0, 0, 0)
			return
		}
		
		let pageSize = firstView.frame.size
		let height = (lastView.frame.height) + (lastView.frame.origin.y) + self.bottomSpacing
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, pageSize.width, height)
		self.frame = NSMakeRect(0, 0, pageSize.width, height)
	}
	
	/// Returns ALL page views (including title page)
	func allPageViews() -> [BeatPaginationPageView] {
		var views = [BeatPaginationPageView]()
		
		if self.titlePage != nil { views.append(self.titlePage!) }
		views.append(contentsOf: self.pageViews)
		
		return views
	}
	
	func fadeOutPages() {
		// Dim out pages while we are refreshing the view
		pageViews.forEach { $0.alphaValue = 0.5 }
	}
	
	func updatePages(_ pagination:BeatPagination, settings:BeatExportSettings, controller:BeatPreviewManager) {
		guard let pages = pagination.pages as? [BeatPaginationPage] else {
			print("Updating pages failed")
			return
		}
		
		for i in 0..<pages.count {
			let page = pages[i]
			// Ensure ownership
			if page.delegate == nil {
				page.delegate = pagination as? BeatPageDelegate
			}
			
			var pageView:BeatPaginationPageView
			
			if i < self.pageViews.count {
				// If a page view already exists, reuse it
				pageView = pageViews[i]
				pageView.update(page: page, settings: settings)
			} else {
				// .. and if not, create a new page view.
				pageView = BeatPaginationPageView(page: page, content: nil, settings: settings, previewController: controller)
				self.addPage(page: pageView)
			}
			
			pageView.textView?.layout()
			pageView.textView?.needsDisplay = true
			pageView.display()
			pageView.animator().alphaValue = 1.0
		}
		
		// Remove excess views
		let pageCount = pages.count
		while pageViews.count > pageCount {
			removePage(at: pageViews.count - 1)
		}
		
		// Add title page if needed
		updateTitlePage(content: pagination.titlePage())

		// Update container size
		updateSize()
		
		self.needsLayout = true
		self.needsDisplay = true
	}
	
	
	/// Moves each page to its correct position inside the view
	func updatePagePositions() {
		let views = self.allPageViews()
		
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
	
	/// Updates title page with given array
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
	
	func removeLastPage() {
		self.removePage(at: self.pageViews.count - 1)
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
		
	func scrollToPage(_ pageIndex: Int) {
		//
	}

	func startLoadingAnimation() {
		fadeOutPages()
		progressIndicator?.isHidden = false
		progressIndicator?.startAnimation(nil)
	}
	func endLoadingAnimation() {
		progressIndicator?.isHidden = true
		progressIndicator?.stopAnimation(nil)
	}
	
}

// MARK: - Assisting views

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

open class FlippedView:NSView {
	override public var isFlipped: Bool { return true }
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
