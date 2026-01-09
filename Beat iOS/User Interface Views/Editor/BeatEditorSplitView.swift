//
//  BeatEditorSplitView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 18.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This is an embedded split view controller, and essentially some sort of a hack.
 Dread lightly. This separates the actual editor view from document view, which could
 cause some memory issues, but ... hasn't yet.
 
 */


import Foundation
import BeatCore

class BeatEditorSplitViewController:UISplitViewController, UISplitViewControllerDelegate {

	@objc public weak var editorDelegate:BeatEditorDelegate?
	
	@objc public weak var editorView:BeatEditorViewController? {
		guard self.viewControllers.count > 1 else { return nil }
		if let nav = self.viewControllers[1] as? UINavigationController {
			return nav.viewControllers.first as? BeatEditorViewController
		} else {
			return self.viewControllers[1] as? BeatEditorViewController
		}
	}
	
	@objc public weak var sidebar:BeatSidebarViewController? {
		guard self.viewControllers.count > 0 else { return nil }
		if let nav = self.viewControllers[0] as? UINavigationController {
			return nav.viewControllers.first as? BeatSidebarViewController
		} else {
			return self.viewControllers[0] as? BeatSidebarViewController
		}
	}
	
	@objc public weak var outlineView:BeatiOSOutlineView? {
		let vc = sidebar
		return vc?.tableView as? BeatiOSOutlineView
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.displayModeButtonVisibility = .never
		self.showsSecondaryOnlyButton = false
		
		self.presentsWithGesture = true
		
		self.preferredDisplayMode = .secondaryOnly
		self.preferredSplitBehavior = .displace
		self.delegate = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Force loading of views
		editorView?.loadView()
		sidebar?.loadView()
		
		self.primaryBackgroundStyle = .sidebar
		self.navigationController?.navigationBar.isHidden = true
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		hideAllNavigationBars()
	}
		
	@objc public func setup(editorDelegate:BeatEditorDelegate) {
		self.editorDelegate = editorDelegate
		self.outlineView?.setup(editorDelegate: editorDelegate)
	}
	
	func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
		//
	}
	
	override func removeFromParent() {
		self.editorView?.editorDelegate = nil
		self.editorView?.pageView = nil
		self.editorView?.scrollView = nil
		
		super.removeFromParent()
		
		self.viewControllers.removeAll()
	}
		
	/// Hides all navigation bars in the view controller hierarchy. I think split view automatically adds navigation controllers to the views (?) so we need to programmatically fix this.
	private func hideAllNavigationBars() {
		for viewController in viewControllers {
			if let navController = viewController as? UINavigationController {
				navController.setNavigationBarHidden(true, animated: false)
			}
		}
	}
	
	/// Delegate method to hide any sort of navigation bar when showing view controllers. This VC is embedded in the main document view controller, so we don't want any of these.
	func splitViewController(_ svc: UISplitViewController,
							willShow vc: UIViewController,
							invalidating barButtonItem: UIBarButtonItem) {
		if let navController = vc as? UINavigationController {
			navController.setNavigationBarHidden(true, animated: false)
		}
	}
	
}

class BeatEditorViewController:UIViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?
	@IBOutlet @objc public weak var scrollView:BeatScrollView?
	@IBOutlet @objc public weak var pageView:BeatPageView?
	@IBOutlet @objc public weak var testView:UITextView?
}

class BeatSidebarViewController:UITableViewController {
	@objc public weak var editorDelegate:BeatEditorDelegate?		
}

/**
 
 i'm 39 and amazed to be alive
    remembering how
   i once planned on dying
      maybe 15 years ago
     and went to say my farewells
 to
 parents
 grandparents
 my ex lover i still loved (still do)
 best friends
 coworkers
 the river
 the sea
 my instruments
 our band
 our records
 the rocky fence
 
 sat with them and never said a word
 never hinted  about what's to come
 i was brighter and easier than ever
 
 my home would become my tomb
 and i was ready
 until i realized i had too many things to do
 didn't want to leave others in trouble
 so i kept on working...
 
 and at some point
 i no longer dreamt about it
 or planned it
 
 i have it easy
 no bombs above my head
 no dead family in among rubbles
 the only one that used to want to kill me
 was me
 and somehow we made a truce
 
 no matter how fragile the peace may be
 i'm savouring
 every moment.
 
 
 */
