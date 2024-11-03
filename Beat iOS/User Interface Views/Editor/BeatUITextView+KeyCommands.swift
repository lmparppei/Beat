//
//  BeatUITextView+KeyCommands.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 12.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatUITextView {
	override var keyCommands: [UIKeyCommand]? {
		return [
			UIKeyCommand(action: #selector(makeBold), input: "b", modifierFlags: [.command], discoverabilityTitle: "Bold"),
			UIKeyCommand(action: #selector(makeItalic), input: "i", modifierFlags: [.command], discoverabilityTitle: "Italic"),
			UIKeyCommand(action: #selector(makeUnderlined), input: "u", modifierFlags: [.command], discoverabilityTitle: "Underline"),
			UIKeyCommand(action: #selector(makeOmitted), input: "e", modifierFlags: [.command, .shift], discoverabilityTitle: "Omit"),
			UIKeyCommand(action: #selector(addNote), input: "e", modifierFlags: [.command, .alternate], discoverabilityTitle: "Note"),
			UIKeyCommand(action: #selector(addMacro), input: "m", modifierFlags: [.command, .alternate], discoverabilityTitle: "Macro"),
			UIKeyCommand(action: #selector(prevScene), input: UIKeyCommand.inputUpArrow, modifierFlags: [.command, .alternate], discoverabilityTitle: "Previous Scene"),
			UIKeyCommand(action: #selector(nextScene), input: UIKeyCommand.inputDownArrow, modifierFlags: [.command, .alternate], discoverabilityTitle: "Next Scene"),
		]
	}
	
	@objc func makeBold() {
		self.editorDelegate?.formattingActions.makeBold(self)
	}
	
	@objc func makeItalic() {
		self.editorDelegate?.formattingActions.makeItalic(self)
	}
	
	@objc func makeUnderlined() {
		self.editorDelegate?.formattingActions.makeUnderlined(self)
	}
	
	@objc func makeOmitted() {
		self.editorDelegate?.formattingActions.makeOmitted(self)
	}
	
	@objc func nextScene() {
		self.editorDelegate?.nextScene?(self)
	}
	
	@objc func prevScene() {
		self.editorDelegate?.previousScene?(self)
	}
	
	@objc func addMacro() {
		self.editorDelegate?.formattingActions.makeMacro(self)
	}
	
	@objc func addNote() {
		self.editorDelegate?.formattingActions.makeNote(self)
	}
}
