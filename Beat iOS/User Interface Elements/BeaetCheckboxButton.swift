//
//  BeaetCheckboxButton.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 10.5.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//
import UIKit
import BeatCore

class BeatCheckboxButton: UIButton {
	@IBInspectable var tintName:String = ""
	
	/// State
	public var isChecked = false {
		didSet {
			let image = (isChecked) ? "checkmark.square.fill" : "square"
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
		
		if tintName.count > 0 {
			if let color = BeatColors.color(tintName) {
				self.tintColor = color
			}
		}
	}
	
	func customInit() {
		self.addTarget(self, action: #selector(toggle), for: .primaryActionTriggered)
		backgroundColor = .clear
	}
	
	@objc func toggle(_ sender:Any?) {
		self.isChecked = !self.isChecked
	}
}
