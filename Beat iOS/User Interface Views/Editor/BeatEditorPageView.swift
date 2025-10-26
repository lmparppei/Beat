//
//  BeatEditorPageView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 5.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatPageView:UIView {
	@objc var shadowOpacity:CGFloat = 0.2
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		layer.shadowRadius = 3.0
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.2
		layer.shadowOffset = .zero
	}
	
	deinit {
		print("Deinit page view")
	}
	
	@objc func toggleShadow(_ value:Bool) {
		self.shadowOpacity = value ? 0.2 : 0
	}
}

