//
//  UIView+Scaling.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 28.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension UIView {
	func scaleView(view: UIView, scale: CGFloat) {
		let factor = (scale > 1.0) ? scale : 1.0
		
		view.contentScaleFactor = factor
		for vi in view.subviews {
			scaleView(view: vi, scale: factor)
		}
	}

	func scaleLayer(layer: CALayer, scale: CGFloat) {
		let factor = (scale > 1.0) ? scale : 1.0
		
		layer.contentsScale = factor
		if layer.sublayers == nil {
			return
		}
		for la in layer.sublayers! {
			scaleLayer(layer: la, scale: factor)
		}
	}
}
