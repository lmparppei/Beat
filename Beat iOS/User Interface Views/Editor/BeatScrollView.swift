//
//  BeatScrollView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 5.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatScrollView: UIScrollView {
	@objc public var manualScroll = false
	
	override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
		super.scrollRectToVisible(rect, animated: animated)
	}
	
	@objc public func safelyScrollRectToVisible(_ rect: CGRect, animated: Bool) {
		super.scrollRectToVisible(rect, animated: animated)
	}
}

