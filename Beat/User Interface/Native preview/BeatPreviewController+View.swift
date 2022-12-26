//
//  BeatPreviewView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

@objc protocol BeatNativePreviewDelegate:BeatEditorDelegate {
	@objc func paginationFinished(_ pages:[BeatPaginationPage])
}

final class BeatPreviewController:NSObject, BeatPaginationManagerDelegate {
	
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var delegate:BeatNativePreviewDelegate?
	@IBOutlet weak var scrollView:CenteringScrollView?
	@IBOutlet weak var spinner:NSProgressIndicator?
	
	@objc var pagination:BeatPaginationManager?
	var renderer:BeatRendering?
	var timer:Timer?
	
	var settings:BeatExportSettings {
		if self.delegate?.exportSettings == nil {
			return BeatExportSettings.operation(.ForPrint, document: nil, header: "", printSceneNumbers: true)
		} else {
			return self.delegate!.exportSettings
		}
	}
	
	var exportSettings:BeatExportSettings? {
		return self.delegate?.exportSettings
	}
	
	override init() {
		super.init()
			
		// Create render manager
		self.renderer = BeatRendering(settings: settings)
		self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer, livePagination: true)
	}
	
	override func awakeFromNib() {
		self.scrollView?.magnification = 1.2;
	}
	
	// MARK: Delegate methods (delegated from delegate)
	@objc var parser: ContinuousFountainParser? { return delegate?.parser }
	
	// MARK: Create preview data
	/// Preview data can be created either in background (async) or in main thread (sync).
	/// - note: This method doesn't create the actual preview yet, just paginates it.
	@objc func createPreview(changeAt index:Int, sync:Bool) {
		// Let's invalidate the timer (if it exists)
		timer?.invalidate()
		
		guard let parser = delegate?.parser else { return }
		if (sync) {
			pagination?.newPagination(screenplay: parser.forPrinting(), settings: settings, forEditor: true, changeAt: index)
		} else {
			timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
				// Dispatch pagination to a background thread after one second
				DispatchQueue.global(qos: .utility).async {
					self.pagination?.newPagination(screenplay: parser.forPrinting(), settings: self.settings, forEditor: true, changeAt: index)
				}
			})
		}
	}

		
	func paginationDidFinish(pages: [BeatPaginationPage]) {
		self.delegate?.paginationFinished(pages)
	}
		
	@objc func renderOnScreen() {
		self.spinner?.isHidden = false
		self.spinner?.startAnimation(nil)
		
		DispatchQueue.global(qos: .userInteractive).async {
			guard let pages = self.pagination?.pages
			else { return }
			
			var strings:[NSAttributedString] = []
			
			for p in pages {
				strings.append(p.attributedString())
			}
			
			DispatchQueue.main.async {
				guard let previewView = self.previewView
				else { return }
				
				let size = BeatPaperSizing.size(for: self.settings.paperSize)
				
				for i in 0 ..< pages.count {
					let page = pages[i]
					
					var pageView:BeatPaginationPageView
					if i < previewView.pageViews.count {
						pageView = self.previewView!.pageViews[i]
						pageView.update(page: page, settings: self.settings)
					}
					else {
						pageView = BeatPaginationPageView(size: size, page: page, content: nil, settings: self.settings, previewController: self)
						previewView.addPage(page: pageView)
					}
				}
				
				// Remove excess views
				while previewView.pageViews.count > pages.count {
					previewView.removePage(at: previewView.pageViews.count - 1)
				}
				
				previewView.updateSize()
				self.scrollToRange(self.delegate?.selectedRange() ?? NSMakeRange(0, 0))
				
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
	
	@IBOutlet weak var previewController:BeatPreviewController?
		
	func clear() {
		pageViews.removeAll()
		
		for pageView in self.subviews {
			pageView.removeFromSuperview()
		}
	}

	/// Update container size based on page count
	func updateSize() {
		let pageSize = self.subviews.first?.frame.size ?? NSSize(width: 0, height: 0)
		let height = (self.subviews.last?.frame.height ?? 0.0) + (self.subviews.last?.frame.origin.y ?? 0.0) + self.bottomSpacing
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, pageSize.width, height)
		self.frame = NSMakeRect(0, 0, pageSize.width, height)
	}
	
	func addPage(page:BeatPaginationPageView) {
		var y = (self.subviews.last?.frame.height ?? 0.0) + (self.subviews.last?.frame.origin.y ?? 0.0)
		y += 10
		
		let frame = NSMakeRect(0, y, page.frame.width, page.frame.height)
		page.frame = frame
		
		self.addSubview(page)
		self.pageViews.append(page)
	}
	
	func removePage(at idx:Int) {
		let pageView = self.pageViews[idx]
		pageView.removeFromSuperview()
		
		self.pageViews.remove(at: idx)
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
