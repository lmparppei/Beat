//
//  BeatUserDefaultButton.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

public class BeatUserSettingSwitch:UISwitch {
	@IBInspectable public var setting:String?
	// If the given setting is a document settings and not a user default
	@IBInspectable public var documentSetting:Bool = false
	
	@IBInspectable public var resetPreview:Bool = false
	@IBInspectable public var redrawTextView:Bool = false
	@IBInspectable public var reformatHeadings:Bool = false
	
	@IBInspectable public var reloadOutline:Bool = false
	
	public override func awakeFromNib() {
		super.awakeFromNib()
		
		guard let setting = self.setting else { return }
		
		if !documentSetting {
			// Get user default values. Document settings have to be set manually via a delegate.
			let value = BeatUserDefaults.shared().getBool(setting)
			self.setOn(value, animated: false)
		}
	}
}

public class BeatUserSettingSegmentedControl:UISegmentedControl {
	@IBInspectable public var setting:String?
	@IBInspectable public var documentSetting:Bool = false
	
	public override func awakeFromNib() {
		super.awakeFromNib()
		
		guard let setting = setting else { return }
		let value = BeatUserDefaults.shared().getInteger(setting)
		
		if value < self.numberOfSegments && value >= 0 {
			self.selectedSegmentIndex = value
		}
	}
}
