//
//  BeatValidationItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatValidationItem: NSObject {

	@objc var title:String?
	@objc var setting:String
	@objc var target:AnyObject!
	@objc var selector:Selector?

	@objc init(title:String, setting:String, target:AnyObject ) {
		self.title = title
		self.setting = setting
		self.target = target
		
		super.init()
	}
	
	@objc init(action:Selector, setting:String, target:AnyObject) {
		self.selector = action
		self.setting = setting
		self.target = target
		
		super.init()
	}
	
	
	@objc func validate() -> Bool {
		var value:Bool = false
		
		if (self.target.className == "BeatDocumentSettings") {
			// Document settings
			if let settings = self.target as? BeatDocumentSettings {
				value = settings.getBool(self.setting)
			}
		} else if (self.target.className == "BeatUserDefaults") {
			// User defaults
			value = BeatUserDefaults.shared().getBool(self.setting)
		} else {
			// Get via selector from document
			if let num = self.target.value(forKey: setting) as? NSNumber {
				value = num.boolValue
			}
		}
		
		return value
	}
}

