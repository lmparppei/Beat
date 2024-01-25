//
//  PageViewController.swift
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//

import Foundation
import UIKit
import BeatParsing
import BeatPagination2
import BeatCore

class BeatSinglePage:UIViewController {
    var string:NSAttributedString?
    var pageNumber = 0
    
    var textView:UITextView?
    var scrollView:ContentCenteringScrollView?
    
    init(string: NSAttributedString?, pageNumber: Int) {
        self.string = string
        self.pageNumber = pageNumber
        
        super.init(nibName: nil, bundle: nil)
        
        //self.view = UIView()
        let size = BeatPaperSizing.size(for: .A4)
        
        let scrollView = ContentCenteringScrollView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: self.view.frame.height))
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(scrollView)
    
        
        self.view.addSubview(scrollView)
        self.scrollView = scrollView
        
        let textView = UITextView(frame: CGRectMake(0.0, 0.0, size.width, size.height))
        textView.isEditable = false
        textView.attributedText = string
        
        self.scrollView?.addSubview(textView)
        self.textView = textView
        
        self.scrollView?.contentSize = textView.frame.size
        self.scrollView?.updateScale()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PageViewController:UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let pageView = viewController as? BeatSinglePage {
            let pageNumber = pageView.pageNumber - 1
            if (pageNumber < 0 || pageNumber > pageData.count || pageData.count == 0) {
                return nil
            } else {
                return BeatSinglePage(string: pageData[pageNumber], pageNumber: pageNumber)
            }
        }
        
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let pageView = viewController as? BeatSinglePage {
            let pageNumber = pageView.pageNumber + 1
            if (pageNumber >= pageData.count) {
                return nil
            } else {
                return BeatSinglePage(string: pageData[pageNumber], pageNumber: pageNumber)
            }
        }
        
        return nil
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        print("Presentation count", self.pageData.count)
        return self.pageData.count
    }
    
    var pageData:[NSAttributedString] = []
    
    override func viewDidLoad() {
        var string = ""
        if let url = Bundle.main.url(forResource: "Testi", withExtension: "fountain") {
            do {
                string = try String(contentsOf: url)
            } catch {
                //
            }
        }
        
        self.delegate = self
        self.dataSource = self
        
        let parser = ContinuousFountainParser(staticParsingWith: string, settings: BeatDocumentSettings())
        
        let settings = BeatExportSettings()
        settings.printSceneNumbers = true
        
        let pagination = BeatPaginationManager(settings: settings, delegate: nil, renderer: nil, livePagination: false)
        if let screenplay = BeatScreenplay.from(parser, settings: settings) {
            pagination.newPagination(screenplay: screenplay)
        }
        
        let renderer = BeatRenderer(settings: settings)
        
        self.pageData = renderer.renderPages(pagination.finishedPagination?.pages as? [BeatPaginationPage] ?? [])
        
        let vc = BeatSinglePage(string: pageData[0], pageNumber: 0)
        self.setViewControllers([vc], direction: .forward, animated: true)
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        
        if let vc = self.viewControllers?.first as? BeatSinglePage {
            return vc.pageNumber
        }
        
        return 0
    }
    
}

class ContentCenteringScrollView: UIScrollView, UIScrollViewDelegate {

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
    }
    
    override var bounds: CGRect {
        didSet { updateContentPosition() }
    }

    override var contentSize: CGSize {
        didSet { updateContentPosition() }
    }
    
    public func updateScale() {
        // Fit the content to view
        let verticalScale = (self.frame.height / self.contentSize.height) * 0.9
        let horizontalScale = (self.frame.width / self.contentSize.width) * 0.9
        
        let scale = min(verticalScale, horizontalScale)
        
        self.zoomScale = scale
        self.minimumZoomScale = scale
    }

    private func updateContentPosition() {
        let subView = subviews[0] // get the image view
        
        let offsetX = max(0.5 * (bounds.size.width - contentSize.width), 0.0)
        let offsetY = max(0.5 * (bounds.size.height - contentSize.height), 0.0)

        subView.center = CGPointMake(contentSize.width * 0.5 + offsetX, contentSize.height * 0.5 + offsetY)
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        updateContentPosition()
    }
    
    func setMaxMinZoomScalesForCurrentBounds() {
        let boundsSize: CGSize = self.bounds.size
        
        // calculate min/max zoom scale
        let xScale: CGFloat = boundsSize.width / contentSize.width   // the scale needed to perfectly fit the image width-wise
        let yScale: CGFloat = boundsSize.height / contentSize.height // the scale neede to perfectly fit the image height-wise
        
        // fill width if the image and phone are both in prortrait or both landscape; otherwise take smaller scale
        let imagePortrait: Bool = contentSize.height > contentSize.width
        let phonePortrait: Bool = boundsSize.height > boundsSize.width
        var minScale: CGFloat = imagePortrait == phonePortrait ? xScale : min(xScale, yScale)
        
        // on high res screens we have double the pixel density, so we will be seeing every pixel if we limit the max zoom scale to 0.5
        let maxScale: CGFloat = 1.0 / UIScreen.main.scale
        
        // don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be zoomed.)
        if minScale > maxScale {
            minScale = maxScale
        }
        
        self.maximumZoomScale = maxScale
        self.minimumZoomScale = minScale
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.subviews.first
    }
}
