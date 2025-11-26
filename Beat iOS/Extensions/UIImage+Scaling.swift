//
//  UIImage+Scaling.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 25.11.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

extension UIImage {
	/// Scales the image to the given CGSize
	func scaled(toSize size: CGSize) -> UIImage {
		if self.size == size { return self }
				
		let newImage = UIGraphicsImageRenderer(size: size).image { context in
			self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
		}
		return newImage.withRenderingMode(self.renderingMode)
	}
}
