//
//  BeatPaginationManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc protocol BeatPaginationManagerExports:JSExport {
	@objc var pages:[BeatPaginationPage] { get }
	@objc var maxPageHeight:CGFloat { get }
	@objc var lengthInEights:[Int] { get }
	@objc var numberOfPages:Int { get }
	@objc var lastPageHeight:CGFloat { get }

	@objc func heightForScene(_ scene:OutlineScene) -> CGFloat
	@objc func paginate(lines: [Line])
}

@objc protocol BeatPaginationManagerDelegate {
	func paginationDidFinish(pages: [BeatPaginationPage])
	var parser:ContinuousFountainParser? { get }
	var exportSettings:BeatExportSettings? { get }
}

class BeatPaginationManager:NSObject, BeatPaginationDelegate, BeatPaginationManagerExports {
	/// Delegate which is informed when pagination is finished. Useful when using background pagination.
	weak var delegate:BeatPaginationManagerDelegate?
	weak var editorDelegate:BeatEditorDelegate?
	/// Optional renderer delegate to be used for rendering `BeatPaginationBlock` objects on screen/print/whatever.
	var renderer: BeatRendererDelegate?
	
	@objc var settings:BeatExportSettings
	var livePagination = false
	
	var operationQueue:[BeatPagination] = [];
	var pageCache:NSMutableArray?
	var pages:[BeatPaginationPage] {
		return (finishedPagination?.pages ?? []) as! [BeatPaginationPage]
	}
		
	var finishedPagination:BeatPagination?
	
	@objc convenience init(delegate:BeatPaginationManagerDelegate, renderer:BeatRendererDelegate?, livePagination:Bool) {
		self.init(settings: delegate.exportSettings!, delegate: delegate, renderer:renderer, livePagination: livePagination)
	}
	@objc init(settings:BeatExportSettings, delegate:BeatPaginationManagerDelegate?, renderer:BeatRendererDelegate?, livePagination:Bool) {
		self.settings = settings
		self.delegate = delegate
		self.renderer = renderer
		self.livePagination = livePagination
		
		super.init()
	}
@objc init(editorDelegate:BeatEditorDelegate) {
		self.settings = editorDelegate.exportSettings
		super.init()
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
	 let pagination = BeatPaginationManager(...)
	 pagination.newPagination(...)
	 let pages = pagination.pages
	 let titlePage = pagination.titlePage
	 */
	@objc func newPagination(screenplay:BeatScreenplay, settings:BeatExportSettings, forEditor:Bool, changeAt:Int) {
		self.pageCache = self.finishedPagination?.pages
		self.settings = settings
		
		let operation = BeatPagination.newPagination(with: screenplay, delegate: self, cachedPages: self.pages, livePagination: self.livePagination, changeAt: changeAt)
		runPagination(pagination: operation)
	}
	
	/// Paginates only the given lines
	func paginate(lines:[Line]) {
		let screenplay = BeatScreenplay()
		screenplay.lines = lines
		
		let operation = BeatPagination.newPagination(with: lines, delegate: self)
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
	
	@objc var titlePage:[[String: [Line]]] {
		return self.finishedPagination?.titlePageContent ?? []
	}
	
	/// Legacy plugin compatibility
	@objc var numberOfPages:Int {
		return self.finishedPagination?.pages.count ?? 0
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
	
	var lastPageHeight:CGFloat {
		guard let lastPage = self.finishedPagination?.pages.lastObject as? BeatPaginationPage
		else { return 0.0 }
		
		return lastPage.maxHeight - lastPage.remainingSpace
	}
	
	// MARK: - Forwarded delegate properties
	
	var parser:ContinuousFountainParser? {
		return self.delegate?.parser
	}
	
	
	// MARK: - Convenience methods
	
	func page(forScene scene:OutlineScene) -> Int {
		return self.finishedPagination?.findPageIndex(for: scene.line) ?? -1
	}
	
	var maxPageHeight:CGFloat {
		return self.finishedPagination?.maxPageHeight ?? BeatPaperSizing.size(for: settings.paperSize).height
	}
	
	func heightForScene(_ scene:OutlineScene) -> CGFloat {
		return self.finishedPagination?.height(for: scene) ?? 0.0
	}
}
