//
//  BeatAdhocLicense.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.11.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore.BeatLocalization

class BeatAdhocLicenseManager:NSObject {
	
	// This is a very silly license manager with no actual robust checking, because, hey – this is FREE SOFTWARE.

	@objc public class var keyName:String {
		return "BeatLicenseKey"
	}
	
	@objc public class var hasValidKey:Bool {
		let key = NSUserDefaultsController.shared.defaults.string(forKey: "BeatLicenseKey") ?? ""
		return BeatAdhocLicenseManager.isValidKey(key)
	}
	
	@objc public class func enterLicenseKey() {
		let dialog = NSAlert()
		dialog.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.OK"))
		dialog.addButton(withTitle: BeatLocalization.localizedString(forKey: "general.cancel"))
		
		
		dialog.messageText = BeatLocalization.localizedString(forKey: "license.title")
		dialog.informativeText = BeatLocalization.localizedString(forKey: "license.info")
		
		let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
		input.placeholderString = "ABCD-EFGH-IJKL-MNOP"
		dialog.accessoryView = input

		
		if dialog.runModal() != .alertFirstButtonReturn {
			// Return if the user pressed cancel
			return
		}
		
		let key = input.stringValue
		var success = false
		if isValidKey(key) {
			NSUserDefaultsController.shared.defaults.set(key, forKey: BeatAdhocLicenseManager.keyName)
			success = true
		}
		
		let msg = NSAlert()
		if (!success) {
			msg.messageText = "Invalid License Key"
			msg.informativeText = "Unfortunately the key you applied was wrong. Please try again."
		} else {
			msg.messageText = "Thank You! ❤️"
			msg.informativeText = "You are a true friend of Beat. The app won't ask you to donate ever again."
		}
		
		msg.runModal()
	}
	
	@objc public class func isValidKey(_ key:String) -> Bool {
		// The string should be something like 0000-0000-0000-0000
		let uppercaseKey = key.uppercased()
		let components = uppercaseKey.components(separatedBy: "-")
		
		var nums:[Int] = []
		
		for component in components {
			if component.count < 4 {
				nums.append(0)
				continue
			}
			
			let f1 = component.prefix(2)
			let f2 = component.suffix(2)
			
			let n1 = UInt64(f1, radix: 16) ?? 0
			let n2 = UInt64(f2, radix: 16) ?? 0
			
			nums.append(Int(n1) - Int(n2))
		}

		if nums.count < 4 { return false }
		let matches = [42, 65, 61, 74]
		
		var success = true
		for i in 0..<4 {
			if matches[i] != nums[i] {
				success = false
			}
		}
		
		return success
	}
	
}
