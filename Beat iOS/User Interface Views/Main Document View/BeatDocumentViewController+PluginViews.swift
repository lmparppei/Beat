//
//  BeatDocumentViewController+PluginViews.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 4.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

/// Support for plugin view floating buttons (future consideration)
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

