//
//  BeatCharacterEditorPopup.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

@objc protocol BeatCharacterListDelegate: AnyObject {
	func prevLine(for chr:BeatCharacter)
	func nextLine(for chr:BeatCharacter)
	
	func saveCharacter(_ character:BeatCharacter, withoutReload:Bool)
	
	var editorDelegate:BeatEditorDelegate? { get }
}

/// Character editor view controller
@objc class BeatCharacterEditorView:NSViewController, NSTextViewDelegate, NSControlTextEditingDelegate {
	@objc weak var manager:BeatCharacterEditorPopoverManager?
	
	@objc @IBOutlet weak var titleView:NSTextField?
	
	@objc @IBOutlet weak var biography:NSTextView?
	@objc @IBOutlet weak var age:NSTextField?
	
	@objc @IBOutlet weak var genderUnspecified:NSButton?
	@objc @IBOutlet weak var genderWoman:NSButton?
	@objc @IBOutlet weak var genderMan:NSButton?
	@objc @IBOutlet weak var genderOther:NSButton?
	
	@objc var changed = false
	
	/// Character reference: When set, object values are loaded into the view.
	@objc weak var character:BeatCharacter? {
		didSet {
			guard let character = self.character else { return }
			
			self.biography?.text = character.bio
			self.age?.stringValue = character.age
			
			genderUnspecified?.state = (character.gender == "" || character.gender == "unspecified") ? .on : .off
			genderWoman?.state = (character.gender == "woman") ? .on : .off
			genderMan?.state = (character.gender == "man") ? .on : .off
			genderOther?.state = (character.gender == "other") ? .on : .off
			
			let info:NSMutableAttributedString = NSMutableAttributedString(string: "")
			
			let title = NSAttributedString(string: character.name + "\n", attributes: [ .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize) ])
			
			let linesAndScenes = NSAttributedString(string:
														NSLocalizedString("statistics.lines", comment: "Lines") + ": \(character.lines)\n" +
														NSLocalizedString("statistics.scenes", comment: "Scenes") + ": \(character.scenes.count)",
													attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)])
			
			info.append(title)
			info.append(linesAndScenes)
			
			self.titleView?.attributedStringValue = info
			
			changed = false
		}
	}
	
	init() {
		super.init(nibName: "BeatCharacterEditorView", bundle: Bundle.main)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	@IBAction func setGender(_ sender:BeatGenderRadioButton?) {
		guard let character = self.character else { return }
		character.gender = sender?.gender ?? ""
		manager?.listDelegate?.saveCharacter(character, withoutReload: false)
		
		changed = true
	}
	
	func textDidChange(_ notification: Notification) {
		character?.age = age?.stringValue ?? ""
		changed = true
	}
	func controlTextDidChange(_ obj: Notification) {
		character?.bio = biography?.text ?? ""
		changed = true
	}
	
	@IBAction @objc func nextLine(_ sender:Any?) {
		self.manager?.nextLine()
	}
	@IBAction @objc func prevLine(_ sender:Any?) {
		self.manager?.prevLine()
	}
}

@objc class BeatCharacterEditorPopoverManager:NSObject, NSPopoverDelegate {
	@objc let popover: NSPopover
	
	weak var delegate:BeatEditorDelegate?
	weak var listDelegate: BeatCharacterListDelegate?
	weak var editorView:BeatCharacterEditorView?
	var character:BeatCharacter
	
	@objc init(editorDelegate:BeatEditorDelegate, listView:BeatCharacterListDelegate, character:BeatCharacter) {
		self.character = character
		self.popover = NSPopover()
		
		self.delegate = editorDelegate
		self.listDelegate = listView
		
		super.init()
		
		configurePopover()
	}
	
	private func configurePopover() {
		let vc = BeatCharacterEditorView()
		vc.loadView()
		
		popover.contentViewController = vc
		popover.behavior = .semitransient
		popover.delegate = self

		vc.character = self.character
		vc.manager = self
		
		self.editorView = vc
	}
	

	@objc func prevLine() {
		guard let lines = delegate?.parser.lines as? [Line],
			  let currentLine = delegate?.currentLine(),
			  let idx = lines.firstIndex(of: currentLine)
		else { return }

		for i in stride(from: idx-1, to: 0, by: -1) {
			let line = lines[i]
			if !line.isAnyCharacter() { continue }
			
			if line.characterName() == character.name {
				self.delegate?.scroll(to: line)
				break
			}
		}
	}
	
	@objc func nextLine() {
		guard let lines = delegate?.parser.lines as? [Line],
			  let currentLine = delegate?.currentLine(),
			  let idx = lines.firstIndex(of: currentLine)
		else { return }

		for i in (idx+1)..<lines.count {
			let line = lines[i]
			if !line.isAnyCharacter() { continue }
			
			if line.characterName() == character.name {
				self.delegate?.scroll(to: line)
				break
			}
		}
	}
	
	func popoverWillClose(_ notification: Notification) {
		// Store values if needed
		guard let editorView = self.editorView else {
			return
		}

		// Only save the character info if the
		if (editorView.changed) {
			self.listDelegate?.saveCharacter(self.character, withoutReload: true)
		}
	}
}

class BeatGenderRadioButton:NSButton {
	@IBInspectable var gender:String = ""
	init(frame frameRect: NSRect, gender:String) {
		self.gender = gender
		super.init(frame: frameRect)
		
		self.setButtonType(.radio)
		self.title = NSLocalizedString("gender." + self.gender, comment: "")
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		
		self.title = NSLocalizedString("gender." + self.gender, comment: "")
	}
	
}
