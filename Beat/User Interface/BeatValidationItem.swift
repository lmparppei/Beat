//
//  BeatValidationItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 ValidationItem converted to Swift for learning reasons. Nothing to see here.
 
 */

import Foundation

class BeatValidationItem: NSObject {

	var title:String?
	var setting:String
	var selector:Selector?
	var target:AnyObject!

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
	
	
	func validate() -> Bool {
		var value:Bool = false
		
		if (self.target.className == "BeatDocumentSettings") {
			// Document settings
			let settings = self.target as! BeatDocumentSettings
			value = settings.getBool(self.setting)
		} else {
			let num = self.target.value(forKey: setting) as! NSNumber
			value = num.boolValue
		}
		
		return value
	}
}

