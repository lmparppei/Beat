//
//  BeatRendererTester.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatRendererTester:NSWindowController {
	
	@IBOutlet var scrollView:NSScrollView?
	
	var doc:Document?
	var screenplay:BeatScreenplay?
	var settings:BeatExportSettings?
	
	var timer:Timer?
	
	override var windowNibName: String! { get {
		return "BeatRendererTester"
	} }
	
	override func windowDidLoad() {
		super.windowDidLoad()
	
	}
	
	@objc init(doc:Document, screenplay:BeatScreenplay, settings:BeatExportSettings) {
		super.init(window: nil) // Call this to get NSWindowController to init with the windowNibName property
		
		self.document = doc
		self.screenplay = screenplay
		self.settings = settings
		
		print("The window...", self.window)
		print("sCROLL VIEW...", self.scrollView)
	}

	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func render(doc:Document, screenplay:BeatScreenplay, settings:BeatExportSettings) {
		self.doc = doc
		self.screenplay = screenplay
		self.settings = settings
	
		timer?.invalidate()
		
		timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { timer in
			self.showRender()
		})
	}
	
	func showRender() {
		var renderer = BeatRenderer(document: doc!, screenplay: screenplay!, settings: settings!, livePagination: false)
		renderer.paginate()
		
		if(self.scrollView == nil) {
			return
		}
		
		let pages = renderer.pages
		let content = self.scrollView!.documentView
		
		for view in content!.subviews {
			view.removeFromSuperview()
		}
		
		if (pages.count == 0) {
			print("No pages")
			return
		}
		
		let pageSize = pages.last!.frame.size
		let contentHeight = CGFloat(pages.count) * (pageSize.height + 10.0)
		
		var rect = content!.frame
		
		rect.size.width = pageSize.width + 10
		rect.size.height = contentHeight
		content!.frame = rect
		
		var i = 1
		for page in pages {
			content!.addSubview(page)
			var f = page.frame
			f.origin.y = rect.height - (CGFloat(i) * page.frame.height) - (CGFloat(i) * 10)
			page.frame = f
			
			i += 1
		}
		
		self.window?.viewsNeedDisplay = true
	}
}
