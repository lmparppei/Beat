//
//  BeatPreviewManager.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 15.12.2023.
//
/**
 
 This protocol defines a compatibility layer between macOS and iOS preview management.
 
 */

import Foundation
import BeatCore

@objc public protocol BeatPreviewManagerDelegate:BeatEditorDelegate {
    @objc func paginationFinished(_ operation:BeatPagination, indices:NSIndexSet, pageBreaks:[NSValue : [NSNumber]])
    @objc func previewVisible() -> Bool
}

/*
@objc public protocol BeatPreviewManager {
    weak var delegate:BeatPreviewManagerDelegate? { get set }
    weak var pagination:BeatPaginationManager? { get }

    var paginationUpdated:Bool { get }
    var lastChangeAt:NSRange { get }
    var changedIndices:NSMutableIndexSet { get }
    
    /// Returns export settings from the editor
    var settings:BeatExportSettings { get }
    var exportSettings:BeatExportSettings { get }
    
    /// Returns the parser from current docuent
    var parser:ContinuousFountainParser? { get }
    
    /// Called when a pagination operation was finished.
    func paginationDidFinish(_ operation:BeatPagination)
    
    /// Creates a preview with a change in given range. When `sync` is true, the preview is created immediately in main thread.
    func createPreview(changedRange range:NSRange, sync:Bool)
    /// Invalidates the preview from given range.
    func invalidatePreview(at range:NSRange)
    /// Invalidates the preview completely
    func resetPreview()
    /// Renders the current preview on screen
    func renderOnScreen()
    
    /// The timer associated with firing up the preview creation
    var timer:Timer? { get set }
}
 */

@objc open class BeatPreviewManager:NSObject, BeatPreviewControllerInstance, BeatPaginationManagerDelegate  {
    
    @IBOutlet public weak var delegate:BeatPreviewManagerDelegate?
    
    @objc public var pagination:BeatPaginationManager?

    @objc public var timer:Timer?
    public var paginationUpdated = false
    public var lastChangeAt = NSMakeRange(0, 0)
            
    /// Returns export settings from editor
    public var settings:BeatExportSettings {
        guard let settings = self.delegate?.exportSettings else {
            // This shouldn't ever happen, but if the delegate fails to return settings, we'll just create our own.
            return BeatExportSettings.operation(.ForPrint, document: nil, header: "", printSceneNumbers: true)
        }

        return settings
    }
    
    public var exportSettings:BeatExportSettings {
        return self.delegate?.exportSettings ?? BeatExportSettings()
    }
    
    /// This is a duct-tape fix for weird scoping issue in @objc protocols
    public func getPagination() -> Any? {
        return self.pagination
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
            if self?.delegate?.previewVisible() ?? false {
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
        // Add index to changed indices
        let changedRange = (range.length > 0) ? range : NSMakeRange(range.location, 1);
        changedIndices.add(in: changedRange)
        
        // Let's invalidate the timer (if it exists)
        self.timer?.invalidate()
        self.paginationUpdated = false
        self.lastChangeAt = changedRange
        
        guard let parser = delegate?.parser else { return }
        
        if (sync) {
            // Store revisions into lines
            self.delegate?.bakeRevisions()
            
            // Create pagination
            if let screenplay = BeatScreenplay.from(parser, settings: self.settings) {
                pagination?.newPagination(screenplay: screenplay, settings: self.settings, forEditor: true, changeAt: changedIndices.firstIndex)
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
                                                        changeAt: self?.changedIndices.firstIndex ?? 0)
                    }
                }
            })
        }
    }
    
    /// Creates a new preview based on change in given range
    @objc open func invalidatePreview(at range:NSRange) {
        self.createPreview(withChangedRange: range, sync: false)
    }
    
    /// Rebuilds the whole preview.
    @objc open func resetPreview() {
        if !Thread.isMainThread {
            print("WARNING: resetPreview() should only be called from main thread.")
        }
        
        self.pagination?.finishedPagination = nil
        self.paginationUpdated = false
        self.changedIndices = NSMutableIndexSet(indexesIn: NSMakeRange(0, self.delegate?.parser.lines.count ?? 0))
        
    }
    
    @objc open func renderOnScreen() {
        print("Preview manager: Override renderOnScreen() in OS-specific implementation.")
    }

    /// Closes preview and selects the given range
    func closeAndJumpToRange(_ range:NSRange) {
        delegate?.returnToEditor?()
        self.delegate?.selectedRange = range
        self.delegate?.scroll(to: range, callback: {})
    }
}
