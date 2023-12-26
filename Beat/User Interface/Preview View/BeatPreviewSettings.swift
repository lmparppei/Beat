//
//  BeatPreviewSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 Popover menu for adjusting what invisible elements should be included in the print.
 
 */

import AppKit

@objc class BeatPreviewOptions:NSViewController {
	@IBOutlet weak var printSynopsis:NSButton?
	@IBOutlet weak var printSections:NSButton?
	@IBOutlet weak var printNotes:NSButton?
	
	var settings:[String:NSButton] = [:]
	
	@objc weak var editorDelegate:BeatEditorDelegate?
	
	init() {
		super.init(nibName: "BeatPreviewSettings", bundle: Bundle.main)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		guard let documentSettings = self.editorDelegate?.documentSettings else { return }
		
		self.settings = [
			DocSettingPrintNotes: printNotes!,
			DocSettingPrintSynopsis: printSynopsis!,
			DocSettingPrintSections: printSections!
		]
		
		// These checkboxes won't load their state automatically, because printing
		// invisible elements is a document setting, so we need to set it manually.
		for key in settings.keys {
			let button = settings[key]
			if documentSettings.getBool(key) {
				button?.state = .on
			}
		}
	}
	
	@IBAction func toggle(sender:NSButton?) {
		guard let state = sender?.state,
			  let documentSettings = editorDelegate?.documentSettings,
			  let button = sender as? BeatUserDefaultCheckbox
		else { return }
		
		// Set document setting
		documentSettings.setBool(button.userDefaultKey, as: (state == .on) ? true : false)
		
		// Reset preview
		self.editorDelegate?.invalidatePreview()
	}
}
