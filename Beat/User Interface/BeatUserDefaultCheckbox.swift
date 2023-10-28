//
//  BeatUserDefaultCheckbox.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc public class BeatUserDefaultControl:NSControl {
	@objc @IBInspectable var userDefaultKey:String = ""
	@objc @IBInspectable var requiresRefresh = false
}

@objc public class BeatUserDefaultCheckbox:NSButton {
	@objc @IBInspectable var userDefaultKey:String {
		get {
			let cell = self.cell as? BeatUserDefaultCheckboxCell
			return cell?.userDefaultKey ?? ""
		}
		set {
			let cell = self.cell as? BeatUserDefaultCheckboxCell
			cell?.userDefaultKey = newValue
		}
	}
	
	@objc @IBInspectable var requiresRefresh:Bool {
		get {
			let cell = self.cell as? BeatUserDefaultCheckboxCell
			return cell?.requiresRefresh ?? false
		}
		set {
			let cell = self.cell as? BeatUserDefaultCheckboxCell
			cell?.requiresRefresh = newValue
		}
	}
}

@objc class BeatUserDefaultCheckboxCell:NSButtonCell {
	@IBInspectable var userDefaultKey:String = ""
	@objc @IBInspectable var requiresRefresh = false
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		if userDefaultKey.count == 0 { return }
		let value = BeatUserDefaults.shared().getBool(userDefaultKey)
		
		if value { self.state = .on }
		else { self.state = .off }
	}
	
	override var state: NSControl.StateValue {
		get {
			return super.state
		}
		set {
			BeatUserDefaults.shared().save(self.checked(), forKey: userDefaultKey)
			super.state = newValue
		}
	}
	
	@objc func checked() -> Bool {
		if self.state == .on { return true }
		else { return false }
	}
}
