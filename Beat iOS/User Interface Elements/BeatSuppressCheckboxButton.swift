//
//  BeatCheckboxButton.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 17.2.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatSuppressCheckboxButton: UIButton {

	/// `BeatUserDefault` key for the observed setting
	@IBInspectable var alertName:String = ""
	
	/// State
	public var isChecked = false {
		didSet {
			let image = (isChecked) ? "checkmark.square.fill" : "square"
			//self.imageView?.image = UIImage(systemName: image)
			self.setImage(UIImage(systemName: image), for: .normal)
		}
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		customInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		customInit()
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		let suppressed = BeatUserDefaults.shared().isSuppressed(alertName)
		self.isChecked = !suppressed
	}
	
	func customInit() {
		self.addTarget(self, action: #selector(toggle), for: .primaryActionTriggered)
	}
	
	@objc func toggle(_ sender:Any?) {
		self.isChecked = !self.isChecked

		// This checkbox tracks the opposite value of suppression (ie. "show this", not "don't show this")
		if (alertName.count > 0) {
			BeatUserDefaults.shared().setSuppressed(alertName, value: !isChecked)
			print("Set suppressed:", !isChecked)
		}
	}
}
