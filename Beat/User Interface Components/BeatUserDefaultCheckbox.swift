//
//  BeatUserDefaultCheckbox.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc public class BeatUserDefaultCheckbox:NSButton {
	@IBInspectable public var resetPreview:Bool = false
	@IBInspectable public var documentSetting:Bool = false
	@objc @IBInspectable var userDefaultKey:String = ""

	override public func awakeFromNib() {
		super.awakeFromNib()
		
		if userDefaultKey.count == 0 { return }
		let value = (!documentSetting) ? BeatUserDefaults.shared().getBool(userDefaultKey) : false
		
		if value { self.state = .on }
		else { self.state = .off }
	}
}

@objc class BeatUserDefaultCheckboxCell:NSButtonCell {
	override var state: NSControl.StateValue {
		get {
			return super.state
		}
		set {
			if let button = self.controlView as? BeatUserDefaultCheckbox {
				BeatUserDefaults.shared().save(self.checked(), forKey: button.userDefaultKey)
			}
			super.state = newValue
		}
	}
	
	@objc func checked() -> Bool {
		return (self.state == .on)
	}
}
