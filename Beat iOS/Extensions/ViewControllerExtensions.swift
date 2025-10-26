//
//  ViewControllerExtensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 13.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension UIViewController {
	@IBAction func dismissViewController(sender:Any?) {
		self.dismiss(animated: true)
	}
	
	@objc func embed(_ viewController:UIViewController, inView view:UIView) {
		viewController.willMove(toParent: self)
		viewController.view.frame = view.bounds

		view.addSubview(viewController.view)
		self.addChild(viewController)

		viewController.didMove(toParent: self)
	}
	
	@objc func removeChildren() {
		if self.children.count > 0 {
			for vc in self.children {
				vc.willMove(toParent: nil)
				vc.view.removeFromSuperview()
				vc.removeFromParent()
			}
		}
	}
}
