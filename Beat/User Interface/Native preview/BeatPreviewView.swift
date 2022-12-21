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

final class BeatPreviewController:NSObject, BeatRenderManagerDelegate {
	@IBOutlet weak var previewView:BeatPreviewView?
	@IBOutlet weak var delegate:BeatEditorDelegate?
	
	
	var pagination:BeatPaginationManager?
	var renderer:BeatRendering?
	
	override init() {
		super.init()
	
		let settings = BeatExportSettings()
		settings.paperSize = delegate?.pageSize ?? .A4
		settings.revisions = BeatRevisions.revisionColors()

		// Create render manager
		self.renderer = BeatRendering(settings: settings)
		self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer)
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
	@objc func createPreview(changeAt index:Int) {
		guard let parser = delegate?.parser else { return }
		//pagination?.newRender(screenplay: parser.forPrinting(), settings: self.settings, forEditor: true, changeAt: index)
		pagination?.newPagination(screenplay: parser.forPrinting(), settings: settings, forEditor: true, changeAt: index)
	}
		
	func paginationDidFinish(pages: [BeatPaginationPage]) {
		print("Preview View: Pagination finished")
	}
		
	@objc func renderOnScreen() {
		self.previewView?.clear()
				
		guard let pages = pagination?.pages else { return }
		let size = BeatPaperSizing.size(for: settings.paperSize)
		let pageStyle = RenderStyles.shared.page()
		
		for i in 0..<pages.count {
			let page = pages[i]
			let string = page.attributedString()
			
			let pageView = BeatPaginationPageView(size: size, content: string, pageStyle: pageStyle)
			self.previewView?.addPage(page: pageView)
		}
	}
	
	func closeAndJumpToRange(_ range:NSRange) {
		delegate?.returnToEditor()
		self.delegate?.scroll(to: range, callback: {})
	}
}

final class FlippedView:NSView {
	override var isFlipped: Bool { return true }
}

final class BeatPreviewView:NSView {
	override var isFlipped: Bool { return true }
	@IBOutlet weak var previewController:BeatPreviewController?
	
	func clear() {
		for pageView in self.subviews {
			pageView.removeFromSuperview()
		}
	}
	
	func updateSize() {
		let pageSize = self.subviews.first?.frame.size ?? NSSize(width: 0, height: 0)
		let height = (self.subviews.last?.frame.height ?? 0.0) + (self.subviews.last?.frame.origin.y ?? 0.0)
		
		self.enclosingScrollView?.documentView?.frame = NSMakeRect(0, 0, pageSize.width, height)
		self.frame = NSMakeRect(0, 0, pageSize.width, height)
	}
		
	func addPage(page:BeatPaginationPageView) {
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
	
	override func scrollWheel(with event: NSEvent) {
		/*
		let newEvent = event.cgEvent!.copy()!
		newEvent.setIntegerValueField(CGEventField.scrollWheelEventDeltaAxis1, value: 0)
		
		guard let customEvent = NSEvent(cgEvent: newEvent) else { return }
		super.scrollWheel(with: customEvent)
		 */
		
		//if event.deltaX != 0 {
			super.scrollWheel(with: event)
		//}
	}
	override func touchesBegan(with event: NSEvent) {
		if event.deltaX != 0 {
			super.touchesBegan(with: event)
		}
	}
	
}

