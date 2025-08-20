//
//  BeatDocumentViewController Extensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore
import BeatFileExport

/// Support for plugin view floating buttons
fileprivate var pluginViewControllers:[BeatPluginHTMLViewController] = []
fileprivate var pluginViewButtons:[BeatPluginHTMLViewController:UIButton] = [:]
extension BeatDocumentViewController {
	
	@objc func registerPluginViewController(_ viewController:BeatPluginHTMLViewController) {
		guard pluginViewControllers.firstIndex(of: viewController) == nil else { return }
		
		pluginViewControllers.append(viewController)
		
		
		let button = UIButton()
		button.backgroundColor = BeatColors.color("blue")
		
		let c = viewController.name?.first ?? "?"
		let title = String(c)
		
		button.title = title
		
		button.frame = CGRectMake(15.0, 15.0, 60.0, 60.0)
		button.layer.cornerRadius = button.frame.width / 2
		button.titleLabel?.adjustsFontSizeToFitWidth = true
		button.titleLabel?.font = UIFont.systemFont(ofSize: 20.0)
		
		self.view.addSubview(button)
		
		pluginViewButtons[viewController] = button
	}
	
	@objc func unregisterPluginViewController(_ viewController:BeatPluginHTMLViewController) {
		pluginViewControllers.removeObject(object: viewController)
		
		let button = pluginViewButtons[viewController]
		button?.removeFromSuperview()
		pluginViewButtons.removeValue(forKey: viewController)
	}
}

@objc public extension BeatDocumentViewController {
	
	@IBAction func nextScene(_ sender:Any!) {
		if let line = self.parser.nextOutlineItem(of: .heading, from: self.selectedRange().location) {
			self.scroll(to: line)
		}
	}
	
	@IBAction func previousScene(_ sender:Any!) {
		if let line = self.parser.previousOutlineItem(of: .heading, from: self.selectedRange().location) {
			self.scroll(to: line)
		}
	}		
}

/// An extension to trick conformance to `BeatBackupViewControlDelegate` and to show backups
@objc extension BeatDocumentViewController:BeatBackupViewControllerDelegate {
	@IBAction func showBackups() {
		let vc = BeatBackupViewController(delegate: self)
		present(vc, animated: true)
	}
}


