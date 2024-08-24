//
//  BeatNotepadView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 15.8.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore
import BeatDynamicColor

class BeatNotepadView:BeatNotepad, UITextViewDelegate {
	
	@IBOutlet var colorButtons:[UIButton] = []
	
	var defaultColor:DynamicColor = DynamicColor(lightColor: UIColor(white: 0, alpha: 1), darkColor: UIColor(white: 0.9, alpha: 1))!
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		
		self.delegate = self
		self.currentColor = defaultColor
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.setup()
	}
	
	func textViewDidChange(_ textView: UITextView) {
		self.didChangeText()
	}
	
}
