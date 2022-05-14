//
//  DocumentView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class DocumentController: NSObject, UITextViewDelegate {
	var document:UIDocument?
	var parser:ContinuousFountainParser?

	func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
		
		
		return true
	}
}
