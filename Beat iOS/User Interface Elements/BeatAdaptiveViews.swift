//
//  BeatAdaptiveViews.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

/// Collection of adaptive views with a inspectable toggle for setting them on/off on phones and pads

import UIKit

class BeatAdaptiveNavigationBarButton:UIBarButtonItem {
	@IBInspectable var hideOnPhone:Bool = false
	@IBInspectable var hideOnPad:Bool = false
	override func awakeFromNib() {
		super.awakeFromNib()
		
		let device = UIDevice.current.userInterfaceIdiom
		
		if hideOnPhone && device == .phone { self.isHidden = true }
		if hideOnPad && device == .pad { self.isHidden = true }
	}
}

class BeatAdaptiveCellView:UITableViewCell {
	@IBInspectable var hiddenOnMobile:Bool = false
	@IBInspectable var hiddenOnPad:Bool = false
	@IBInspectable var name:String = ""
		
	override func awakeFromNib() {
		super.awakeFromNib()
		
		let device = UIDevice.current.userInterfaceIdiom
		
		if hiddenOnMobile && device == .phone { self.isHidden = true }
		if hiddenOnPad && device == .pad { self.isHidden = true }
	}
}

class BeatStylesheetAdaptiveCellView:UITableViewCell {
	@IBInspectable var stylesheet:String = ""
}

