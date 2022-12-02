//
//  BeatPreviewView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

protocol BeatPreviewDelegate:BeatEditorDelegate {
	
}

final class BeatPreviewController:NSObject, BeatRenderDelegate {
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var textView:BeatTextView?
	@IBOutlet weak var delegate:BeatEditorDelegate?
	
	var renderer:BeatRenderManager?
	
	override init() {
		super.init()
	
		let settings = BeatExportSettings()
		settings.paperSize = delegate?.pageSize ?? .A4
		settings.revisions = BeatRevisions.revisionColors()

		// Create render manager
		self.renderer = BeatRenderManager(settings: settings, delegate: self)
	}
	
	var settings:BeatExportSettings {
		let settings = BeatExportSettings()
		settings.paperSize = delegate?.pageSize ?? .A4
		settings.printSceneNumbers = delegate?.printSceneNumbers ?? true
		settings.revisions = BeatRevisions.revisionColors()
		
		return settings
	}
	
	// MARK: Delegate methods (delegated from delegate)
	@objc var parser: ContinuousFountainParser? { return delegate?.parser }
	
	// MARK: Create preview data in background
	
	func createPreview() {
		renderer?.newRender(screenplay: delegate!.parser.forPrinting(), settings: self.settings)
	}
	
	/// Called when a render is done.
	func renderingDidFinish(pages: [BeatPageView]) {
		print("Rendering finished")
		
	}
		
	func renderOnScreen() {
		let pages = renderer!.getRenderedPages(titlePage: true)
		
		self.previewView?.clear()
		
		for page in pages {
			self.previewView?.addPage(page: page.forDisplay())
		}
	}
}

final class BeatPreviewView:NSView {
	override var isFlipped: Bool { return true }
	
	func clear() {
		for pageView in self.subviews {
			pageView.removeFromSuperview()
		}
	}
	
	func updateHeight() {
		var rect = self.frame
		let height = (self.subviews.last?.frame.height ?? 0.0) + (self.subviews.last?.frame.origin.y ?? 0.0)
		rect.size.height = height
		self.frame = rect
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, self.frame.width, self.frame.height + 10.0)
	}
	
	@objc func addPages(pages:[BeatPagePrintView]) {
		for page in pages {
			addPage(page: page)
		}
		updateHeight()
	}
	
	func addPage(page:BeatPagePrintView) {
		var y = (self.subviews.last?.frame.height ?? 0.0) + (self.subviews.last?.frame.origin.y ?? 0.0)
		y += 10
		
		let frame = NSMakeRect(0, y, page.frame.width, page.frame.height)
		page.frame = frame
		
		self.addSubview(page)
	}
	
	
}

// Stolen from Victor Gama, https://vito.io/articles/2021-12-04-centered-nsscrollview
final class CenteringClipView: NSClipView {
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

