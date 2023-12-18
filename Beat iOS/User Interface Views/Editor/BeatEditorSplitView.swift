//
//  BeatEditorSplitView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 18.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore

class BeatEditorSplitViewController:UISplitViewController, UISplitViewControllerDelegate {

	@objc public weak var editorDelegate:BeatEditorDelegate?
	@objc public weak var textView:BeatUITextView?
	@objc public weak var container:UIView?
	
	@objc public weak var editorView:BeatEditorViewController? {
		let nav = self.viewControllers[1] as? UINavigationController
		return nav?.viewControllers.first as? BeatEditorViewController
	}
	
	@objc public weak var sidebar:BeatSidebarViewController? {
		let nav = self.viewControllers[0] as? UINavigationController
		return nav?.viewControllers.first as? BeatSidebarViewController
	}
	
	@objc public weak var outlineView:BeatiOSOutlineView? {
		let vc = sidebar
		return vc?.tableView as? BeatiOSOutlineView
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.displayModeButtonVisibility = .never
		self.showsSecondaryOnlyButton = false
		
		self.preferredDisplayMode = .secondaryOnly
		self.delegate = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		editorView?.loadView()
		sidebar?.loadView()
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		if let frame = container?.frame {
			print("ok!")
			self.view.frame.size = frame.size
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
	}
	
	@objc public func setup(editorDelegate:BeatEditorDelegate) {
		self.editorDelegate = editorDelegate
		self.outlineView?.setup(editorDelegate: editorDelegate)
	}
	
	func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
		//
	}
}

class BeatEditorViewController:UIViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?
	@IBOutlet @objc public var scrollView:BeatScrollView?
	@IBOutlet @objc public var pageView:BeatPageView?

}

class BeatSidebarViewController:UITableViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?
		
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView.keyboardDismissMode = .none
	}
}
