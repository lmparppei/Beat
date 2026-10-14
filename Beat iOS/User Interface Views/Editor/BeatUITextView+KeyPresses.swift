//
//  BeatUITextView+KeyPresses.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

extension BeatUITextView {
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }
		
		// First check possible assistant view status and move highlight if needed
		// Normal tab presses are caught later
		if let assistantView, assistantView.numberOfSuggestions > 0,
		   key.modifierFlags.rawValue == 0 || key.modifierFlags == .shift {
			var preventSuper = false
			
			if key.keyCode == .keyboardTab && key.modifierFlags == .shift {
				assistantView.highlightPreviousSuggestion()
				preventSuper = true
			} else if key.keyCode == .keyboardTab {
				assistantView.highlightNextSuggestion()
				preventSuper = true
			} else if assistantView.highlightedSuggestion >= 0, key.keyCode == .keyboardReturnOrEnter {
				// Select the highlighted item
				assistantView.selectHighlightedItem()
				preventSuper = true
			} else if assistantView.highlightedSuggestion >= 0, key.keyCode == .keyboardEscape  {
				// De-select highlights
				assistantView.deselectHighlightedItem()
				preventSuper = true
			}
			
			if preventSuper { return }
		}
		
		if key.keyCode == .keyboardTab {
			handleTabPress()
			return
		}
		
		if key.keyCode == .keyboardReturnOrEnter, key.modifierFlags == .shift {
			self.modifierFlags = key.modifierFlags
		} else if key.keyCode == .keyboardDeleteOrBackspace, self.shouldCancelCharacterInput() {
			// Check if we should cancel character input
			self.cancelCharacterInput()
			return
		}
		
		super.pressesBegan(presses, with: event)
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		// Reset modifier flags first
		self.modifierFlags = []
		
		guard let key = presses.first?.key else { return }

		switch key.keyCode {
		case .keyboardTab:
			return
			
		default:
			super.pressesEnded(presses, with: event)
		}
	}
	
	func handleTabPress() {
		guard let line = self.editorDelegate?.currentLine else { return }
					
		if line.isAnyCharacter(), line.length > 0 {
			self.editorDelegate?.formattingActions.addOrEditCharacterExtension()
		} else if line.isAnyDialogue() && line.length == 0 {
			self.editorDelegate?.textActions.add("()", at: UInt(line.position), skipAutomaticLineBreaks: true)
			self.selectedRange = NSMakeRange(line.position+1, 0)
		} else {
			forceCharacterInput()
		}
	}
	
	func forceCharacterInput() {
		if self.editorDelegate?.lineForNewCue != nil { return }
		self.editorDelegate?.formattingActions.addCue()
	}
	
}
