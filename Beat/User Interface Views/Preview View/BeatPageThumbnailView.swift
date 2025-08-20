//
//  BeatPageThumbnailView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa
import BeatPagination2
import BeatCore

class BeatPageThumbnailItem: NSCollectionViewItem {
	static let identifier = NSUserInterfaceItemIdentifier("PageThumbnail")
	
	override var isSelected: Bool {
		didSet {
			//guard let view = self.view.subviews.first else { return }
			
			if isSelected {
				view.subviews.first?.layer?.borderWidth = 3.0
				view.subviews.first?.layer?.borderColor = NSColor.highlightColor.cgColor
			} else {
				view.subviews.first?.layer?.borderWidth = 0.0
				view.subviews.first?.layer?.borderColor = .none
			}
		}
	}
	
	override func loadView() {
		view = NSView()
	}
	
	func configure(with contentView: NSView, pageNumber:Int, pageSize:CGSize) {
		self.view.subviews.forEach { $0.removeFromSuperview() }
		let p = 3.0
		let rect = CGRectMake(p, p, pageSize.width - p*2, pageSize.height - p*2)
		if let image:NSImage = contentView.imageRepresentation(size: rect.size) {
			let imgView = NSImageView(frame: rect)
			imgView.imageScaling = .scaleProportionallyDown
			imgView.image = image
			imgView.frame.origin.y = view.frame.height - imgView.frame.height
			view.addSubview(imgView)
			
			let label = NSTextField(labelWithString: (pageNumber > 0) ? "\(pageNumber)" : "")
			label.textColor = .textColor
			label.frame.size.width = view.frame.size.width
			label.frame.origin = CGPoint(x: 0, y: 0)
			label.alignment = .center
			label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
			view.addSubview(label)
		}
	}
	
	override func mouseDown(with event: NSEvent) {
		super.mouseDown(with: event)
	}

}

class BeatPageThumbnailView:NSCollectionView {
	@IBOutlet weak var pageDataSource:BeatPreviewPageViewDataSource?
	@IBOutlet var pageView:BeatPreviewPageView?
	var pageDataProvider:BeatPageThumbnailProvider?
	
	var itemSize: CGSize = CGSize(width: 0, height: 0)
	var maxWidth = 100.0
	var queuedSelection:IndexPath?
	
	override func viewWillDraw() {
		super.viewWillDraw()
		
		if let queuedSelection {
			self.selectItems(at: [queuedSelection], scrollPosition: .centeredVertically)
			self.queuedSelection = nil
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.isSelectable = true
		
		self.pageDataProvider = BeatPageThumbnailProvider(pageDataSource: pageDataSource, pageView: pageView)
		self.delegate = self.pageDataProvider
		self.dataSource = self.pageDataProvider
		
		self.register(BeatPageThumbnailItem.self, forItemWithIdentifier: BeatPageThumbnailItem.identifier)
		
		self.maxWidth = self.bounds.width * 0.8
		
		let pageSize = pageDataSource?.pageSize() ?? CGSize(width: 0, height: 0)
		let factor = pageSize.height / pageSize.width
		itemSize = CGSizeMake(maxWidth, maxWidth * factor)
		
		let layout = NSCollectionViewFlowLayout()
		layout.itemSize = itemSize
		layout.minimumInteritemSpacing = 10.0
		layout.minimumLineSpacing = 10.0
		self.collectionViewLayout = layout
	}
		
	override func reloadData() {
		if let superview = self.superview, superview.frame.width == 0 {
			// Don't reload invisible views
			return
		}
		
		let layout = self.collectionViewLayout as? NSCollectionViewFlowLayout
		
		// Update page size
		if let pageSize = pageDataSource?.pageSize() {
			maxWidth = self.bounds.width * 0.8
			
			let factor =  pageSize.height / pageSize.width
			let pageSize = CGSizeMake(maxWidth, maxWidth * factor)
			
			itemSize = CGSizeMake(pageSize.width, pageSize.height + 15)
			
			layout?.itemSize = itemSize
			pageDataProvider?.itemSize = itemSize
			pageDataProvider?.pageSize = pageSize
		}
		
		super.reloadData()
	}
	
	override func layout() {
		super.layout()
	}
	
	override func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
		guard let indexPath = indexPaths.first else { print("No index path"); return }
		if indexPath.item < numberOfItems(inSection: indexPath.section) {
			super.selectItems(at: indexPaths, scrollPosition: scrollPosition)
			self.queuedSelection = indexPaths.first
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		// Send esc forward
		guard let owner = window?.windowController?.owner as? AnyObject else { return }
		if owner.responds(to: #selector(cancelOperation)) {
			owner.cancelOperation(sender)
		}
	}
	
}

class BeatPageThumbnailProvider:NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
	weak var pageDataSource:BeatPreviewPageViewDataSource?
	weak var pageView:BeatPreviewPageView?
	
	var itemSize:CGSize = CGSizeMake(0.0, 0.0)
	var pageSize:CGSize = CGSizeMake(0.0, 0.0)
	
	init(pageDataSource: BeatPreviewPageViewDataSource? = nil, pageView:BeatPreviewPageView? = nil) {
		self.pageDataSource = pageDataSource
		self.pageView = pageView
	}
	
	func numberOfSections(in collectionView: NSCollectionView) -> Int {
		return 1
	}
	
	func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.pageDataSource?.numberOfPages() ?? 0
	}
	
	func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		let item = collectionView.makeItem(withIdentifier: BeatPageThumbnailItem.identifier, for: indexPath) as! BeatPageThumbnailItem
		
		let temporary = pageDataSource?.rendering ?? false
		
		if let view = pageDataSource?.pageView(forPage: indexPath.item, placeholder: temporary) {
			var pageNumber = indexPath.item + 1
			if self.pageDataSource?.hasTitlePage() ?? false {
				// Ignore page number at first page of a title page
				pageNumber -= 1
			}
			
			item.configure(with: view, pageNumber:pageNumber, pageSize: pageSize)
		}
		
		return item
	}
	
	func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
		return itemSize
	}
	
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		if let pView = collectionView as? BeatPageThumbnailView {
			pView.queuedSelection = nil
		}
	}
		
	func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
		if let path = Array(indexPaths).first {
			pageView?.scrollToPage(path.item)
		}
		
		return indexPaths
	}
	
	func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
		
	}
}

extension NSView {
	
	func imageRepresentation(size: CGSize) -> NSImage? {
		let size = self.bounds.size
		let imgSize = size
		
		if let bmp = self.bitmapImageRepForCachingDisplay(in: self.bounds) {
			bmp.size = imgSize
			self.cacheDisplay(in: self.bounds, to: bmp)
			
			let img = NSImage(size: imgSize)
			img.addRepresentation(bmp)
			
			if let resizedImg = img.resized(to: size) {
				return resizedImg
			}
		}
		
		return nil
	}

}
