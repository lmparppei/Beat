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
	var renderer:BeatRenderManager?
	
	var timer:Timer?
	
	override var windowNibName: String! { get {
		return "BeatRendererTester"
	} }
	
	override func windowDidLoad() {
		super.windowDidLoad()
	
	}
	
	@objc init(screenplay:BeatScreenplay, settings:BeatExportSettings, delegate:BeatRenderDelegate) {
		self.screenplay = screenplay
		self.settings = settings
		
		self.renderer = BeatRenderManager(settings: self.settings!, delegate: delegate)
				
		super.init(window: nil) // Call this to get NSWindowController to init with the windowNibName property
		print("tester window:", self.window ?? "(null)")
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
		renderer!.newRender(screenplay: screenplay!, settings: settings!, forEditor: false, titlePage: false)
		
		if(self.scrollView == nil) {
			return
		}
		
		let pages = renderer!.getRenderedPages(titlePage: true)
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
			page.render()
			var f = page.frame
			f.origin.y = rect.height - (CGFloat(i) * page.frame.height) - (CGFloat(i) * 10)
			page.frame = f
			
			i += 1
		}
		
		self.window?.viewsNeedDisplay = true
	}
}
