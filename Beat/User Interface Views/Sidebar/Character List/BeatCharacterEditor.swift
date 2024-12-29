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
	var editorDelegate:BeatEditorDelegate? { get }	
	//var characterData:BeatCharacterData { get }
	
	func editorDidClose(for character:BeatCharacter)
	func reloadView()
}


// MARK: - Character editor view controller

/// Character editor view controller
@objc class BeatCharacterEditorView:NSViewController, NSTextViewDelegate, NSControlTextEditingDelegate {
	@objc weak var manager:BeatCharacterEditorPopoverManager?
	
	@objc @IBOutlet weak var titleView:NSTextField?
	
	@objc @IBOutlet weak var biography:NSTextView?
	@objc @IBOutlet weak var age:NSTextField?
	
	@objc @IBOutlet weak var aliasButton:NSButton?
	@objc @IBOutlet var aliasMenu:NSMenu?
	
	@objc @IBOutlet weak var genderUnspecified:NSButton?
	@objc @IBOutlet weak var genderWoman:NSButton?
	@objc @IBOutlet weak var genderMan:NSButton?
	@objc @IBOutlet weak var genderOther:NSButton?
	
	@objc var allNames:[String] = []
	
	@objc var changed = false
	@objc var changesRequireReload = false
	
	/// Character reference: When set, object values are loaded into the view.
	@objc weak var character:BeatCharacter? {
		didSet {
			guard let character = self.character else { return }
			
			self.biography?.text = character.bio
			self.biography?.textColor = .textColor
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
		
		manager?.saveCharacter(character, reloadView: true)
		changed = true
	}
	
	func textDidChange(_ notification: Notification) {
		character?.bio = biography?.text ?? ""
		changed = true
	}
	
	func controlTextDidChange(_ obj: Notification) {
		character?.age = age?.stringValue ?? ""
		changed = true
	}
	
	@IBAction @objc func nextLine(_ sender:Any?) {
		self.manager?.nextLine()
	}
	
	@IBAction @objc func prevLine(_ sender:Any?) {
		self.manager?.prevLine()
	}
	
	// MARK: Alias menus
	
	@objc func createAliasMenu() -> NSMenu? {
		guard let character else { print("No character"); return nil }
		
		// Populate alias list
		if let characterData = manager?.characterData {
			var names = characterData.charactersAndLines()
			
			// Remove this character's name
			names.removeValue(forKey: character.name)
			
			aliasMenu = NSMenu()
			
			// First, add existing aliases
			for alias in character.aliases {
				let aliasItem = NSMenuItem(title: alias, action: #selector(selectAlias), keyEquivalent: "")
				aliasItem.state = .on
				aliasMenu?.addItem(aliasItem)
			}
			
			// Then, all others in alphabetical order
			for name in names.keys.sorted() {
				let aliasItem = NSMenuItem(title: name, action: #selector(selectAlias), keyEquivalent: "")
				aliasMenu?.addItem(aliasItem)
			}
		}
		
		return aliasMenu
	}
	
	@objc func selectAlias(_ sender:NSMenuItem) {
		guard let character = self.character else { return }
		
		let name = sender.title
		
		// If the alias exists, remove it, otherwise add it
		if character.aliases.contains(name) {
			character.aliases.removeObject(object: name)
		} else {
			character.aliases.append(name)
		}
		
		manager?.saveCharacter(character, reloadView: true)
		self.changed = true
	}
	
	@IBAction func openAliasMenu(_ sender:NSButton?) {
		guard let sender else { return }
		let location = NSPoint(x: 0, y: sender.frame.height + 5)
		
		self.aliasMenu = createAliasMenu()
		self.aliasMenu?.popUp(positioning: nil, at: location, in: sender)
	}
	
}


// MARK: - Popover manager

@objc class BeatCharacterEditorPopoverManager:NSObject, NSPopoverDelegate {
	@objc let popover: NSPopover
	
	weak var delegate:BeatEditorDelegate?
	weak var listDelegate: BeatCharacterListDelegate?
	weak var editorView:BeatCharacterEditorView?
	var character:BeatCharacter
	var characterData:BeatCharacterData
		
	@objc init(editorDelegate:BeatEditorDelegate, listView:BeatCharacterListDelegate, character:BeatCharacter, characterData:BeatCharacterData) {
		self.character = character
		self.characterData = characterData
		
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
		if #available(macOS 10.14, *) {
			popover.appearance = NSAppearance(named: .darkAqua)
		}
				
		vc.manager = self
		vc.character = self.character
		
		self.editorView = vc
	}
	
	func saveCharacter(_ character:BeatCharacter, reloadView:Bool = false) {
		guard let delegate = self.listDelegate?.editorDelegate else {
			print("No delegate")
			return
		}
		
		let data = BeatCharacterData(delegate: delegate)
		data.saveCharacter(character)
		
		if reloadView {
			self.listDelegate?.reloadView()
		}
	}
	

	@objc func prevLine() {
		guard let lines = delegate?.parser.lines as? [Line],
			  let currentLine = delegate?.currentLine,
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
			  let currentLine = delegate?.currentLine,
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

		// Only save the character info if it was changed
		if (editorView.changed) {
			saveCharacter(self.character)
		}
		
		self.listDelegate?.editorDidClose(for: self.character)
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
