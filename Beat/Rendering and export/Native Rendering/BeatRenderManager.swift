//
//  BeatRenderManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc protocol BeatRenderDelegate {
	func renderingDidFinish(pages:[BeatPageView])
	func paginationDidFinish(pages: [BeatPaginationPage])
	var parser:ContinuousFountainParser? { get }
}

class BeatRenderManager:NSObject, BeatPaginationDelegate {
	weak var delegate:BeatRenderDelegate?
	var document:Document?
	
	@objc var settings:BeatExportSettings
	var livePagination = false
	
	var operationQueue:[BeatPagination] = [];
	var pageCache:[BeatPaginationPage] = []
	var pages:[BeatPaginationPage] {
		return (finishedPagination?.pages ?? []) as! [BeatPaginationPage]
	}
		
	var finishedPagination:BeatPagination?
	
	@objc init(settings:BeatExportSettings, delegate:BeatRenderDelegate) {
		self.settings = settings
		self.delegate = delegate
	}
	
	//MARK: - Run operations
		
	/// Run an Objc pagination operation
	func runPagination(pagination: BeatPagination) {
		// Cancel any running operations
		cancelAllObjcOperations()
		
		operationQueue.append(pagination)
		
		// If the queue is empty, run it right away. Otherwise the operation will be run once other renderers have finished.
		if operationQueue.last != nil {
			//if pagination.livePagination { renderer.paginateForEditor() }
			//else { renderer.paginate() }
			operationQueue.last!.paginate()
		}
	}
	
	//MARK: - Cancel operations
	
	/// Cancels all background operations
	func cancelAllObjcOperations() {
		for operation in operationQueue {
			operation.canceled = true
		}
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
	@objc func newPagination(screenplay:BeatScreenplay, settings:BeatExportSettings, forEditor:Bool, changeAt:Int) {
		self.pageCache = []
		
		let operation = BeatPagination.newPagination(with: screenplay, delegate: self)
		runPagination(pagination: operation)
	}
	
	// MARK: - Finished operations
	
	func paginationFinished(_ pagination: BeatPagination) {
		if (self.finishedPagination != nil) {
			if (pagination.startTime < self.finishedPagination!.startTime) { return }
		}
		
		let i = self.operationQueue.firstIndex(of: pagination) ?? NSNotFound
		if i != NSNotFound {
			var n = 0
			while (n < i+1) {
				operationQueue.remove(at: 0)
				n += 1
			}
		}
		
		if pagination.success {
			self.finishedPagination = pagination
			self.delegate?.paginationDidFinish(pages: self.pages)
		}
		
		let lastOperation = operationQueue.last
		if (lastOperation != nil) {
			runPagination(pagination: lastOperation!)
		}
	}
	
	// MARK: - Convenience
	
	/// Returns the *actual* page size for either the latest operation or from current settings
	@objc var pageSize:NSSize {
		if (self.finishedPagination != nil) {
			return BeatPaperSizing.size(for: self.finishedPagination!.settings.paperSize)
		} else {
			return BeatPaperSizing.size(for: self.settings.paperSize)
		}
	}
	
	/*
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
	*/
	
	// MARK: - Forwarded delegate properties
	
	var parser:ContinuousFountainParser? {
		return self.delegate?.parser
	}
}
