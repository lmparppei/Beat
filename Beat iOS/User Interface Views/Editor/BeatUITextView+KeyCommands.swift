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
			UIKeyCommand(title: "Bold", action: #selector(makeBold), input: "b", modifierFlags: [.command]),
			UIKeyCommand(title: "Italic", action: #selector(makeItalic), input: "i", modifierFlags: [.command]),
			UIKeyCommand(title: "Underline", action: #selector(makeUnderlined), input: "u", modifierFlags: [.command]),
			UIKeyCommand(title: "Omit", action: #selector(makeOmitted), input: "e", modifierFlags: [.command, .shift]),
			UIKeyCommand(title: "Note", action: #selector(addNote), input: "e", modifierFlags: [.command, .alternate]),
			UIKeyCommand(title: "Macro", action: #selector(addMacro), input: "m", modifierFlags: [.command, .alternate]),
			UIKeyCommand(title: "Previous Scene", action: #selector(prevScene), input: UIKeyCommand.inputUpArrow, modifierFlags: [.command, .alternate]),
			UIKeyCommand(title: "Next Scene", action: #selector(nextScene), input: UIKeyCommand.inputDownArrow, modifierFlags: [.command, .alternate]),
			UIKeyCommand(title: "Mark as Revised", action: #selector(markAsRevised), input: "k", modifierFlags: [.command]),
			UIKeyCommand(title: "Clear Revisions", action: #selector(clearRevisions), input: "k", modifierFlags: [.command, .alternate]),
			UIKeyCommand(title: "Add Review", action: #selector(addReview), input: "r", modifierFlags: [.command])
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
	
	@objc func markAsRevised() {
		self.editorDelegate?.revisionTracking.markerAction(.addition)
	}
	
	@objc func clearRevisions() {
		self.editorDelegate?.revisionTracking.markerAction(.none)
	}
	
	@objc func addReview() {
		guard let editorDelegate, editorDelegate.selectedRange.length > 0 else { return }
		
		editorDelegate.review.showReviewIfNeeded(range: editorDelegate.selectedRange, forEditing: true)
	}
}
