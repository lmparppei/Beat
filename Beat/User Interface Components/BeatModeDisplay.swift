//
//  BeatModeDisplay.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

class BeatModeDisplay:NSView {
	
	@IBOutlet var title:NSTextField?
	@IBOutlet weak var editorDelegate:BeatEditorDelegate?
	
	override func awakeFromNib() {
		self.wantsLayer = true
		self.layer?.cornerRadius = 10.0
		self.layer?.backgroundColor = NSColor.darkGray.cgColor
	}
	
	override func viewWillDraw() {
		super.viewWillDraw()
	}
	
	@objc func showMode (modeName:String) {
		title?.stringValue = modeName
	}
	
	@IBAction func closeMode(sender: Any?) {
		self.editorDelegate?.mode = .EditMode
	}
	
	
	
}
