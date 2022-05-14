//
//  BeatUITextView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatUITextView: UITextView {
	
	@IBInspectable var documentWidth:CGFloat = 640
	var insetTop = 30.0
	
	override var insetsLayoutMarginsFromSafeArea: Bool {
		get { return true }
		set { super.insetsLayoutMarginsFromSafeArea = true }
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		resize()
	}
	
	func resize() {
		var width = (self.superview!.frame.width - documentWidth) / 2;
		
		if (width < 0) { width = 10; }
		let insets = UIEdgeInsets.init(top: insetTop, left: width, bottom: insetTop, right: width)
		self.contentInset = insets
	}
	
	
}
