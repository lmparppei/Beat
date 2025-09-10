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
	@IBOutlet weak var printSceneNumbers:NSButton?
	@IBOutlet weak var printSynopsis:NSButton?
	@IBOutlet weak var printSections:NSButton?
	@IBOutlet weak var printNotes:NSButton?
	
	@IBOutlet weak var revision1:NSButton?
	@IBOutlet weak var revision2:NSButton?
	@IBOutlet weak var revision3:NSButton?
	@IBOutlet weak var revision4:NSButton?
	@IBOutlet weak var revision5:NSButton?
	@IBOutlet weak var revision6:NSButton?
	@IBOutlet weak var revision7:NSButton?
	@IBOutlet weak var revision8:NSButton?
	
	var revisionButtons:[NSButton] = []
	
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
			DocSettingPrintSceneNumbers: printSceneNumbers!,
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
		
		// We also need to check if revisions are visible or not
		self.revisionButtons = [revision1!, revision2!, revision3!, revision4!, revision5!, revision6!, revision7!, revision8!]
		let hiddenRevisions = documentSettings.get(DocSettingHiddenRevisions) as? [Int] ?? []
		for revisionButton in revisionButtons {
			revisionButton.state = hiddenRevisions.contains(revisionButton.tag) ? .off : .on
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
	
	@IBAction func toggleRevision(sender:NSButton?) {
		guard let sender, let editorDelegate else { return }
		var hiddenRevisions = editorDelegate.documentSettings.get(DocSettingHiddenRevisions) as? [Int] ?? []
		
		if (hiddenRevisions.contains(sender.tag)) {
			hiddenRevisions.removeObject(object: sender.tag)
		} else {
			hiddenRevisions.append(sender.tag)
		}
		
		editorDelegate.documentSettings.set(DocSettingHiddenRevisions, as: hiddenRevisions)
		
		editorDelegate.resetPreview()
	}
}
