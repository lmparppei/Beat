//
//  BeatPageViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.1.2024.
//

import UIKit
import BeatPagination2
import BeatCore

/**
 
 This class provides a dynamically created and scrollable page view. It loads views only for pages inside viewport bounds.
 - note: Data source protocol is defined in preview manager class, because the idea is to use the same protocol for both macOS and iOS in the future.
 
 */
@objc public class BeatPageViewController:UIViewController, BeatPreviewPageView {
	@IBOutlet weak var pageView:BeatPageScrollView?
	@IBOutlet weak var pageSettingsButton:UIBarButtonItem?
	@objc public weak var delegate:BeatEditorDelegate?
	
	public var dataSource: BeatPagination2.BeatPreviewPageViewDataSource? {
		didSet {
			self.pageView?.dataSource = dataSource
		}
	}
	
	// We need some silliness here because of iOS responder chains
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.becomeFirstResponder()
	}
	public override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.pageView?.becomeFirstResponder()
	}
	public override func didMove(toParent parent: UIViewController?) {
		super.didMove(toParent: parent)
	
		if parent != nil {
			if !isFirstResponder { self.becomeFirstResponder() }
		} else {
			self.resignFirstResponder()
		}
	}
	
	public override var canBecomeFirstResponder: Bool {
		return true
	}
	
	public override func viewDidLoad() {
		self.pageView?.becomeFirstResponder()
		
		self.pageSettingsButton?.menu = UIMenu(children: [
			UIDeferredMenuElement.uncached { [weak self] completion in
				guard let delegate = self?.delegate else { completion([]); return }
				
				var items:[UIMenuElement] = []
				
				let sceneNumbers = UIAction(title: "Scene Numbers", state: delegate.documentSettings.getBool(DocSettingPrintSceneNumbers) ? .on : .off, handler: { _ in
					delegate.documentSettings.toggleBool(DocSettingPrintSceneNumbers)
					self?.delegate?.invalidatePreview()
				})
				
				let boldHeadings = UIAction(title: "Bolded", state: BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleBold) ? .on : .off) { _ in
					BeatUserDefaults.shared().toggleBool(BeatSettingHeadingStyleBold)
					self?.delegate?.reloadStyles()
					self?.delegate?.invalidatePreview()
				}
				let underlinedHeadings = UIAction(title: "Underlined", state: BeatUserDefaults.shared().getBool(BeatSettingHeadingStyleUnderlined) ? .on : .off) { _ in
					BeatUserDefaults.shared().toggleBool(BeatSettingHeadingStyleUnderlined)
					self?.delegate?.reloadStyles()
					self?.delegate?.invalidatePreview()
				}
				
				items.append(UIMenu(title: "Heading Style", options: .displayInline, children: [sceneNumbers, boldHeadings, underlinedHeadings]))
				
				let sections = UIAction(title: "Sections", state: delegate.documentSettings.getBool(DocSettingPrintSections) ? .on : .off, handler: { _ in
					delegate.documentSettings.toggleBool(DocSettingPrintSections)
					self?.delegate?.invalidatePreview()
				})
				
				let synopses = UIAction(title: "Synopses", state: delegate.documentSettings.getBool(DocSettingPrintSynopsis) ? .on : .off) { _ in
					delegate.documentSettings.toggleBool(DocSettingPrintSynopsis)
					self?.delegate?.invalidatePreview()
					self?.reload()
				}
				
				let notes = UIAction(title: "Notes", state: delegate.documentSettings.getBool(DocSettingPrintNotes) ? .on : .off) { _ in
					delegate.documentSettings.toggleBool(DocSettingPrintNotes)
					self?.delegate?.invalidatePreview()
					self?.reload()
				}
				
				items.append(UIMenu(title: "Print invisible Elements", options: .displayInline, children: [sections, synopses, notes]))

				completion(items)
			}
		])
		
	}
	
	public override var keyCommands: [UIKeyCommand]? {
		return [
			UIKeyCommand(action: #selector(closePreview), input: "e", modifierFlags: .command, discoverabilityTitle: "Close preview"),
			UIKeyCommand(action: #selector(closePreview), input: UIKeyCommand.inputEscape)
		]
	}
	
	public override func viewWillDisappear(_ animated: Bool) {
		resignFirstResponder()
		super.viewWillDisappear(animated)
	}
	
	public func clear() {
		self.pageView?.clear()
	}
	
	public func scrollToPage(_ pageIndex:Int) {
		self.pageView?.scrollToPage(pageIndex)
	}
	
	public func startLoadingAnimation() {
		self.pageView?.startLoadingAnimation()
	}
	
	public func endLoadingAnimation() {
		self.pageView?.endLoadingAnimation()
	}
	
	public func reload() {
		// Make sure the data source is up to date
		self.pageView?.dataSource = self.dataSource
		self.pageView?.reload()
	}
	
	/// This pops the preview from navigation
	@IBAction @objc func closePreview(sender:Any?) {
		self.resignFirstResponder()
		self.navigationController?.popViewController(animated: true)
		self.pageView?.clear()
	}
	
	/// This just dismisses the view
	@IBAction func dismissPreviewView(sender:Any) {
		self.dismiss(animated: true)
		self.pageView?.clear()
	}

}

@objc open class BeatPageScrollView: UIScrollView, UIScrollViewDelegate {
	/// Data source provide the views and number of pages
    @IBOutlet public var dataSource:BeatPreviewPageViewDataSource?
	@IBOutlet weak var activityIndicator:UIActivityIndicatorView?
	
	/// Container view for pages
	var container:UIView?
	/// Spacing between page views
    var spacing = 10.0
    /// Class value
    var loadedPageViews:[Int:UIView] = [:]
    /// Current page rects
    var pageRects:[CGRect] = []
        
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.customInit()
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.customInit()
    }
    
    func customInit() {
        self.bouncesZoom = true
        self.decelerationRate = .fast
        self.delegate = self
        
        self.maximumZoomScale = 2.0
		self.minimumZoomScale = 1.0
				
        backgroundColor = .black
        
        let container = UIView()
        self.addSubview(container)
        self.container = container
		
        self.delegate = self
	
		self.contentInset = UIEdgeInsets(top: spacing, left: 0.0, bottom: 0.0, right: 0.0)
		
        reload()
    }
	
	public override var keyCommands: [UIKeyCommand]? {
		return superview?.keyCommands
	}
		
	/// Removes all views from page view
	public func clear() {
		for pageView in self.loadedPageViews.values {
			pageView.removeFromSuperview()
		}
		
		self.loadedPageViews = [:]
	}
		
	public func startLoadingAnimation() {
		self.alpha = 0.5
		self.container?.alpha = 0.5
		self.activityIndicator?.isHidden = false
	}
	
	public func endLoadingAnimation() {
		self.alpha = 1.0
		self.container?.alpha = 1.0
		self.activityIndicator?.isHidden = true
	}
 
    override public var bounds: CGRect {
        didSet {
            updateContentPosition()
            loadPagesInBounds(self.bounds)
        }
    }
	
	override public var frame: CGRect {
		didSet {
			updateContentPosition()
			loadPagesInBounds(self.bounds)
		}
	}

    override public var contentSize: CGSize {
		didSet {
			updateContentPosition()
		}
    }
	
	public func scrollToPage(_ pageIndex:Int) {
		guard let container, pageIndex < self.pageRects.count else { return }
		
		let pageRect = self.pageRects[pageIndex]
		let localRect = container.convert(pageRect, to: self)
		
		self.scrollRectToVisible(localRect, animated: true)
	}
    
    public func updateScale() {
        // Fit the content to view
        let pageSize = self.dataSource?.pageSize() ?? BeatPaperSizing.size(for: .A4)
		
		let smallerSide = min(self.frame.size.width, self.frame.size.height)
        let scale = (smallerSide / pageSize.width) * 0.9
		
		// Update minimum zoom scale if needed
		if (scale < self.minimumZoomScale) { self.minimumZoomScale = scale }
        
		self.setZoomScale(scale, animated: false)
    }
    
	/// Centers content view
    private func updateContentPosition() {
		guard subviews.count > 0 else { return }
				
		// get the content view and center it
        let subView = subviews[0]
		let offset = self.bounds.width / 2
		subView.center = CGPointMake(offset, subView.center.y)
    }
    
	/// Reloads page data and draws pages in current bounds
    public func reload() {
        guard let container = self.container else {
            print("BeatPageViewController: No container")
            return
        }
        
		updateScale()
		
        let pageSize = self.dataSource?.pageSize() ?? BeatPaperSizing.size(for: .A4)
        let pages = self.dataSource?.numberOfPages() ?? 0
		
		// Why the FUCK do we need to scale the *container*? This seems counterintuitive.
		container.frame.size.width = pageSize.width * self.zoomScale
		container.frame.size.height = Double(pages) * (pageSize.height + spacing) * self.zoomScale
        
		// Reset loaded page views
		self.loadedPageViews = [:]
		
        //self.contentSize = container.frame.size
		self.contentSize = container.frame.size
        self.pageRects = rectsForPages()
        
        loadPagesInBounds(self.bounds)
        
		updateContentPosition()
		
		// Restore bounds
		self.bounds = bounds
    }

    /// Loads only the pages that have entered our bounds
    public func loadPagesInBounds(_ bounds:CGRect) {
        guard let container, let dataSource = self.dataSource else { return }
        
        for i in 0..<pageRects.count {
            let pageRect = pageRects[i]
            
			// Convert the visible page rect to scroll view coordinates
			let localRect = container.convert(pageRect, to: self)
			
            if !CGRectIntersectsRect(bounds, localRect) { continue }
            if loadedPageViews[i] != nil { continue }
            
			let view = dataSource.pageView(forPage: i, placeholder: false)
            view.frame = pageRect
            
            self.container?.addSubview(view)
            loadedPageViews[i] = view
        }
    }
    
    /// Returns the calculated frame for each page. Called on `reload()`.
    private func rectsForPages() -> [CGRect] {
        guard let dataSource = self.dataSource else {
            return []
        }
        
        let pages = dataSource.numberOfPages()
        let pageSize = dataSource.pageSize()
        
        var rects:[CGRect] = []
        
        for i in 0..<pages {
			let y = (pageSize.height + spacing) * CGFloat(i)
            let rect = CGRect(x: 0.0, y: y, width: pageSize.width, height: pageSize.height)
            rects.append(rect)
        }
        
        // Remove excess views
        let pageNumbers = self.loadedPageViews.keys
        for pageNumber in pageNumbers {
            if pageNumber >= rects.count {
                // Remove and unload
                let page = self.loadedPageViews[pageNumber]
                page?.removeFromSuperview()
                
                self.loadedPageViews.removeValue(forKey: pageNumber)
            }
        }
        
        return rects
    }
	
	
	public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		self.container
	}
}
