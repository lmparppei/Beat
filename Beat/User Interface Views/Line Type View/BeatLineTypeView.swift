//
//  BeatLineTypeView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

class BeatLineTypeView:NSView {
	@IBOutlet weak var label:NSTextField?
	@IBOutlet weak var delegate:BeatEditorDelegate?
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.isHidden = (BeatUserDefaults.shared().getBool(BeatSettingLineTypeView)) ? false : true
		
		NotificationCenter.default.addObserver(self, selector: #selector(setup), name: NSNotification.Name("SettingToggled"), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSTextView.didChangeSelectionNotification, object: self.delegate!.getTextView()!)
		
		setup()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	@objc func setup() {
		self.isHidden = (BeatUserDefaults.shared().getBool(BeatSettingLineTypeView)) ? false : true
		
		if !self.isHidden {
			self.wantsLayer = self.isHidden ? false : true
			
			self.layer?.cornerRadius = 10.0
			self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
			
			if let filter = CIFilter(name:"CIGaussianBlur") {
				filter.name = "myFilter"
				self.layer?.backgroundFilters = [filter]
				self.layer?.setValue(2, forKeyPath: "backgroundFilters.myFilter.inputRadius")
			}
		} else {
			self.wantsLayer = false
			self.layer?.backgroundFilters = []
		}
		
		update()
	}
	
	@objc func update() {
		guard !self.isHidden, let line = delegate?.currentLine else {
			return
		}
		
		var text = line.typeName() ?? ""
		if text.count > 0 {
			text = BeatLocalization.localizedString(forKey: "type." + text)
		}
		
		self.label?.textColor = (line.type != .empty) ? .white : .gray
		self.label?.stringValue = text
	}
}
