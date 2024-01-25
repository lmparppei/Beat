//
//  BeatPageViewController.swift
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 23.1.2024.
//

import UIKit

@objc protocol BeatPageViewControllerDataSource {
    func numberOfPages() -> Int
    func pageSize() -> CGSize
    func pageView(forPage pageIndex:Int) -> UIView
}

class BeatPageViewController: UIScrollView, UIScrollViewDelegate, BeatPageViewControllerDataSource {
    @IBOutlet var dataSource:BeatPageViewControllerDataSource?
    var container:UIView?
    var spacing = 10.0
    
    /// Delegate value
    var pageViews:[UIView] = []
    /// Class value
    var loadedPageViews:[Int:UIView] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.customInit()
    }
    
    required init(coder aDecoder: NSCoder) {
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
        
        self.dataSource = self
        self.delegate = self
        
        reload()
    }
    
    func numberOfPages() -> Int {
        return 5
    }
    func pageSize() -> CGSize {
        return BeatPaperSizing.size(for: .A4)
    }
    
    func pageView(forPage pageIndex: Int) -> UIView {
        if pageIndex < pageViews.count {
            return pageViews[pageIndex]
        }
        
        let view = UIView()
        view.frame.size = pageSize()
        view.backgroundColor = .white
        
        let label = UILabel()
        label.text = "Page \(pageIndex)"
        view.addSubview(label)
        
        pageViews.append(view)
        
        return view
    }
 
    override var bounds: CGRect {
        didSet {
            updateContentPosition()
            loadPagesInBounds(self.bounds)
        }
    }

    override var contentSize: CGSize {
        didSet { updateContentPosition() }
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
        
        container.frame.size.width = pageSize.width
        container.frame.size.height = Double(pages) * (pageSize.height + spacing)
        
        self.contentSize = container.frame.size
        
        loadPagesInBounds(self.bounds)
        updateContentPosition()
    }

    /// Loads only the pages that have entered our bounds
    public func loadPagesInBounds(_ bounds:CGRect) {
        guard let dataSource = self.dataSource else { return }
        
        let rects = rectsForPages()
        for i in 0..<rects.count {
            let pageRect = rects[i]
            
            if !CGRectIntersectsRect(bounds, pageRect) { continue }
            if loadedPageViews[i] != nil { continue }
            
            let view = dataSource.pageView(forPage: i)
            view.frame = pageRect
            
            self.container?.addSubview(view)
            loadedPageViews[i] = view
        }
    }
    
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
        
        return rects
    }
    
}
