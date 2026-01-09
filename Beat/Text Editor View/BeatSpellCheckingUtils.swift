//
//  File.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore.BeatUserDefaults

class BeatSpellCheckingUtils:NSObject, NSMenuDelegate {
	@IBOutlet weak var langMenu:NSMenu?
	@IBOutlet weak var target:AnyObject?
	var spellChecking = NSSpellChecker.shared
	
	var language:String {
		get {
			let lang = BeatUserDefaults.shared().get(BeatSpellCheckingLanguage) as? String ?? "auto"
			return lang == "" ? "auto" : lang
		}
		set {
			BeatUserDefaults.shared().save(newValue, forKey: BeatSpellCheckingLanguage)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		updateLanguage(language)
	}
	
	func menuWillOpen(_ menu: NSMenu) {
		guard let langMenu else { return }
		
		if langMenu.items.count < 3 {
			for l in spellChecking.availableLanguages {
				let title = localizedSpellLanguageName(l)
				
				let item = BeatLanguageMenuItem(title: title, action: #selector(selectLanguage), keyEquivalent: "")
				item.locale = l
				item.target = self
				
				langMenu.items.append(item)
			}
		}
				
		// Update on/off status
		langMenu.items.forEach { item in
			if let menuItem = item as? BeatLanguageMenuItem {
				menuItem.state = (menuItem.locale == language) ? .on : .off
			}
		}
	}
		
	@objc @IBAction func selectLanguage(_ sender:AnyObject) {
		guard let menuItem = sender as? BeatLanguageMenuItem else {
			print("Spell checking utils: Wrong menu item class")
			return
		}
		
		// Store the language
		let lang = menuItem.locale
		
		self.language = lang
		updateLanguage(lang)
		
		NotificationCenter.default.post(name: .languageChange, object: nil)
	}
	
	func updateLanguage(_ language:String) {
		spellChecking.automaticallyIdentifiesLanguages = (language == "auto")
		
		if !spellChecking.automaticallyIdentifiesLanguages {
			spellChecking.setLanguage(language)
		} else {
			spellChecking.setLanguage("")
		}
	}
	
	func localizedSpellLanguageName(_ identifier: String) -> String {
		let locale = Locale.current
		
		// Split BCP-47 / legacy identifiers: "en", "en_US", "en-US"
		let parts = identifier
			.replacingOccurrences(of: "-", with: "_")
			.split(separator: "_")
		
		guard let languageCode = parts.first.map(String.init) else {
			return identifier
		}
		
		let regionCode: String?
		if parts.count >= 2 {
			regionCode = String(parts[1])
		} else {
			regionCode = nil
		}
		
		let languageName = locale.localizedString(forLanguageCode: languageCode)
		
		let regionName = regionCode.flatMap {
			locale.localizedString(forRegionCode: $0)
		}
		
		switch (languageName, regionName) {
		case let (language?, region?):
			return "\(language) (\(region))"
		case let (language?, nil):
			return language
		default:
			return identifier
		}
	}

}

class BeatLanguageMenuItem:NSMenuItem {
	@IBInspectable var locale:String = ""
}

extension Notification.Name {
	static let languageChange = Notification.Name("BeatLanguageChangedNotification")
}
