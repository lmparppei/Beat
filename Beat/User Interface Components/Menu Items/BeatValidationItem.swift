//
//  BeatValidationItem.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class matches item selector to a property in another class, and checks if it's `true` or `false`.
 It's used to validate menus in document view. This approach should be deprecated ASAP.
 
 */

import Foundation
import BeatCore

@objc public protocol BeatMenuItemValidationInstance {
	func validate(delegate:BeatEditorDelegate) -> Bool
}

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
	
	@objc init(matchedValue:String, setting:String, action:Selector, target:AnyObject) {
		self.selector = action
		self.target = target
		self.setting = setting
		
		super.init()
	}
	
	@objc func validate() -> Bool {
		var value = false
		
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

/// How about this?
@objc class BeatSelfValidatingMenuItem:NSObject {
	weak var menuItem:NSMenuItem?
	weak var editorDelegate:BeatEditorDelegate?
	var handler:(_ delegate:BeatEditorDelegate?) -> Bool
	
	init(menuItem: NSMenuItem? = nil, handler: @escaping (_: BeatEditorDelegate?) -> Bool) {
		self.menuItem = menuItem
		self.handler = handler
	}
	
	@objc func validate() -> Bool {
		return handler(self.editorDelegate)
	}
}


/// A more sensible way to do the above
@objc class BeatOnOffMenuItem:NSMenuItem {
	@IBInspectable var documentSetting:Bool = false
	@IBInspectable var settingKey:String = ""
	@IBInspectable var requiresRedraw = false
	
	@objc func setChecked(document:BeatEditorDelegate? = nil) -> Bool {
		guard let document else { return false }
		
		var value = false
		
		if self.documentSetting {
			value = document.documentSettings.getBool(settingKey)
		} else {
			value = BeatUserDefaults.shared().getBool(settingKey)
		}
				
		self.state = (value) ? .on : .off

		return true
	}
}
