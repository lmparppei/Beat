//
//  BeatPaginationManager.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class handles pagination operations. You can instantiate a `BeatPagination` operation without the manager, but for most use cases, the manager is preferred.
 If you provide an editor delegate, settings and screenplay content will be automatically delivered to the manager.
 
 */

import Foundation
import BeatCore

@objc protocol BeatPaginationManagerExports:JSExport {
    /// The pages (`BeatPaginationPage`) in current finished pagination
    @objc var pages:[BeatPaginationPage] { get }
    /// The maximum height of a single page in the current pagination.
    @objc var maxPageHeight:CGFloat { get }
    /// The length of each page in the current pagination, measured in eights
    @objc var lengthInEights:[Int] { get }
    /// The number of pages in the current pagination.
    @objc var numberOfPages:Int { get }
    /// The height of the last page in the current pagination.
    @objc var lastPageHeight:CGFloat { get }
    /// The finished pagination of the Beat document, if one has been generated.
    @objc var finishedPagination:BeatPagination? { get }
    
    /// Returns the relative height (`0..1`) of a given scene in the current pagination.
    /// - parameter scene: The scene to calculate the height for.
    /// - Returns: The relative height of the scene
    @objc func heightForScene(_ scene:OutlineScene) -> CGFloat
    
    /// Returns the relative height (`0..1`) of a range of text in the current pagination.
    /// - Parameters:
    ///   - location: Starting index of the range
    ///   - length: Length of the range
    /// - Returns: The relative height of the scene
    @objc func heightForRange(_ location:Int, _ length:Int) -> CGFloat
    
    /// Returns the length of a given scene in eights (an eighth is a unit of musical time).
    /// - Parameter scene: The scene to calculate the length for.
    /// - Returns: The length of the scene in eights `[full pages, eights]`.
    @objc func sceneLengthInEights(_ scene:OutlineScene) -> [Int]
    
    /// Creates a new pagination for a given set of lines.
    /// - Parameter lines: The lines to generate the pagination for.
    /// - note: Do NOT use this with `Beat.currentPagination()`, as you might end up breaking editor page numbering
    @objc func paginate(lines: [Line])
    
    /// Generates a new pagination for a given set of lines.
    /// - Parameter lines: The lines to generate the pagination for.
    /// - note: Do NOT use this with `Beat.currentPagination()`, as you might end up breaking editor page numbering
    @objc func paginateLines(_ lines:[Line])
    
    /// Returns the human-readable page number at a given index in the current pagination.
    /// - Parameter location: The index to retrieve the page number for.
    /// - Returns: The page number at the given index.
    @objc func pageNumberAt(_ location:Int) -> Int
    
    /// Returns the page number for a given scene in the current pagination.
    /// - Parameter scene: The scene to retrieve the page number for.
    /// - Returns: The page number for the given scene.
    @objc func pageNumberForScene(_ scene:OutlineScene) -> Int
}

@objc public protocol BeatPaginationManagerDelegate {
    func paginationDidFinish(_ operation:BeatPagination)
	var parser:ContinuousFountainParser? { get }
	var exportSettings:BeatExportSettings { get }
}

@objc public class BeatPaginationManager:NSObject, BeatPaginationDelegate, BeatPaginationManagerExports {
    /// If you provide an editor delegate, pagination manager will automatically fetch screenplay and export settings from the editor.
    public weak var editorDelegate:BeatEditorDelegate?
    
    /// Delegate which is informed when pagination is finished. Useful when using background pagination.
	weak var delegate:BeatPaginationManagerDelegate?

	/// Optional renderer delegate to be used for rendering `BeatPaginationBlock` objects on screen/print/whatever.
	public var renderer: BeatRendererDelegate?
    
    /// When `livePagination` is set `true`, pagination operations will try to reuse pre-paginated content when possible.
    public var livePagination = false

    /// Export settings
    @objc public var settings:BeatExportSettings
    
    /// The latest finished pagination
    @objc public var finishedPagination:BeatPagination?

	var operationQueue:[BeatPagination] = [];
    public var pages:[BeatPaginationPage] {
		return (finishedPagination?.pages ?? []) as! [BeatPaginationPage]
	}
    
    
    // MARK: - Initialization
    
	@objc public convenience init(delegate:BeatPaginationManagerDelegate, renderer:BeatRendererDelegate?, livePagination:Bool) {
		self.init(settings: delegate.exportSettings, delegate: delegate, renderer:renderer, livePagination: livePagination)
	}
	
	@objc public init(settings:BeatExportSettings, delegate:BeatPaginationManagerDelegate?, renderer:BeatRendererDelegate?, livePagination:Bool) {
		// Load default styles if none were explicitly delivered through export settings
		if (settings.styles == nil) {
            settings.styles = BeatStyles.shared.defaultStyles
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
			settings.styles = BeatStyles.shared.defaultStyles
		}
		
		super.init()
	}
	
	
	// MARK: - Run and cancel pagination operations
		
	/// Run an Objc pagination operation
	func runPagination(pagination: BeatPagination) {
        if operationQueue.contains(pagination) {
            // Trying to run pagination which is already in queue. Ignore.
            // This *shouldn't* happen, but multithreading can be weird.
            return
        }
        
		// Cancel any running operations
		cancelAllOperations()
		
        // Add operation to queue
        operationQueue.append(pagination)
        
		// If the queue was empty, run our new pagination operation right away.
        // Otherwise it will be run once other paginations have finished.
		if operationQueue.first == pagination {
			operationQueue.first!.paginate()
		}
	}
		
	/// Cancels all background operations
	func cancelAllOperations() {
        // Because of multithreading, some operations can be left behind in queue.
        // This operation both cancels running operations AND removes dormant ones.
        var i = 0
        while i < operationQueue.count {
            let operation = operationQueue[i]
            operation.canceled = true
            
            // This is a dormant operation left behind for some reason. Remove it from queue.
            if !operation.running {
                operationQueue.remove(at: i)
            } else {
                i += 1
            }
        }
	}
	
    // MARK: - Create a new operation
    
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
		self.settings = settings
		let operation = BeatPagination.newPagination(with: screenplay, delegate: self, cachedPages: self.pages, livePagination: self.livePagination, changeAt: changeAt)
        
		runPagination(pagination: operation)
	}
    
    /// Use this when paginating with an editor delegate
    @objc public func newPagination() {
        if let settings = self.delegate?.exportSettings {
            if let screenplay = BeatScreenplay.from(self.delegate?.parser, settings: settings) {
                let operation = BeatPagination.newPagination(with: screenplay, delegate: self, cachedPages: self.pages, livePagination: self.livePagination, changeAt: 0)
                runPagination(pagination: operation)
            }
        }
    }
    
    /// Paginates given screenplay object
    @objc public func newPagination(screenplay:BeatScreenplay) {
        let operation = BeatPagination.newPagination(with: screenplay, delegate: self, cachedPages: self.pages, livePagination: false, changeAt: 0)
        runPagination(pagination: operation)
    }
	
	/// Paginates only the given lines
    public func paginate(lines:[Line]) {
		let screenplay = BeatScreenplay()
		screenplay.lines = lines
		
		let operation = BeatPagination.newPagination(with: lines, delegate: self)
		runPagination(pagination: operation)
	}
    
    /// This is here for backwards compatibility with plugin API
    public func paginateLines(_ lines:[Line]) {
		self.paginate(lines: lines)
	}
	
    
    
	// MARK: - Delegate methods
	
    /// Called when a pagination operation is finished.
	public func paginationFinished(_ pagination: BeatPagination) {
        // Remove the finished pagination operation (and any earlier ones) from queue
        while (operationQueue.count > 0) {
            operationQueue.remove(at: 0)
        }
        
        // Check if the currently finished pagination was created before the latest one. If it's older, do nothing.
        if (finishedPagination != nil && pagination.startTime < self.finishedPagination!.startTime) {
            return
        }
		
        // If the pagination was successful, let's make it the latest finished pagination
		if pagination.success {
			self.finishedPagination = nil
			self.finishedPagination = pagination

			self.delegate?.paginationDidFinish(pagination)
		}
		
        // Move on to the next pagination operation in queue
		if let lastOperation = operationQueue.last {
			runPagination(pagination: lastOperation)
		}
	}
	
	
	
	// MARK: - Getting paginated content properties
	
	/// Returns the *actual* page size for either the latest operation or from current settings
	@objc public var pageSize:CGSize {
		if (self.finishedPagination != nil) {
			return BeatPaperSizing.size(for: self.finishedPagination!.settings.paperSize)
		} else {
			return BeatPaperSizing.size(for: self.settings.paperSize)
		}
	}
	
    /// Returns the title page content in finished pagination
	@objc public var titlePage:[[String: [Line]]] {
		return self.finishedPagination?.titlePageContent ?? []
	}
    
    /// Returns `true` if the paginated document has a title page
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
	
    /**
     Returns given scene length in eights.
     - returns `[pages:Int, eights:Int]`
     */
	@objc public func sceneLengthInEights(_ scene:OutlineScene) -> [Int] {
		let height = self.heightForScene(scene)
		return heightToEights(height)
	}
	
    /// Converts given height in current pagination to eights of a page
	@objc public func heightToEights(_ height:CGFloat) -> [Int] {
		if height == 0 { return [0,0] }
		
        var pageCount = Int(floor(height / 1.0))
		let remainder = height - CGFloat(pageCount)
		var eights = Int(round(remainder / (1.0/8.0)))
		
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
	
    /// Returns the actual last page height in points
    public var actualLastPageHeight:CGFloat {
		guard let lastPage = self.finishedPagination?.pages.lastObject as? BeatPaginationPage
		else { return 0.0 }
		
		return lastPage.maxHeight - lastPage.remainingSpace
	}
	
    /// Returns relative height of the last page (`0...1`)
    public var lastPageHeight:CGFloat {
		guard let lastPage = self.finishedPagination?.pages.lastObject as? BeatPaginationPage
		else { return 0.0 }
		return (lastPage.maxHeight - lastPage.remainingSpace) / lastPage.maxHeight
	}
	
    
	// MARK: - Forwarded delegate properties
	
    /// Returns the parser in current document
    public var parser:ContinuousFountainParser? {
		return self.delegate?.parser
	}
	
    
	// MARK: - Convenience methods
	
    /// Returns the page index for given scene
    @objc public func page(forScene scene:OutlineScene) -> Int {
		return self.finishedPagination?.findPageIndex(for: scene.line) ?? -1
	}

    /// Returns page number for given scene
    @objc public func pageNumberForScene(_ scene:OutlineScene) -> Int {
        return pageNumberAt(Int(scene.position))
    }
    
    /// Returns page number at given location
    @objc public func pageNumberAt(_ location:Int) -> Int {
        var pageNumber = self.finishedPagination?.findPageIndex(at: location) ?? 0
        
        // 0 will indicate that we didn't find anything
        if pageNumber == NSNotFound {
            pageNumber = 0
        } else {
            // We'll use human-readable page numbers here
            pageNumber += 1
        }
        
        return pageNumber
    }
    
    /// Returns maximum content height on page for the  pagination
    @objc public var maxPageHeight:CGFloat {
        return self.finishedPagination?.maxPageHeight ?? self.defaultMaxHeight
	}
    
    /// Returns the default content height when no finished pagination is available
    var defaultMaxHeight:CGFloat {
        let size = BeatPaperSizing.size(for: settings.paperSize)
        let style = BeatStyles.shared.defaultStyles.page()
        
        return size.height - style.marginTop - style.marginBottom - BeatPagination.lineHeight() * 3
    }
	
    /// Returns the relative height `0...1` for given range in paginated screenplay.
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
