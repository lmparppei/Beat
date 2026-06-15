//
//  UIView+Scaling.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension UIView {
	func scaleViewTree(to scale:CGFloat) {
		scaleView(scale: scale)
		self.layer.scaleLayer(scale: scale)
	}
	
	func scaleView(scale: CGFloat) {
		let factor = (scale > 1.0) ? scale : 1.0
		
		self.contentScaleFactor = factor
		for vi in self.subviews {
			vi.scaleView(scale: factor)
		}
	}
}

extension CALayer {
	func scaleLayer(scale: CGFloat) {
		let factor = (scale > 1.0) ? scale : 1.0
		self.contentsScale = factor
		
		guard let sublayers = self.sublayers else { return }
		for la in sublayers {
			la.scaleLayer(scale: factor)
		}
	}
}
