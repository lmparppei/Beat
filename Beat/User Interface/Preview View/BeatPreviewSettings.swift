//
//  BeatPreviewSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

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
			  let button = sender?.cell as? BeatUserDefaultCheckboxCell
		else { return }
		
		documentSettings.setBool(button.userDefaultKey, as: (state == .on) ? true : false)
		
		// Reset preview
		self.editorDelegate?.invalidatePreview()
	}
}
