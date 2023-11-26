//
//  BeatDocumentWindow.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit

class BeatDocumentWindow:NSWindow {
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	
	override func cancelOperation(_ sender: Any?) {
		editorDelegate?.returnToEditor?()
	}

}
