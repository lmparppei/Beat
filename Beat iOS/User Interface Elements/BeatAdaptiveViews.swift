//
//  BeatAdaptiveViews.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

/// Collection of adaptive views with a inspectable toggle for setting them on/off on phones

import UIKit

class BeatAdaptiveNavigationBarButton:UIBarButtonItem {
	@IBInspectable var hideOnPhone:Bool = false
	override func awakeFromNib() {
		super.awakeFromNib()
		
		if hideOnPhone && UIDevice.current.userInterfaceIdiom == .phone {
			self.isHidden = true
		}
	}
}

class BeatAdaptiveCellView:UITableViewCell {
	@IBInspectable var hiddenOnMobile:Bool = false
		
	override func awakeFromNib() {
		super.awakeFromNib()
		if hiddenOnMobile && UIDevice.current.userInterfaceIdiom == .phone {
			self.isHidden = true
		}
	}
}
