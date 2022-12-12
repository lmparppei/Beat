//
//  File.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatSpellCheckingUtils:NSObject, NSMenuDelegate {
	@IBOutlet weak var langMenu:NSMenu?
	@IBOutlet weak var target:AnyObject?
	var spellChecking = NSSpellChecker.shared
	
	var lang = ""
	
	override func awakeFromNib() {
		var spLang = UserDefaults.standard.value(forKey: "BeatSpellChecking") as? String ?? "auto"
		if (spLang == "") { spLang = "auto" }
		
		lang = spLang
		if (lang == "auto") {
			spellChecking.automaticallyIdentifiesLanguages = true
		} else {
			spellChecking.automaticallyIdentifiesLanguages = false
			spellChecking.setLanguage(lang)
		}
	}
	
	func menuWillOpen(_ menu: NSMenu) {
		if langMenu == nil { return }
		
		if langMenu!.items.count < 3 {
			for l in spellChecking.userPreferredLanguages {
				let item = BeatLanguageMenuItem()
				item.keyEquivalent = ""
				item.title = Locale.current.localizedString(forLanguageCode: l) ?? "(none)"
				item.locale = l
				item.target = self
				item.action = #selector(selectLanguage)
				
				langMenu?.items.append(item)
			}
		}
				
		// Check preferred language
		var preferredLang = lang
		if (lang != "auto") {
			preferredLang = spellChecking.language()
		} else {
			let autoItem = langMenu!.items.first!
			autoItem.state = NSControl.StateValue.on
		}
		
		// Update on/off status
		for item in langMenu!.items {
			let menuItem = item as? BeatLanguageMenuItem ?? nil
			if (menuItem == nil) { continue }
			
			if menuItem!.locale == preferredLang {
				menuItem!.state = NSControl.StateValue.on
			} else {
				menuItem!.state = NSControl.StateValue.off
			}
		}
	}
		
	@objc @IBAction func selectLanguage(_ sender:AnyObject) {
		let menuItem = sender as! BeatLanguageMenuItem
		
		// Store the language
		lang = menuItem.locale
		UserDefaults.standard.set(menuItem.locale, forKey: "BeatSpellChecking")
		
		if menuItem.locale == "auto" {
			spellChecking.automaticallyIdentifiesLanguages = true
		} else {
			spellChecking.automaticallyIdentifiesLanguages = false
			spellChecking.setLanguage(menuItem.locale)
		}
	}
}

class BeatLanguageMenuItem:NSMenuItem {
	@IBInspectable var locale:String = ""
}
