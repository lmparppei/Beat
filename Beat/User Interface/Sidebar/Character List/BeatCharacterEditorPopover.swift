//
//  BeatCharacterEditorPopup.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc class BeatCharacter:NSObject
{
	@objc var name:String = ""
	@objc var gender:String = ""
	@objc var lines:Int = 0
	@objc var scenes:NSMutableSet = NSMutableSet()
}

@objc protocol BeatCharacterListDelegate: AnyObject {
	func setGender(name: String, gender: String)
	func getGender(forName name: String) -> String?
	
	func prevLine(for chr:BeatCharacter)
	func nextLine(for chr:BeatCharacter)
}

@objc class BeatCharacterEditorPopoverManager:NSObject {
	@objc let popover: NSPopover
	private let infoTextView: NSTextView
	private let genderRadioButtons: [BeatGenderRadioButton]
	weak private var listDelegate: BeatCharacterListDelegate?
	var character:BeatCharacter
	
	@objc init(delegate:BeatCharacterListDelegate, character:BeatCharacter) {
		self.character = character
		
		popover = NSPopover()
				
		self.infoTextView = NSTextView(frame: NSZeroRect)
	
		genderRadioButtons = [
			BeatGenderRadioButton(frame: NSZeroRect, gender: "unspecified"),
			BeatGenderRadioButton(frame: NSZeroRect, gender: "woman"),
			BeatGenderRadioButton(frame: NSZeroRect, gender: "man"),
			BeatGenderRadioButton(frame: NSZeroRect, gender: "other")
		]
		
		listDelegate = delegate
		
		super.init()
		
		configurePopover()
	}
	
	private func configurePopover() {
		// Create the view for the popover content
		let contentView = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 160))
		contentView.layer?.backgroundColor = NSColor.blue.cgColor
		
		infoTextView.frame = contentView.frame
		infoTextView.isEditable = false
		infoTextView.drawsBackground = false
		infoTextView.isRichText = false
		infoTextView.usesRuler = false
		infoTextView.isSelectable = false
		infoTextView.textContainerInset = NSSize(width: 8, height: 8)
		infoTextView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		
		contentView.addSubview(infoTextView)
		
		// Set frame and action for gender radio buttons
		let yOrigin = contentView.frame.size.height - (CGFloat(genderRadioButtons.count) * 20.0) - 8.0
		for (index, button) in genderRadioButtons.enumerated() {
			button.target = self
			button.action = #selector(genderRadioButtonClicked(_:))
			button.tag = index
			
			button.frame = NSRect(x: 8.0, y: yOrigin + (CGFloat(index) * 20.0), width: 150.0, height: 20.0)
			contentView.addSubview(button)
		}
		
		// Info text
		let infoString = String(format: "%@\n%@: %lu\n%@: %lu",
								character.name,
								NSLocalizedString("statistics.lines", comment: ""),
								character.lines,
								NSLocalizedString("statistics.scenes", comment: ""),
								character.scenes.count)
		self.infoTextView.string = infoString
		
		// Next/prev line buttons
		let buttonUp = NSButton(title: "▲", target: self, action: #selector(prevLine))
		let buttonDown = NSButton(title: "▼", target: self, action: #selector(nextLine))

		var upFrame = buttonUp.frame
		var downFrame = buttonDown.frame

		upFrame.origin.x = contentView.frame.width - upFrame.width
		upFrame.origin.y = contentView.frame.height - upFrame.height
		
		downFrame.origin.x = contentView.frame.width - downFrame.width
		downFrame.origin.y = 0
		
		buttonUp.frame = downFrame
		buttonDown.frame = upFrame

		contentView.addSubview(buttonUp)
		contentView.addSubview(buttonDown)
		
		
		// Get gender for this character
		for button in genderRadioButtons {
			if button.gender == character.gender {
				button.state = .on
				break
			}
		}
		
		// Create the popover with the content view
		popover.contentViewController = NSViewController()
		popover.contentViewController?.view = contentView
		
		// Set the popover behavior
		popover.behavior = .semitransient
	}
	
	
	@objc @IBAction func genderRadioButtonClicked(_ sender: BeatGenderRadioButton) {
		let gender = sender.gender
		listDelegate?.setGender(name: self.character.name, gender: gender)
	}
	
	@objc func prevLine() {
		self.listDelegate?.prevLine(for: character)
	}
	
	@objc func nextLine() {
		self.listDelegate?.nextLine(for: character)
	}
}

class BeatGenderRadioButton:NSButton {
	var gender:String
	init(frame frameRect: NSRect, gender:String) {
		self.gender = gender
		super.init(frame: frameRect)
		
		self.setButtonType(.radio)
		self.title = NSLocalizedString("gender." + self.gender, comment: "")
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
}
