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
		guard let previewView = self.previewView,
			  let pagination = self.pagination
		else {
			return
		}

		// This flag determines if the preview should refresh after pagination has finished. Reset it.
		renderImmediately = false
					
		// Some more guard clauses
		if !paginationUpdated {
			// If pagination is not up to date, start loading animation and wait for the operation to finish.
			startLoadingAnimation()
			renderImmediately = true
			return
		} else if !pagination.hasPages {
			// Pagination has no results. Clear the view and remove animations.
			endLoadingAnimation()
			previewView.clear()
			return
		}
		
		DispatchQueue.global(qos: .userInitiated).async {
			// Create page strings in background
			// At least some of the pages are usually cached, so this should be pretty fast.
			let pages = pagination.pages
			_ = pages.map { $0.attributedString() }
			
			DispatchQueue.main.async {
				if let finishedPagination = pagination.finishedPagination {
					previewView.updatePages(finishedPagination, settings: self.settings, controller: self)
				}
				
				// Scroll view to the last edited position
				self.scrollToRange(self.delegate?.selectedRange ?? NSMakeRange(0, 0))
				
				// Hide animation
				self.endLoadingAnimation()
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
	
	func startLoadingAnimation() {
		self.previewView?.fadeOutPages()
		self.spinner?.isHidden = false
		self.spinner?.startAnimation(nil)
	}
	func endLoadingAnimation() {
		self.spinner?.isHidden = true
		self.spinner?.stopAnimation(nil)
	}
}

