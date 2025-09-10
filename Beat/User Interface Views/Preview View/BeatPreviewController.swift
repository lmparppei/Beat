//
//  BeatPreviewController.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.12.2022.
//  Copyright © 2022-2024 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This is the macOS implementation of preview manager.
 The main difference is the preview creation. At one point I could take a look at how iOS preview handles
 pages using a data source and only loading them when needed.
 
 */

import AppKit
import BeatCore.BeatEditorDelegate
import BeatPagination2

fileprivate let sidebarWidth = 158.0

@objc public class BeatPreviewController:BeatPreviewManager {

	var renderer:BeatRenderer?
	var optionsPopover:NSPopover?
	
	@IBOutlet weak var scrollView:CenteringScrollView?
	@IBOutlet weak var thumbnailView:BeatPageThumbnailView?
	@IBOutlet weak var thumbnailViewConstraint:NSLayoutConstraint?
	
	let thumbnailViewWidth = 160.0
	
	
	// MARK: - Creating  preview data
	
	var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
	
	public override func awakeFromNib() {
		super.awakeFromNib()
		if #available(macOS 12.0, *) {
			if let hideThumbnailView = BeatUserDefaults.shared().get("hideThumbnailView") as? Bool {
				setThumbnailViewHidden(hideThumbnailView)
			}
		}
	}
	
	@objc override public func reload(with pagination: BeatPagination) {
		// We should migrate to a data source model on macOS as well, but let's just cast the view this time
		if let previewView = self.previewView as? BeatPreviewView {
			previewView.updatePages(pagination, settings: self.settings, controller: self)
			//self.thumbnailView?.reloadData()
		}
	}
	
	public override func didEndRendering() {
		self.thumbnailView?.reloadData()
	}
	
	@objc override public func scrollToRange(_ range:NSRange) {
		guard let scrollView = self.scrollView,
			  let previewView = self.previewView as? BeatPreviewView else { return }
		
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
				
				// Select page in thumbnail view
				if let pageIndex = previewView.pageViews.firstIndex(of: pageView) {
					// We might need to add one to page index because title page is not part of `previewView.pageViews
					let offset = (self.pagination?.hasTitlePage ?? false) ? 1 : 0
					let idxPath = IndexPath(item: pageIndex+offset, section: 0)
					thumbnailView?.selectItems(at: [idxPath], scrollPosition: .top)
					thumbnailView?.queuedSelection = idxPath
				}
				
				return
			}
		}
	}
	
	func setThumbnailViewHidden(_ hidden:Bool) {
		if hidden {
			self.thumbnailViewConstraint?.constant = 0.0
		} else {
			self.thumbnailView?.reloadData()
			self.thumbnailViewConstraint?.constant = sidebarWidth
		}
	}

}

