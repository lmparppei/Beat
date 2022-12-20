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
	@IBOutlet var container:NSView?
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
		
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
			self.showRender()
		})
	}
	
	func showRender() {
		renderer!.newPagination(screenplay: screenplay!, settings: settings!, forEditor: false, changeAt: 0)
		
		guard let scrollView = self.scrollView,
			  let renderer = self.renderer,
			  let container = self.container
		else {
			return
		}

		for view in container.subviews {
			view.removeFromSuperview()
		}
		
		let contentHeight = CGFloat(renderer.pages.count) * (renderer.pageSize.height + 10.0)
		var rect = NSMakeRect(0, 0, renderer.pageSize.width, contentHeight)
		container.frame = rect
		
		let style = Styles.shared.page()
		
		for page in renderer.pages {
			let y = (container.subviews.last?.frame.origin.y ?? 0.0) + 10.0 + (container.subviews.last?.frame.size.height ?? 0.0)
			let string = page.attributedString()
			
			let view = BeatPaginationPageView(size: renderer.pageSize, content: string, pageStyle: style)
			let r = NSMakeRect(0, y, view.frame.width, view.frame.height)
			view.frame = r
			
			container.addSubview(view)
		}
		
		scrollView.documentView?.frame = NSMakeRect(0, 0, renderer.pageSize.width, contentHeight + 30)
		
		rect = NSMakeRect(0, 0, renderer.pageSize.width, contentHeight)
		container.frame = rect
		
		self.window?.viewsNeedDisplay = true
	}
}
