//
//  BeatTextView+TabBehavior.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 27.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

public extension BeatTextView {
	@objc func handleTabPress() {
		guard let editorDelegate,
			  let currentLine = editorDelegate.currentLine
		else { return }
		
			
		if currentLine.isAnyCharacter() && currentLine.string.count > 0 {
			if self.text.position(insideParentheticals: self.selectedRange.lowerBound) {
				editorDelegate.textActions.moveToNextDialogueLineOrAddNew()
			} else {
				editorDelegate.formattingActions.addOrEditCharacterExtension()
			}
		} else if currentLine.isAnyDialogue() && currentLine.string.count == 0 {
			editorDelegate.textActions.add("()", at: UInt(currentLine.position))
			self.selectedRange = NSRange(location: currentLine.position + 1, length: 0)
		} else {
			self.forceCharacterInput()
		}
	}
	
	@objc func forceCharacterInput() {
		guard let editorDelegate, !editorDelegate.characterInput else { return }
		
		editorDelegate.formattingActions.addCue()
	}
}
