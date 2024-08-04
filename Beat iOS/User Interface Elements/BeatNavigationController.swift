//
//  BeatNavigationController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 10.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//
//  Thank you, @iwasrobbed on stackoverflow

import UIKit

final class BeatNavigationController: UINavigationController {
	
	// MARK: - Lifecycle
	
	override init(rootViewController: UIViewController) {
		super.init(rootViewController: rootViewController)
		delegate = self
	}
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		delegate = self
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		delegate = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// This needs to be in here, not in init
		interactivePopGestureRecognizer?.delegate = self
	}
	
	deinit {
		delegate = nil
		interactivePopGestureRecognizer?.delegate = nil
	}
	
	// MARK: - Overrides
	
	override func pushViewController(_ viewController: UIViewController, animated: Bool) {
		duringPushAnimation = true
		super.pushViewController(viewController, animated: animated)
	}
	
	// MARK: - Private Properties
	
	fileprivate var duringPushAnimation = false

}

// MARK: - UINavigationControllerDelegate

extension BeatNavigationController: UINavigationControllerDelegate {
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		guard let swipeNavigationController = navigationController as? BeatNavigationController else { return }
		
		swipeNavigationController.duringPushAnimation = false
	}
	
}

// MARK: - UIGestureRecognizerDelegate

extension BeatNavigationController: UIGestureRecognizerDelegate {
	
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard gestureRecognizer == interactivePopGestureRecognizer else {
			return true // default value
		}
		
		// Disable pop gesture in two situations:
		// 1) when the pop animation is in progress
		// 2) when user swipes quickly a couple of times and animations don't have time to be performed
		return viewControllers.count > 1 && duringPushAnimation == false
	}
}
