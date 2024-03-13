//
//  BeatUserDefaultButton.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatUserSettingSwitch:UISwitch {
	@IBInspectable var setting:String?
	// If the given setting is a document settings and not a user default
	@IBInspectable var documentSetting:Bool = false
	
	@IBInspectable var resetPreview:Bool = false
	@IBInspectable var redrawTextView:Bool = false
	@IBInspectable var reformatHeadings:Bool = false
	
	@IBInspectable var reloadOutline:Bool = false
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		guard let setting = self.setting else { return }
		
		if !documentSetting {
			// Get user default values. Document settings have to be set manually via a delegate.
			let value = BeatUserDefaults.shared().getBool(setting)
			self.setOn(value, animated: false)
		}
	}
}

class BeatUserSettingSegmentedControl:UISegmentedControl {
	@IBInspectable var setting:String?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		guard let setting = setting else { return }
		let value = BeatUserDefaults.shared().getInteger(setting)
		
		if value < self.numberOfSegments && value >= 0 {
			self.selectedSegmentIndex = value
		}
	}
}
