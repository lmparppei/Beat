//
//  InputAccessoryView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 25.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class InputAccessoryView:UIView {
	var editorDelegate:BeatEditorDelegate?
	
	func show(for textView:UITextView) {
		textView.autocorrectionType = .default
		textView.inputAccessoryView = self
	}
}
