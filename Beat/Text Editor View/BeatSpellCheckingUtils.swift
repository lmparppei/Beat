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
	
	var language = ""
	
	override func awakeFromNib() {
		language = UserDefaults.standard.value(forKey: "BeatSpellChecking") as? String ?? "auto"
		if (language == "") { language = "auto" }
		
		updateLanguage(language)
	}
	
	func menuWillOpen(_ menu: NSMenu) {
		guard let langMenu else { return }
		
		if langMenu.items.count < 3 {
			for l in spellChecking.userPreferredLanguages {
				let title = Locale.current.localizedString(forLanguageCode: l) ?? "(none)"
				
				let item = BeatLanguageMenuItem(title: title, action: #selector(selectLanguage), keyEquivalent: "")
				item.locale = l
				item.target = self
				
				langMenu.items.append(item)
			}
		}
				
		// Check preferred language. Automatic item is the first one.
		if language == "auto" {
			langMenu.items.first?.state = .on
		} else {
			language = spellChecking.language()
			
			// Update on/off status
			langMenu.items.forEach { item in
				if let menuItem = item as? BeatLanguageMenuItem {
					menuItem.state = (menuItem.locale == language) ? .on : .off
				}
			}
		}
	}
		
	@objc @IBAction func selectLanguage(_ sender:AnyObject) {
		let menuItem = sender as! BeatLanguageMenuItem
		
		// Store the language
		UserDefaults.standard.set(menuItem.locale, forKey: "BeatSpellChecking")
		updateLanguage(menuItem.locale)
	}
	
	func updateLanguage(_ language:String) {
		spellChecking.automaticallyIdentifiesLanguages = (language == "auto")
		
		if !spellChecking.automaticallyIdentifiesLanguages {
			spellChecking.setLanguage(language)
		}
	}
}

class BeatLanguageMenuItem:NSMenuItem {
	@IBInspectable var locale:String = ""
}
