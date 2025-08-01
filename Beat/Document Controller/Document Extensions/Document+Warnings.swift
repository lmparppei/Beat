//
//  Document+Warnings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 31.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension Document {
	
	@objc func showDataHealthWarning() -> Bool {
		// At first we'll check if there are some range values we might be missing.
		let alert = NSAlert()
		alert.messageText = BeatLocalization.localizedString(forKey: "dataHealth.warning.title")
		alert.informativeText = BeatLocalization.localizedString(forKey: "dataHealth.warning.informative")
		
		alert.addButton(withTitle: BeatLocalization.localizedString(forKey: "dataHealth.warning.ignore"))
		alert.addButton(withTitle: BeatLocalization.localizedString(forKey: "dataHealth.warning.remove"))
		
		//Swift.print("Key window", NSApplication.shared.)
		let response = alert.runModal()
		if response != .alertSecondButtonReturn { return false }
				
		return true
	}
}
