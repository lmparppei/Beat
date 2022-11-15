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
}

/*
 @property (weak) id<BeatPaginatorDelegate> delegate;
 @property (nonatomic, readonly) NSUInteger numberOfPages;
 @property (nonatomic, readonly) NSArray* lengthInEights;
 @property (nonatomic) CGSize paperSize;
 @property (nonatomic) CGFloat lastPageHeight;
 @property (strong, atomic) NSMutableArray<NSMutableArray<Line*>*> *pages;
 @property (nonatomic) NSMutableIndexSet *updatedPages;

 @property (atomic) BeatExportSettings *settings;

 @property (nonatomic) BeatFont *font;

 @property (weak, nonatomic) BeatDocument *document;
 @property (atomic) BeatPrintInfo *printInfo;
 @property (atomic) bool printNotes;

 // For live pagination
 @property (atomic) bool livePagination;
 @property (strong, nonatomic) NSMutableArray *pageBreaks;
 @property (strong, nonatomic) NSMutableArray *pageInfo;
 */

class BeatRenderManager:NSObject, BeatRenderOperationDelegate {
	weak var delegate:BeatRenderDelegate?
	
	var queue:[BeatRenderer] = []
	var settings:BeatExportSettings
	
	var textCache = ""
	var pageCache:[BeatPageView] = []
	var pageBreakCache:[BeatPageBreak] = []
	
	var pages:[BeatPageView] = []
	var titlePage:BeatPageView?
	var pageBreaks:[BeatPageBreak] = []
	
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
	@objc func newRender(screenplay:BeatScreenplay, settings:BeatExportSettings, forEditor:Bool, titlePage:Bool) {
		self.pageCache = self.finishedOperation?.pages ?? []
		self.pageBreakCache = self.finishedOperation?.pageBreaks ?? []
		
		let operation = BeatRenderer(delegate:self, screenplay: screenplay, settings: settings, livePagination: forEditor, cachedPages: self.pageCache, cachedPageBreaks: self.pageBreakCache)
		runOperation(renderer: operation)
	}
	
	/// Returns both screenplay pages and the title page
	var allPages:[BeatPageView] { get {
		var pages = Array(self.pages)
		
		if self.titlePage != nil {
			pages.append(self.titlePage!)
		}
		
		return pages
	} }
	
	/// Legacy plugin compatibility
	var numberOfPages:Int { get {
		return self.pages.count
	} }
	
	/// Returns `[numberOfFullPages, eightsOfLastpage]`, ie. `[5, 2]` for 5 2/8
	var lengthInEights:[Int] { get {
		if self.pages.count == 0 { return [0,0] }
		
		var pageCount = self.pages.count - 1
		var eights = Int(round((self.pages.last!.height / self.pages.last!.maxHeight) / (1.0/8.0)))
		
		if eights == 8 {
			pageCount += 1
			eights = 0
		}
		
		return [pageCount, eights]
	} }
	
	
	func renderDidFinish(renderer: BeatRenderer) {
		print("# Render did finish")
		let i = self.queue.firstIndex(of: renderer) ?? NSNotFound
		if i != NSNotFound {
			self.queue.remove(at: i)
		}
		
		// Only accept newest results
		// NSTimeInterval timeDiff = [operation.startTime timeIntervalSinceDate:_finishedOperation.startTime];
		// if (operation.success && (timeDiff > 0 || self.finishedOperation == nil)) {
		
		self.finishedOperation = renderer
		self.pageBreaks = renderer.pageBreaks
		self.pages = renderer.pages
		
		// Once finished, run the next operation, if it exists
		let lastOperation = queue.last
		if (lastOperation != nil) {
			runOperation(renderer: lastOperation!)
		}
	}
	
	func runOperation(renderer: BeatRenderer) {
		// Cancel any running operations
		cancelAllOperations()
		
		queue.append(renderer)
		
		// If the queue is empty, run it right away. Otherwise the operation will be run once other renderers have finished.
		if queue.count == 1 {
			if renderer.livePagination { renderer.liveRender() }
			else { renderer.paginate() }
		}
	}
	
	func cancelAllOperations() {
		for operation in queue {
			operation.canceled = true
		}
	}
		
	var lines: [Line] { get {
		return self.delegate?.lines() ?? []
	} }
	
	var text: String { get {
		return self.delegate?.text() ?? ""
	} }
	
	
}
