//
//  BeatTagNameField.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.11.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatTagNameField:NSTextField {
	var originalText = ""
	override var isEditable: Bool {
		didSet {
			if (isEditable) { originalText = self.stringValue }
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		if self.isEditable {
			self.window?.makeFirstResponder(nil)
			
			self.isEditable = false
			self.stringValue = originalText
		}
	}
}
