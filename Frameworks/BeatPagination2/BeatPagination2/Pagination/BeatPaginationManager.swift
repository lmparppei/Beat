//
//  BeatPaginationManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore

@objc protocol BeatPaginationManagerExports:JSExport {
	@objc var pages:[BeatPaginationPage] { get }
	@objc var maxPageHeight:CGFloat { get }
	@objc var lengthInEights:[Int] { get }
	@objc var numberOfPages:Int { get }
	@objc var lastPageHeight:CGFloat { get }

	@objc func heightForScene(_ scene:OutlineScene) -> CGFloat
    @objc func heightForRange(_ location:Int, _ length:Int) -> CGFloat
    
	@objc func sceneLengthInEights(_ scene:OutlineScene) -> [Int]
	@objc func paginate(lines: [Line])
	@objc func paginateLines(_ lines:[Line])
    
    @objc func pageNumberAt(_ location:Int) -> Int
    @objc func pageNumberForScene(_ scene:OutlineScene) -> Int
}

@objc public protocol BeatPaginationManagerDelegate {
	func paginationDidFinish(pages: [BeatPaginationPage])
	var parser:ContinuousFountainParser? { get }
	var exportSettings:BeatExportSettings? { get }
}

public class BeatPaginationManager:NSObject, BeatPaginationDelegate, BeatPaginationManagerExports {
	/// Delegate which is informed when pagination is finished. Useful when using background pagination.
	weak var delegate:BeatPaginationManagerDelegate?
	weak var editorDelegate:BeatEditorDelegate?
	/// Optional renderer delegate to be used for rendering `BeatPaginationBlock` objects on screen/print/whatever.
	public var renderer: BeatRendererDelegate?
	
	@objc public var settings:BeatExportSettings
    public var livePagination = false
	
	var operationQueue:[BeatPagination] = [];
	var pageCache:NSMutableArray?
    public var pages:[BeatPaginationPage] {
		return (finishedPagination?.pages ?? []) as! [BeatPaginationPage]
	}
		
    @objc public var finishedPagination:BeatPagination?
	
	@objc convenience init(delegate:BeatPaginationManagerDelegate, renderer:BeatRendererDelegate?, livePagination:Bool) {
		self.init(settings: delegate.exportSettings!, delegate: delegate, renderer:renderer, livePagination: livePagination)
	}
	
	@objc public init(settings:BeatExportSettings, delegate:BeatPaginationManagerDelegate?, renderer:BeatRendererDelegate?, livePagination:Bool) {
		// Load default styles if none were explicitly delivered through export settings
		if (settings.styles == nil) {
			settings.styles = BeatRenderStyles.shared
		}
        
		self.settings = settings
		self.delegate = delegate
		self.livePagination = livePagination
				
		super.init()
		
		if (renderer != nil) {
			self.renderer = renderer
			self.renderer?.pagination = self
		}
	}
	
    /// What is this?
	@objc public init(editorDelegate:BeatEditorDelegate) {
		self.settings = editorDelegate.exportSettings
		self.editorDelegate = editorDelegate
		
		if (settings.styles == nil) {
			settings.styles = BeatRenderStyles.shared
		}
		
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
	@objc public func newPagination(screenplay:BeatScreenplay, settings:BeatExportSettings, forEditor:Bool, changeAt:Int) {
		self.pageCache = self.finishedPagination?.pages
		self.settings = settings
		
		let operation = BeatPagination.newPagination(with: screenplay, delegate: self, cachedPages: self.pages, livePagination: self.livePagination, changeAt: changeAt)
		runPagination(pagination: operation)
	}
    
    @objc public func newPagination() {
        self.pageCache = self.finishedPagination?.pages
        self.settings = self.delegate!.exportSettings!
        
        let operation = BeatPagination.newPagination(with: self.delegate!.parser!.forPrinting()!, delegate: self, cachedPages: self.pages, livePagination: false, changeAt: 0)
        runPagination(pagination: operation)
    }
	
	/// Paginates only the given lines
    public func paginate(lines:[Line]) {
		let screenplay = BeatScreenplay()
		screenplay.lines = lines
		
		let operation = BeatPagination.newPagination(with: lines, delegate: self)
		runPagination(pagination: operation)
	}
    public func paginateLines(_ lines:[Line]) {
		//self.finishedPagination = nil
		self.paginate(lines: lines)
	}
	
	// MARK: - Finished operations
	
	public func paginationFinished(_ pagination: BeatPagination) {
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
			self.finishedPagination = nil
			self.finishedPagination = pagination

			self.delegate?.paginationDidFinish(pages: self.pages)
		}
		
		let lastOperation = operationQueue.last
		if (lastOperation != nil) {
			runPagination(pagination: lastOperation!)
		}
	}
	
	
	// MARK: - Delegate methods
	
	
	
	
	// MARK: - Getting paginated content properites
	
	/// Returns the *actual* page size for either the latest operation or from current settings
	@objc public var pageSize:CGSize {
		if (self.finishedPagination != nil) {
			return BeatPaperSizing.size(for: self.finishedPagination!.settings.paperSize)
		} else {
			return BeatPaperSizing.size(for: self.settings.paperSize)
		}
	}
	
	@objc public var titlePage:[[String: [Line]]] {
		return self.finishedPagination?.titlePageContent ?? []
	}
	@objc public var hasTitlePage:Bool {
		return (self.titlePage.count > 0)
	}
	
	/// Legacy plugin compatibility
	@objc public var numberOfPages:Int {
		return self.finishedPagination?.pages.count ?? 0
	}
	
	/// Returns `[numberOfFullPages, eightsOfLastpage]`, ie. `[5, 2]` for 5 2/8
    @objc public var lengthInEights:[Int] {
		if self.pages.count == 0 { return [0,0] }
		
		var pageCount = self.pages.count - 1
		var eights = Int(round((self.pages.last!.maxHeight - self.pages.last!.remainingSpace / self.pages.last!.maxHeight) / (1.0/8.0)))
		
		if eights == 8 {
			pageCount += 1
			eights = 0
		}
		
		return [pageCount, eights]
	}
	
	@objc public func sceneLengthInEights(_ scene:OutlineScene) -> [Int] {
		let height = self.heightForScene(scene)
		return heightToEights(height)
	}
	
	@objc public func heightToEights(_ height:CGFloat) -> [Int] {
		if height == 0 { return [0,0] }
		
		var pageCount = Int(floor(height / self.maxPageHeight))
		let remainder = height - (CGFloat(pageCount) * self.maxPageHeight)
		var eights = Int(round((remainder / self.maxPageHeight) / (1.0/8.0)))
		
		// It's almost a full page, so let's report it so
		if eights == 8 {
			pageCount += 1
			eights = 0
		}
		
		// The shortest scene ever will still be 1/8 pages
		if pageCount == 0 && eights == 0 {
			eights = 1
		}
		
		return [pageCount, eights]
	}
	
    public var actualLastPageHeight:CGFloat {
		guard let lastPage = self.finishedPagination?.pages.lastObject as? BeatPaginationPage
		else { return 0.0 }
		
		return lastPage.maxHeight - lastPage.remainingSpace
	}
	
    public var lastPageHeight:CGFloat {
		guard let lastPage = self.finishedPagination?.pages.lastObject as? BeatPaginationPage
		else { return 0.0 }
		return (lastPage.maxHeight - lastPage.remainingSpace) / lastPage.maxHeight
	}
	
	// MARK: - Forwarded delegate properties
	
    public var parser:ContinuousFountainParser? {
		return self.delegate?.parser
	}
	
	// MARK: - Convenience methods
	
    @objc public func page(forScene scene:OutlineScene) -> Int {
		return self.finishedPagination?.findPageIndex(for: scene.line) ?? -1
	}

    @objc public func pageNumberForScene(_ scene:OutlineScene) -> Int {
        return pageNumberAt(Int(scene.position))
    }
    
    @objc public func pageNumberAt(_ location:Int) -> Int {
        var pageNumber = self.finishedPagination?.findPageIndex(at: location) ?? 0
        
        // 0 will indicate that we didn't find anything
        if pageNumber == NSNotFound || pageNumber == 0 { pageNumber = 0 }
        else {
            // We'll use human-readable page numbers here
            pageNumber += 1
        }
        
        return pageNumber
    }
    
    @objc public var maxPageHeight:CGFloat {
        return self.finishedPagination?.maxPageHeight ?? self.defaultMaxHeight
	}
    
    var defaultMaxHeight:CGFloat {
        let size = BeatPaperSizing.size(for: settings.paperSize)
        let style = BeatRenderStyles.shared.page()
        
        return size.height - style.marginTop - style.marginBottom - BeatPagination.lineHeight() * 3
    }
	
    @objc public func heightFor(_ range:NSRange) -> CGFloat {
        guard let height = self.finishedPagination?.height(for: range) else {
            print("No height available for range:", range)
            return 0.0
        }
        
        return height / self.maxPageHeight
    }
    
    /// JS convenience method
    func heightForRange(_ location: Int, _ length: Int) -> CGFloat {
        return heightFor(NSMakeRange(location, length))
    }
    
    @objc public func heightForScene(_ scene:OutlineScene) -> CGFloat {
		guard let height = self.finishedPagination?.height(for: scene)
		else {
			print("No height available for scene:", scene)
			return 0.0
		}
		
        return height / self.maxPageHeight
	}
    
    @objc public func actualHeightForScene(_ scene:OutlineScene) -> CGFloat {
        guard let height = self.finishedPagination?.height(for: scene)
        else {
            print("No height available for scene:", scene)
            return 0.0
        }
        
        return height
    }
}
