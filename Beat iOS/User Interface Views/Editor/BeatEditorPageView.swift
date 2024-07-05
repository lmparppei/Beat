//
//  BeatEditorPageView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 5.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatPageView:UIView {
	override func awakeFromNib() {
		super.awakeFromNib()
		
		layer.shadowRadius = 3.0
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.2
		layer.shadowOffset = .zero
	}
}

