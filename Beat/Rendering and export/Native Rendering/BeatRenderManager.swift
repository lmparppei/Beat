//
//  BeatRenderManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc protocol BeatRenderDelegate {
	func renderingDidFinish(pages:[BeatPageView], pageBreaks:[BeatPageBreak])
	func lines() -> [Line]
	func text() -> String
	var parser:ContinuousFountainParser? { get }
}

class BeatRenderManager:NSObject, BeatRenderOperationDelegate {
	weak var delegate:BeatRenderDelegate?
	
	var queue:[BeatRenderer] = []
	var settings:BeatExportSettings
	
	var textCache = ""
	var pageCache:[BeatPageView] = []
	var pages:[BeatPageView] = []
	
	var livePagination = false
	
	var document:Document?
	
	var finishedOperation:BeatRenderer?
	
	@objc init(settings:BeatExportSettings, delegate:BeatRenderDelegate) {
		self.settings = settings
		self.delegate = delegate
	}
	
	/**
	 Adds a new render to queue. Once rendering is complete, render manager will call `renderingDidFinish()` on its delegate.
	 - note: If you are queuing only a single render, the results can be fetched in sync:
	 ```
	 let renderer = BeatRenderManager(...)
	 renderer.newRender(...)
	 let pages = renderer.pages
	 let titlePage = renderer.titlePage
	 */
	@objc func newRender(screenplay:BeatScreenplay, settings:BeatExportSettings, titlePage:Bool) {
		newRender(screenplay: screenplay, settings: settings, titlePage: titlePage, forEditor: false, changeAt: 0)
	}
	@objc func newRender(screenplay:BeatScreenplay, settings:BeatExportSettings, titlePage:Bool, forEditor:Bool, changeAt:Int) {
		self.pageCache = self.finishedOperation?.pages ?? []
		
		let operation = BeatRenderer(delegate:self, screenplay: screenplay, settings: settings, livePagination: forEditor, changeAt:changeAt, cachedPages: self.pageCache)
		runOperation(renderer: operation)
	}
	
	/// Returns both screenplay pages and the title page
	var allRenderedPages:[BeatPageView] {
		return self.finishedOperation?.getPages(titlePage: true) ?? []
	}
	var titlePage:BeatPageView? {
		return self.finishedOperation?.titlePage() ?? nil
	}
	
	/// Returns page views and
	func getRenderedPages(titlePage:Bool) -> [BeatPageView] {
		return self.finishedOperation?.getPages(titlePage: titlePage) ?? []
	}
	
	/// Legacy plugin compatibility
	var numberOfPages:Int {
		return self.pages.count
	}
	
	/// Returns `[numberOfFullPages, eightsOfLastpage]`, ie. `[5, 2]` for 5 2/8
	var lengthInEights:[Int] {
		if self.pages.count == 0 { return [0,0] }
		
		var pageCount = self.pages.count - 1
		var eights = Int(round((self.pages.last!.maxHeight - self.pages.last!.remainingSpace / self.pages.last!.maxHeight) / (1.0/8.0)))
		
		if eights == 8 {
			pageCount += 1
			eights = 0
		}
		
		return [pageCount, eights]
	}
	
	/// Pagination or render was finished
	func renderDidFinish(renderer: BeatRenderer) {
		//print("# Render did finish")
		let i = self.queue.firstIndex(of: renderer) ?? NSNotFound
		if i != NSNotFound {
			self.queue.remove(at: i)
		}
		
		// Only accept newest results
		// NSTimeInterval timeDiff = [operation.startTime timeIntervalSinceDate:_finishedOperation.startTime];
		// if (operation.success && (timeDiff > 0 || self.finishedOperation == nil)) {
		
		self.finishedOperation = renderer
		self.pages = renderer.pages
		
		self.delegate?.renderingDidFinish(pages: self.pages, pageBreaks: [])
		
		// Once finished, run the next operation, if it exists
		let lastOperation = queue.last
		if (lastOperation != nil) {
			runOperation(renderer: lastOperation!)
		}
	}
	
	/// Run a render operation
	func runOperation(renderer: BeatRenderer) {
		// Cancel any running operations
		cancelAllOperations()
		
		queue.append(renderer)
		
		// If the queue is empty, run it right away. Otherwise the operation will be run once other renderers have finished.
		if queue.count == 1 {
			if renderer.livePagination { renderer.paginateForEditor() }
			else { renderer.paginate() }
		}
	}
	
	/// Cancels all background operations
	func cancelAllOperations() {
		for operation in queue {
			operation.canceled = true
		}
	}
	
	
	// MARK: - Delegation methods
	
	var lines: [Line] {
		return self.delegate?.lines() ?? []
	}
	
	var text: String {
		return self.delegate?.text() ?? ""
	}
	
	var parser:ContinuousFountainParser? {
		return self.delegate?.parser
	}
}
