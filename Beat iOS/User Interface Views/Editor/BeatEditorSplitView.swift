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
	}
	
	@objc public func setup(editorDelegate:BeatEditorDelegate) {
		self.editorDelegate = editorDelegate
		self.outlineView?.setup(editorDelegate: editorDelegate)
	}
}

class BeatEditorViewController:UIViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?
	@IBOutlet @objc public weak var scrollView:BeatScrollView?
	@IBOutlet @objc public weak var pageView:BeatPageView?
}

class BeatSidebarViewController:UITableViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?
}
