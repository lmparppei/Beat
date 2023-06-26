//
//  BeatOutlineSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

@objc public protocol BeatOutlineSettingDelegate {
	func reloadOutline()
}

class BeatOutlineSettings: NSViewController {
	@IBOutlet var showSynopsis:NSButton?
	@IBOutlet var showNotes:NSButton?
	@IBOutlet var showSceneNumbers:NSButton?
	@IBOutlet var showMarkers:NSButton?
	var settings:[String:NSButton] = [:]
	
	@objc weak var outlineDelegate:BeatOutlineSettingDelegate?
	
	init() {
		super.init(nibName: "BeatOutlineSettings", bundle: Bundle.main)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		self.settings = [
			BeatSettingShowNotesInOutline: showNotes!,
			BeatSettingShowSceneNumbersInOutline: showSceneNumbers!,
			BeatSettingShowSynopsisInOutline: showSynopsis!,
			BeatSettingShowMarkersInOutline: showMarkers!,
		]
		
		let userDefaults = BeatUserDefaults.shared()
		for key in settings.keys {
			let button = settings[key]
			if userDefaults.getBool(key) {
				button?.state = .on
			}
		}
	}
	
	@IBAction func toggle(sender:NSButton?) {
		guard let state = sender?.state else { return }
		let value = (state == .on) ? true : false
		
		var key = ""
		
		// Find the correct control
		for name in settings.keys {
			if settings[name] == sender {
				key = name
				break
			}
		}
		print("Setting:", key, value)
		
		if (key.count > 0) {
			BeatUserDefaults.shared().save(value, forKey: key)
			outlineDelegate?.reloadOutline()
		}
	}
}

