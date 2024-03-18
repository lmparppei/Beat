//
//  BeatDonationNag.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.11.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

import Cocoa

@objc public class BeatDonationPlea:NSObject {
	@objc public class func nag() {
		/*
		 // If you are compiling Beat yourself and don't want to see this nag screen, you can just uncomment return.
		 // Consider donating anyway. :-)
		 // return;
		 */
		
		if BeatAdhocLicenseManager.hasValidKey {
			// The user has already donated
			return
		}
		
		let alert = NSAlert()
		alert.messageText = "Thank you for using Beat! ❤️"
		alert.informativeText = "Beat is developed on spare time and using personal resources. It's free and open source — and always will be.\n\nIf you'd like to help make the app even better, please consider donating to the project. Any loose change actually makes a differene and lets me buy lunch or a coffee now and then. You'll also receive a donation key to remove this message.";
		
		alert.addButton(withTitle: "Donate")
		alert.addButton(withTitle: "Buy on App Store")
		alert.addButton(withTitle: "Remind Me Later")
		
		let response = alert.runModal()
		var url:URL?
		
		if response == .alertFirstButtonReturn {
			// Donate
			url = URL(string: "https://www.beat-app.fi/support-the-development/")
		} else if response == .alertSecondButtonReturn {
			// Buy on app store
			url = URL(string: "https://apps.apple.com/app/beat/id1549538329")
		}
		
		// If we've set the URL, open it
		if (url != nil) { NSWorkspace.shared.open(url!) }
	}
}
