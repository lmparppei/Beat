//
//  BeatPreviewManager.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 15.12.2023.
//
/**
 
 This class handles most of the preview management for both macOS and iOS.
 You need to override `renderOnScreen()` (and possibly some other methods as well) in OS-specific implementations to support the actual preview drawing and rendering.
 
 */

import Foundation
import BeatCore
import UXKit

/// A protocol which defines basic preview view behaviors
@objc public protocol BeatPreviewPageView {
    func clear()
    func scrollToPage(_ pageIndex:Int)
    
    func startLoadingAnimation()
    func endLoadingAnimation()
    
    weak var dataSource:BeatPreviewPageViewDataSource? { get set }
}

@objc public protocol BeatPreviewPageViewDataSource {
    func numberOfPages() -> Int
    func pageSize() -> CGSize
    func hasTitlePage() -> Bool
    func pageView(forPage pageIndex:Int, placeholder:Bool) -> UXView
    var rendering:Bool { get }
}

@objc public protocol BeatPreviewManagerDelegate:BeatEditorDelegate {
    @objc func paginationFinished(_ operation:BeatPagination, indices:NSIndexSet, pageBreaks:[NSValue : [NSNumber]])
    @objc func previewVisible() -> Bool
}

@objc open class BeatPreviewManager:NSObject, BeatPreviewControllerInstance, BeatPaginationManagerDelegate {
    
    @IBOutlet public weak var delegate:BeatPreviewManagerDelegate?
    @IBOutlet weak open var previewView:BeatPreviewPageView?
    
    @objc public var rendering = false
    
    /// Pagination manager
    @objc public var pagination:BeatPaginationManager?
    /// Renderer
    var renderer:BeatRenderer?
    /// Timer for updating the content
    @objc public var timer:Timer?
    /// If set `true`, the preview view will be rendered right away when pagination has finished
    public var renderImmediately = false
    
    public var paginationUpdated = false
    public var lastChangeAt = NSMakeRange(0, 0)

    /// Page views for iOS page view data source
    public var pageViews:[Int:UXView] = [:]
    
    /// Returns export settings from editor
    public var settings:BeatExportSettings {
        guard let settings = self.delegate?.exportSettings else {
            // This shouldn't ever happen, but if the delegate fails to return settings, we'll just create our own.
            return BeatExportSettings.operation(.ForPrint, document: nil, header: "", printSceneNumbers: true)
        }

        return settings
    }
    
    /// Fetch export settings from delegate
    public var exportSettings:BeatExportSettings {
        return self.delegate?.exportSettings ?? BeatExportSettings()
    }
    
    /// This is a duct-tape fix for weird scoping issue in @objc protocols
    @objc open func getPagination() -> Any? {
        return self.pagination
    }
    
    
    // MARK: - Initialization and setup
    
    override init() {
        super.init()
        //customInit()
    }
    
    @objc public init(delegate:BeatPreviewManagerDelegate, previewView:BeatPreviewPageView) {
        self.delegate = delegate
        self.previewView = previewView
        super.init()
        
        setup()
    }
    
    @objc public func setup() {
        // Create renderer and pagination manager
        self.renderer = BeatRenderer(settings: settings)
        self.pagination = BeatPaginationManager(settings: settings, delegate: self, renderer: self.renderer, livePagination: true)
        self.pagination?.editorDelegate = self.delegate
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        
        self.pagination?.editorDelegate = self.delegate
        // NOTE: This does nothing on macOS
        self.previewView?.dataSource = self
    }
    
    deinit {
        self.pagination?.finishedPagination = nil
        self.pagination?.renderer = nil
        self.pagination = nil
        self.renderer = nil
    }
    
    
    // MARK: - Pagination delegation
    
    /// When pagination has finished, we'll inform the host document and mark our pagination as done
    open func paginationDidFinish(_ operation:BeatPagination) {
        self.paginationUpdated = true
        
        // Let's tell the delegate this, too
        self.delegate?.paginationFinished(operation, indices: self.changedIndices, pageBreaks: operation.editorPageBreaks())
        
        //  Clear changed indices
        self.changedIndices.removeAllIndexes()
        
        // Return to main thread and render stuff on screen if needed
        DispatchQueue.main.async { [weak self] in
            if (self?.delegate?.previewVisible() ?? false) || self?.renderImmediately ?? false {
                self?.renderOnScreen()
            }
        }
    }
    
    
    // MARK: - Delegate methods (delegated from delegate)
    @objc public var parser: ContinuousFountainParser? { return delegate?.parser }
    
    
    // MARK: - Creating  preview data
    
    var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
    
    /// Preview data can be created either in background (async) or in main thread (sync).
    /// - note: This method doesn't create the actual preview yet, just paginates it and prepares the data ready for display.
    @objc open func createPreview(withChangedRange range:NSRange, sync:Bool) {
        // Make sure we have at least one index in range
        let changedRange = (range.length > 0) ? range : NSMakeRange(range.location, 1);
        // Add index to changed indices.
        changedIndices.add(in: changedRange)
        
        var fullChangedRange = NSMakeRange(changedIndices.firstIndex, changedIndices.lastIndex - changedIndices.firstIndex)
        if fullChangedRange.length <= 0 { fullChangedRange.length = 1 }
        
        // Let's invalidate the timer (if it exists)
        self.timer?.invalidate()
        self.paginationUpdated = false
        self.lastChangeAt = changedRange
        
        // Reset page views
        self.pageViews = [:]
        
        guard let parser = delegate?.parser else { return }
        
        if (sync) {
            // Store revisions into lines
            self.delegate?.bakeRevisions()
            
            // Create pagination
            if let screenplay = BeatScreenplay.from(parser, settings: self.settings) {
                pagination?.newPagination(screenplay: screenplay, settings: self.settings, forEditor: true, changedRange: fullChangedRange)
            }
        } else {
            // Paginate and create preview with 1 second delay
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
                // Store revisions into lines in sync
                self.delegate?.bakeRevisions()
                
                // Dispatch pagination to a background thread after one second
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    if let screenplay = BeatScreenplay.from(parser, settings: self?.settings) {
                        self?.pagination?.newPagination(screenplay: screenplay,
                                                        settings: self?.settings ?? BeatExportSettings(),
                                                        forEditor: true,
                                                        changedRange: fullChangedRange)
                    }
                }
            })
        }
    }
    
    /// Creates a new preview based on change in given range
    @objc open func invalidatePreview(at range:NSRange) {
        self.pageViews = [:]
        
        self.createPreview(withChangedRange: range, sync: false)
    }
    
    /// Rebuilds the whole preview.
    @objc open func resetPreview() {
        if !Thread.isMainThread {
            print("WARNING: resetPreview() should only be called from main thread.")
        }
        
        // Nil everything and reset changes to screenplay
        self.pagination?.finishedPagination = nil
        self.paginationUpdated = false
        self.changedIndices = NSMutableIndexSet(indexesIn: NSMakeRange(0, self.delegate?.parser.lines.count ?? 0))
        
        self.pageViews = [:]
        
        // Reload styles
        self.renderer?.reloadStyles()
        self.previewView?.clear()
        
        // Create new preview
        let previewVisible = self.delegate?.previewVisible() ?? false
        self.createPreview(withChangedRange: NSMakeRange(0, self.delegate?.text().count ?? 1), sync: previewVisible)
        
        // If the preview was cleared when in preview mode, let's display it immediately
        if previewVisible {
            self.renderOnScreen()
        }
    }
    
    /// Closes preview and selects the given range
    open func closeAndJumpToRange(_ range:NSRange) {
        delegate?.returnToEditor?()
        self.delegate?.selectedRange = range
        self.delegate?.scroll(to: range, callback: {})
    }
    
    
    // MARK: - Rendering
    
    @objc open func renderOnScreen() {
        self.rendering = true
        
        guard let previewView = self.previewView,
              let pagination = self.pagination
        else { return }
        
        // This flag determines if the preview should refresh after pagination has finished. Reset it.
        renderImmediately = false
        
        // Make sure the data source is up to date
        self.previewView?.dataSource = self
        
        // Some more guard clauses
        if !paginationUpdated {
            // If pagination is not up to date, start loading animation and wait for the operation to finish.
            previewView.startLoadingAnimation()
            renderImmediately = true
            return
        } else if !pagination.hasPages {
            // Pagination has no results. Clear the view and remove animations.
            previewView.clear()
            previewView.endLoadingAnimation()
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
#if os(macOS)
            // Create page strings in background. At least some of the pages are usually cached, so this should be pretty fast.
            // This only works on macOS though, because iOS rendering requires creating some UI elements. Oh my satan.
            let pages = pagination.pages
            _ = pages.map { $0.attributedString() }
#endif
            
            DispatchQueue.main.async { [weak self] in
                if let finishedPagination = pagination.finishedPagination {
                    // Reload all pages
                    self?.reload(with: finishedPagination)
                    
                    // Scroll view to the last edited position
                    self?.scrollToRange(self?.delegate?.selectedRange ?? NSMakeRange(0, 0))
                }
                
                // Hide animation
                previewView.endLoadingAnimation()
                self?.rendering = false
                self?.didEndRendering()
            }
        }
    }
    
    @objc open func reload(with pagination:BeatPagination) {
        print("Preview manager: Override reload() in OS-specific implementation")
    }
    
    @objc open func scrollToRange(_ range:NSRange) {
        print("Preview manager: Override scrollToRange() in OS-specific implementation")
    }
    
    @objc open func didEndRendering() {
        //
    }
}

// MARK: - Preview view data source (iOS only for now)

extension BeatPreviewManager:BeatPreviewPageViewDataSource {
        
    public func pageSize() -> CGSize {
        return BeatPaperSizing.size(for: self.settings.paperSize)
    }
    
    public func numberOfPages() -> Int {
        var pages = self.pagination?.finishedPagination?.pages.count ?? 0
        // If there's a title page, add one to full number
        if self.pagination?.hasTitlePage ?? false { pages += 1 }
        
        return pages
    }
    
    public func pageView(forPage pageIndex: Int, placeholder:Bool = false) -> UXView {
        guard let pagination = self.pagination?.finishedPagination
        else {
            return UXView()
        }
        
        // Let's first check our cached page views
        if (pageViews[pageIndex] != nil) {
            return pageViews[pageIndex]!
        }

        let hasTitlePage = (pagination.titlePageContent?.count ?? 0) > 0
        
        // The *actual* index of page in our pagination. If there's a title page present, pagination index is -1
        let actualIndex = (hasTitlePage) ? pageIndex - 1 : pageIndex

        var pageView:UXView?
                        
        if pageIndex == 0 && hasTitlePage {
            // If we have a title page and page index is 0, we'll return a title page view.
            // Something causes a race condition with title page lines (or something) when requesting a title page from thumbnail view, so... yeah. Let's avoid that by checking the placeholder flag.
            if !placeholder {
                pageView = BeatTitlePageView(titlePage: pagination.titlePage(), settings: settings)
            } else {
                pageView = BeatTitlePageView(titlePage: [], settings: settings)
            }
        } else if let pages = self.pagination?.pages, actualIndex != NSNotFound, actualIndex < pages.count {
            // Otherwise we'll just return the actual page
            let page = pages[actualIndex]
            pageView = BeatPaginationPageView(page: page, content: nil, settings: self.settings, previewController: self, textViewDelegate: self)
        }
        
        if (pageView != nil && !placeholder) {
            pageViews[pageIndex] = pageView
            return pageView!
        } else {
            print("Failed to create")
            return UXView()
        }
    }
    
    public func hasTitlePage() -> Bool {
        return pagination?.hasTitlePage ?? false
    }
}

extension BeatPreviewManager:UXTextViewDelegate {
    #if os(iOS)
    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return false
    }
    #endif
}
