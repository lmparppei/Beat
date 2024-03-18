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

	override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
		super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
		print(self.tabbingMode.rawValue)
	}
	
	override func cancelOperation(_ sender: Any?) {
		editorDelegate?.returnToEditor?()
	}

	override class var userTabbingPreference: NSWindow.UserTabbingPreference {
		return .always
	}

	override var tabbingMode: NSWindow.TabbingMode {
		get { return .preferred }
		set {}
	}
}
