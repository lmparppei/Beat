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
	public var dataSource: BeatPagination2.BeatPreviewPageViewDataSource? {
		didSet {
			self.pageView?.dataSource = dataSource
		}
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
	
	
	@IBAction func dismissPreviewView(sender:Any) {
		self.dismiss(animated: true)
		self.pageView?.clear()
	}
}

@objc open class BeatPageScrollView: UIScrollView, UIScrollViewDelegate {
	/// Data source provide the views and number of pages
    @IBOutlet public var dataSource:BeatPreviewPageViewDataSource?
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
		
	/// Removes all views from page view
	public func clear() {
		for pageView in self.loadedPageViews.values {
			pageView.removeFromSuperview()
		}
		
		self.loadedPageViews = [:]
	}
		
	public func startLoadingAnimation() {
		self.container?.alpha = 0.5
	}
	
	public func endLoadingAnimation() {
		self.container?.alpha = 1.0
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
            
            let view = dataSource.pageView(forPage: i)
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
