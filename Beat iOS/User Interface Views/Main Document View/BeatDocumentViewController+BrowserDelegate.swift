//
//  BeatDocumentViewController+BrowserDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.9.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import SwiftUI


extension UIDocument.CreationIntent {
	static let template = UIDocument.CreationIntent("template")
}

extension BeatDocumentViewController:UIDocumentBrowserViewControllerDelegate {
	
	@objc func setupLaunchItems() {
		self.launchOptions.browserViewController.delegate = self
		
		self.launchOptions.background.backgroundColor = BeatColors.color("backgroundDarkGray")
		self.launchOptions.background.image = UIImage(named: "browser.background")
		self.launchOptions.background.imageContentMode = .scaleAspectFill
				
		self.launchOptions.primaryAction = UIDocumentViewController.LaunchOptions.createDocumentAction(withIntent: .default)
		self.launchOptions.primaryAction?.title = "New Document"
		self.launchOptions.primaryAction?.subtitle = "Start A New, Blank Project"
		self.launchOptions.primaryAction?.image = UIImage(systemName: "document")
		
		let templateAction = UIDocumentViewController.LaunchOptions.createDocumentAction(withIntent: .template)
		templateAction.title = "Templates & Tutorials"
		templateAction.subtitle = "Get Familiar With Beat and Fountain"
		templateAction.image = UIImage(systemName: "map")
		
		self.launchOptions.secondaryAction = templateAction
	}
	
	public func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
		guard let intent = controller.activeDocumentCreationIntent else { return }
		
		if intent == .template {
			pickTemplate(importHandler: importHandler)
		}
	}
	
	/// Force template menu
	func pickTemplate(importHandler: @escaping ((URL?, UIDocumentBrowserViewController.ImportMode) -> Void)) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let templateVC = storyboard.instantiateViewController(identifier: "TemplateCollectionViewController") as TemplateCollectionViewController
		templateVC.importHandler = importHandler
		
		templateVC.importHandler = { url, mode in
			if let url {
				importHandler(url, mode)
			} else {
				importHandler(nil, .none)
			}
			
			
		}
		
		present(templateVC, animated: true)
	}
	
}
