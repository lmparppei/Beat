//
//  BeatPageViewController.swift
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 23.1.2024.
//

import UIKit
import BeatPagination2
import BeatCore

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
	
    @IBOutlet public var dataSource:BeatPreviewPageViewDataSource?
    var container:UIView?
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
        self.minimumZoomScale = 0.5
        backgroundColor = .black
        
        let container = UIView()
        self.addSubview(container)
        self.container = container
        
        self.delegate = self
	
        reload()
    }
	
	public func clear() {
		for pageView in self.loadedPageViews.values {
			pageView.removeFromSuperview()
		}
		
		self.loadedPageViews = [:]
	}
	
	public func startLoadingAnimation() {
		//
	}
	
	public func endLoadingAnimation() {
		//
	}
 
    override public var bounds: CGRect {
        didSet {
            updateContentPosition()
            loadPagesInBounds(self.bounds)
        }
    }

    override public var contentSize: CGSize {
        didSet { updateContentPosition() }
    }
	
	public func scrollToPage(_ pageIndex:Int) {
		guard pageIndex < self.pageRects.count else { return }
		
		let pageRect = self.pageRects[pageIndex]
		self.scrollRectToVisible(pageRect, animated: true)
	}
    
    public func updateScale() {
        // Fit the content to view
        let pageSize = self.dataSource?.pageSize() ?? BeatPaperSizing.size(for: .A4)
        
        let verticalScale = (self.frame.height / pageSize.height) * 0.9
        let horizontalScale = (self.frame.width / pageSize.width) * 0.9
        
        let scale = min(verticalScale, horizontalScale)
        
        self.zoomScale = scale
        self.minimumZoomScale = scale
    }
    
    private func updateContentPosition() {
        let subView = subviews[0] // get the content view
        
        let offsetX = max(0.5 * (bounds.size.width - contentSize.width), 0.0)
        //let offsetY = max(0.5 * (bounds.size.height - contentSize.height), 0.0)

        subView.center = CGPointMake(contentSize.width * 0.5 + offsetX, subView.center.y)
    }
    
    public func reload() {
        guard let container = self.container else {
            print("BeatPageViewController: No container")
            return
        }
        
        let pageSize = self.dataSource?.pageSize() ?? BeatPaperSizing.size(for: .A4)
        let pages = self.dataSource?.numberOfPages() ?? 0
		
		let originalBounds = self.bounds
		
        container.frame.size.width = pageSize.width
        container.frame.size.height = Double(pages) * (pageSize.height + spacing)
        
		self.loadedPageViews = [:]
		
        self.contentSize = container.frame.size
        self.pageRects = rectsForPages()
        
        loadPagesInBounds(self.bounds)
        updateContentPosition()
		
		// Restore bounds
		self.bounds = bounds
    }

    /// Loads only the pages that have entered our bounds
    public func loadPagesInBounds(_ bounds:CGRect) {
        guard let dataSource = self.dataSource else { return }
        
        for i in 0..<pageRects.count {
            let pageRect = pageRects[i]
            
            if !CGRectIntersectsRect(bounds, pageRect) { continue }
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
            let rect = CGRect(x: 0.0, y: (pageSize.height + spacing) * CGFloat(i), width: pageSize.width, height: pageSize.height)
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
}
