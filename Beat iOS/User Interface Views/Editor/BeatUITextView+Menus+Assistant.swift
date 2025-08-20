//
//  BeatUITextView+InputAssistant.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 20.6.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatUITextView: InputAssistantViewDelegate {
	
	func inputAssistantView(_ inputAssistantView: InputAssistantView, didSelectSuggestion suggestion: String) {
		guard let editorDelegate = self.editorDelegate, suggestion.count > 0 else { return }
		
		let originalPosition = editorDelegate.selectedRange.location
		
		if suggestion[0] == "(" && editorDelegate.currentLine.isAnyCharacter() {
			// This is a character extension
			editorDelegate.textActions.addCueExtension(suggestion, on: editorDelegate.currentLine)
		} else {
			// This is something else
			let r = NSMakeRange(editorDelegate.currentLine.position, editorDelegate.currentLine.length)
			editorDelegate.textActions.replace(r, with: suggestion)
		}
		
		// Oh well. Because iOS doesn't (always) parse the changes when getting here, we need to do some silly string index magic to get the position and then move at the end of the line
		let nextLineBreak = editorDelegate.text().rawIndexOfNextLineBreak(from: originalPosition)
		if nextLineBreak != NSNotFound {
			editorDelegate.selectedRange = NSRange(location: nextLineBreak, length: 0)
		}	
	}
	
	func shouldShowSuggestions() -> Bool {
		return inputAssistantMode == .writing
	}
	
	
	// MARK: - Update assisting views
	
	@objc func updateAssistingViews () {
		guard let currentLine = self.editorDelegate?.currentLine
		else { return }
		
		if (currentLine.isAnyParenthetical()) {
			self.autocapitalizationType = .none
		} else {
			self.autocapitalizationType = .sentences
		}
		
		assistantView?.reloadData()
	}
}


// MARK: - Input assistant buttons

extension BeatUITextView {	
	func setupInputAssistantButtons() {
				
		self.inputAssistantButtons = [
			.writing: [
				InputAssistantAction(image: UIImage(systemName: "arrow.backward"), target: self, action: #selector(moveLeft)),
				InputAssistantAction(image: UIImage(systemName: "arrow.forward"), target: self, action: #selector(moveRight)),
				InputAssistantAction(image: UIImage(systemName: "bubble.left.fill"), target: self, action: #selector(addCue)),
				InputAssistantAction(image: UIImage(named: "Shortcut.INT"), target: self, action: #selector(addINT)),
				InputAssistantAction(image: UIImage(named: "Shortcut.EXT"), target: self, action: #selector(addEXT))
			],
			.editing: [
				InputAssistantAction(image: UIImage(systemName: "arrow.backward"), target: self, action: #selector(moveLeft)),
				InputAssistantAction(image: UIImage(systemName: "arrow.forward"), target: self, action: #selector(moveRight)),
				InputAssistantAction(image: UIImage(systemName: "arrow.up"), target: self, action: #selector(moveUp)),
				InputAssistantAction(image: UIImage(systemName: "arrow.down"), target: self, action: #selector(moveDown)),
				InputAssistantAction(image: UIImage(systemName: "delete.left"), target: self, action: #selector(deleteWordBackward)),
				InputAssistantAction(image: UIImage(systemName: "delete.forward"), target: self, action: #selector(deleteWordForward)),
				InputAssistantAction(image: UIImage(systemName: "minus.rectangle"), target: self, action: #selector(deleteLine)),
			]
		]
		
		let inputAssistantTrailingButtons:[BeatInputAssistantMode:[InputAssistantAction]] = [
			.writing: [
				inputMenu(),
				InputAssistantAction(image: UIImage(systemName: "arrow.uturn.backward")!, target: self, action: #selector(undo)),
				InputAssistantAction(image: UIImage(systemName: "arrow.uturn.forward")!, target: self, action: #selector(redo))
			],
			.editing: [
				InputAssistantAction(image: UIImage(systemName: "arrow.uturn.backward")!, target: self, action: #selector(undo)),
				InputAssistantAction(image: UIImage(systemName: "arrow.uturn.forward")!, target: self, action: #selector(redo))
			]
		]
		
		// First add the mode selector
		var leadingActions = [InputAssistantAction(image: UIImage(systemName: "chevron.up.chevron.down")!, menu: UIMenu(title: "Toolbar", children: [ UIDeferredMenuElement.uncached { [weak self] completion in
				let items = [
					UIAction(title:"Editing", state: self?.inputAssistantMode == .editing ? .on : .off, handler: { b in self?.inputAssistantMode = .editing }),
					UIAction(title:"Writing", state: self?.inputAssistantMode == .writing ? .on : .off, handler: { b in self?.inputAssistantMode = .writing })
				]
				completion(items)
			}]))
		]
		
		// Then add buttons by assistant mode
		if let actions = self.inputAssistantButtons[self.inputAssistantMode] {
			leadingActions.append(contentsOf: actions)
		}
		
		self.assistantView?.leadingActions = leadingActions
		
		self.assistantView?.trailingActions = inputAssistantTrailingButtons[inputAssistantMode] ?? []
	}
	
	func inputMenu() -> InputAssistantAction {
		return InputAssistantAction(image: UIImage(systemName: "filemenu.and.selection")!, menu: UIMenu(title: "", children: [
			UIMenu(title:"", options:[.displayInline], children: [
				UIAction(title: "Find & Replace…", handler: { _ in
					self.findAndReplace(nil)
				}),
				UIAction(title: "Find…", handler: { _ in
					self.find(nil)
				})
			]),
			
			UIMenu(title:"Macros", children: [
				UIAction(title: "New Macro", handler: { _ in
					self.editorDelegate?.formattingActions.makeMacro(self)
				}),
				UIAction(title: "Panel", subtitle: "Auto-incrementing number, resets at top-level sections", handler: { _ in
					self.editorDelegate?.textActions.add("{{ panel }}", at: UInt(self.selectedRange.location))
				}),
				UIAction(title: "Date", subtitle: "Automatic date", handler: { _ in
					self.editorDelegate?.textActions.add("{{ date YYYY-MM-dd }}", at: UInt(self.selectedRange.location))
				}),
				UIAction(title: "Define Text Macro", subtitle: "Definition for any text", handler: { _ in
					self.editorDelegate?.textActions.add("{{ name = value }}", at: UInt(self.selectedRange.location))
				}),
				UIAction(title: "Define Serial Number", subtitle: "Auto-incrementing number", handler: { _ in
					self.editorDelegate?.textActions.add("{{ serial name = 1 }}", at: UInt(self.selectedRange.location))
				}),
			].reversed()),
			
			UIMenu(title:"Markers", children: [
				UIMenu(title: "Marker With Color...", children: [
					UIAction(title: "Pink", image: UIImage(named: "color.pink"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker pink:New marker]]", caretPosition: -2)
					}),
					UIAction(title: "Orange", image: UIImage(named: "color.orange"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker orange:New marker]]", caretPosition: -2)
					}),
					UIAction(title: "Purple", image: UIImage(named: "color.purple"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker purple:New marker]]", caretPosition: -2)
					}),
					UIAction(title: "Blue", image: UIImage(named: "color.blue"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker blue:New marker]]", caretPosition: -2)
					}),
					UIAction(title: "Green", image: UIImage(named: "color.green"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker green:New marker]]", caretPosition: -2)
					}),
					UIAction(title: "Red", image: UIImage(named: "color.red"),  handler: { (_) in
						self.editorDelegate?.textActions.addNewParagraph("[[marker red:New marker]]", caretPosition: -2)
					}),
				]),
				UIAction(title: "Add Marker", handler: { (_) in
					self.editorDelegate?.textActions.addNewParagraph("[[marker New marker]]", caretPosition: -2)
				}),
			]),
			
			UIMenu(title: "Outline Elements", children: [
				UIAction(title: "Add Synopsis (=)", handler: { _ in
					self.addSynopsis()
				}),
				UIAction(title: "Add Section (#)", image: UIImage(named: "Shortcut.Synopsis"), handler: { _ in
					self.addSection()
				})
			]),
			
			UIMenu(title: "Transitions", children: [
				UIAction(title: "FADE IN", handler: { (_) in
					self.editorDelegate?.textActions.addNewParagraph("> FADE IN")
				}),
				UIAction(title: "CUT TO:", handler: { (_) in
					self.editorDelegate?.textActions.addNewParagraph("CUT TO:")
				}),
				UIAction(title: "DISSOLVE TO:", handler: { (_) in
					self.editorDelegate?.textActions.addNewParagraph("DISSOLVE TO:")
				}),
				UIAction(title: "FADE OUT", handler: { (_) in
					self.editorDelegate?.textActions.addNewParagraph("> FADE OUT")
				}),
				
			]),
			
			UIMenu(title: "", options: [.displayInline], children: [
				UIAction(title: "Make Centered", handler: { (_) in
					self.editorDelegate?.formattingActions.makeCentered(self)
				}),
				UIAction(title: "Omit", handler: { (_) in
					self.editorDelegate?.formattingActions.makeOmitted(self)
				}),
				UIAction(title: "Note", handler: { (_) in
					self.editorDelegate?.formattingActions.makeNote(self)
				})
			]),
			
			UIMenu(title:"Force element", children: [
				UIAction(title: "Scene heading", handler: { (_) in
					self.editorDelegate?.formattingActions.forceHeading(self)
				}),
				UIAction(title: "Action", handler: { (_) in
					self.editorDelegate?.formattingActions.forceAction(self)
				}),
				UIAction(title: "Character", handler: { (_) in
					self.editorDelegate?.formattingActions.forceCharacter(self)
				}),
				UIAction(title: "Transition", handler: { (_) in
					self.editorDelegate?.formattingActions.forceTransition(self)
				}),
				UIAction(title: "Lyrics", handler: { (_) in
					self.editorDelegate?.formattingActions.forceLyrics(self)
				}),
			]),
			
			UIMenu(title:"", options: [.displayInline], preferredElementSize: .small, children: [
				UIAction(image: UIImage(systemName: "bold"), handler: { (_) in
					self.editorDelegate?.formattingActions.makeBold(self)
				}),
				UIAction(image: UIImage(systemName: "italic"), handler: { (_) in
					self.editorDelegate?.formattingActions.makeItalic(self)
				}),
				UIAction(image: UIImage(systemName: "underline"), handler: { (_) in
					self.editorDelegate?.formattingActions.makeUnderlined(nil)
				})
			])
		]))
	}
	
	@objc func addINT() {
		self.editorDelegate?.textActions.addNewParagraph("INT. ")
	}
	
	@objc func addSection() {
		self.editorDelegate?.textActions.addNewParagraph("# ")
	}
	
	@objc func addSynopsis() {
		self.editorDelegate?.textActions.addNewParagraph("= ")
	}
	
	@objc func addEXT() {
		self.editorDelegate?.textActions.addNewParagraph("EXT. ")
	}
	
	@objc func addCue() {
		self.editorDelegate?.formattingActions.addCue()
		self.updateAssistingViews()
	}
	
	@objc func undo() {
		self.editorDelegate?.undoManager.undo()
		self.scrollRangeToVisible(self.selectedRange)
	}
	
	@objc func redo() {
		self.editorDelegate?.undoManager.redo()
		self.scrollRangeToVisible(self.selectedRange)
	}
	
	@objc func moveLeft() {
		guard let text = self.text, let selectedRange = self.selectedTextRange else { return }
		
		let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
		if cursorOffset == 0 { return }
		
		// Find the last space or the start of the string
		let textBeforeCaret = text.prefix(cursorOffset)
		if let lastWordStartIndex = textBeforeCaret.lastIndex(where: { $0.isWhitespace || $0.isNewline }) {
			let newOffset = textBeforeCaret.distance(from: textBeforeCaret.startIndex, to: lastWordStartIndex)
			setCaretPosition(offset: newOffset)
		} else {
			// Move to the start if no space was found
			setCaretPosition(offset: 0)
		}
	}
	
	@objc func moveRight() {
		guard let text = self.text, let selectedRange = self.selectedTextRange else { return }
		
		let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
		if cursorOffset == text.count { return }
		
		// Find the last space or the start of the string
		let startIndex = text.index(text.startIndex, offsetBy: cursorOffset)
		
		let textAfterCaret = text.suffix(from: startIndex)
		
		if let lastWordStartIndex = textAfterCaret.firstIndex(where: { $0.isWhitespace || ($0.isNewline) }) {
			let chr = text[lastWordStartIndex]
			let offsetBy = (chr == "\n" && textAfterCaret.first != "\n") ? 0 : 1
			
			let newIndex = text.index(lastWordStartIndex, offsetBy: offsetBy)
			let newOffset = text.distance(from: text.startIndex, to: newIndex)
			setCaretPosition(offset: newOffset)
		} else {
			// Move to the start if no space was found
			setCaretPosition(offset: 0)
		}
	}
	
	@objc func moveUp() {
		guard let line = editorDelegate?.currentLine, let parser = editorDelegate?.parser else { return }
		
		if let prevLine = parser.previousLine(line) {
			self.selectedRange = NSMakeRange(NSMaxRange(prevLine.textRange()), 0)
		}
	}
	
	@objc func moveDown() {
		guard let line = editorDelegate?.currentLine, let parser = editorDelegate?.parser else { return }
		
		if let prevLine = parser.nextLine(line) {
			self.selectedRange = NSMakeRange(NSMaxRange(prevLine.textRange()), 0)
		}
	}
	
	private func setCaretPosition(offset: Int) {
		if let newPosition = position(from: beginningOfDocument, offset: offset) {
			self.selectedTextRange = textRange(from: newPosition, to: newPosition)
		}
	}
	
	@objc func deleteWordBackward() {
		guard let text = self.text, let selectedRange = self.selectedTextRange else { return }
		
		// Get current caret position
		let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
		if cursorOffset == 0 { return }
		
		let textBeforeCaret = text.prefix(cursorOffset)
		
		let currentChr = textBeforeCaret.endIndex < text.endIndex ? text[textBeforeCaret.endIndex] : nil
		let lastCharIndex = text.index(textBeforeCaret.endIndex, offsetBy: -1)
		let prevChr = text[lastCharIndex]
		
		var start: UITextPosition?
		var end: UITextPosition?
		
		if textBeforeCaret.last?.isNewline ?? false {
			// Delete newline character
			start = position(from: selectedRange.start, offset: -1)
			end = position(from: beginningOfDocument, offset: cursorOffset)
		} else if !prevChr.isWhitespace, !(currentChr?.isWhitespace ?? true) {
			// Find full word range
			if let wordRange = findWordRangeAroundCaret(cursorOffset: cursorOffset) {
				start = position(from: beginningOfDocument, offset: wordRange.lowerBound)
				if let start { end = position(from: start, offset: wordRange.count) }
			}
		} else if let nextWordIndex = textBeforeCaret.lastIndex(where: { !($0.isWhitespace && $0.isNewline) }) {
			// First find the last non-whitespace component
			let boundaryOffset = textBeforeCaret.distance(from: textBeforeCaret.startIndex, to: nextWordIndex)
			end = position(from: beginningOfDocument, offset: boundaryOffset + 1) // `+1` to include the non-whitespace character
			
			let prefix = text.prefix(boundaryOffset)
			
			// Then find the first whitespace after that
			if let wordStartIndex = prefix.lastIndex(where: { $0.isWhitespace || $0.isNewline }) {
				let wordStartOffset = textBeforeCaret.distance(from: textBeforeCaret.startIndex, to: wordStartIndex)
				start = position(from: beginningOfDocument, offset: wordStartOffset + 1) // `+1` to move past the whitespace
			} else {
				// No whitespace found, delete everything up to the start of the text
				start = beginningOfDocument
			}
		}

		if let start, let end, let range = textRange(from: start, to: end) {
			replace(range, withText: "")
			// Remove redundant spaces after deletion
			cleanUpExtraSpaces(at: start)
		}
	}
	
	@objc func deleteWordForward() {
		guard let text = self.text, let selectedRange = self.selectedTextRange else { return }
		
		// Get current caret position
		let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
		if cursorOffset >= text.count { return } // At the end of the text, nothing to delete
		
		let textAfterCaret = text.suffix(text.count - cursorOffset)
		
		let currentChr = text[text.index(text.startIndex, offsetBy: cursorOffset)]
		let nextChr = cursorOffset + 1 < text.count ? text[text.index(text.startIndex, offsetBy: cursorOffset + 1)] : nil
		
		var start: UITextPosition?
		var end: UITextPosition?
		
		if currentChr.isNewline {
			// Delete newline character
			start = position(from: beginningOfDocument, offset: cursorOffset)
			end = position(from: start!, offset: 1)
		} else if !currentChr.isWhitespace, nextChr?.isWhitespace == false {
			// Find full word range
			if let wordRange = findWordRangeAroundCaret(cursorOffset: cursorOffset) {
				start = position(from: beginningOfDocument, offset: wordRange.lowerBound)
				end = position(from: start!, offset: wordRange.count)
			}
		} else if let nextWordIndex = textAfterCaret.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) {
			// First find the first non-whitespace component
			let boundaryOffset = text.distance(from: text.startIndex, to: nextWordIndex)
			start = position(from: beginningOfDocument, offset: cursorOffset) // Start at the caret
			
			// Then find the first whitespace or newline after that
			let suffix = textAfterCaret.suffix(text.count - boundaryOffset)
			if let wordEndIndex = suffix.firstIndex(where: { $0.isWhitespace || $0.isNewline }) {
				let wordEndOffset = text.distance(from: text.startIndex, to: wordEndIndex)
				end = position(from: beginningOfDocument, offset: wordEndOffset)
			} else {
				// No whitespace or newline found, delete everything to the end of the text
				end = position(from: beginningOfDocument, offset: text.count)
			}
		}
		
		if let start, let end, let range = textRange(from: start, to: end) {
			replace(range, withText: "")
			// Remove redundant spaces after deletion
			cleanUpExtraSpaces(at: start)
		}
	}

	/// Finds the range of the word around the caret position.
	private func findWordRangeAroundCaret(cursorOffset: Int) -> Range<Int>? {
		// Find boundaries for the word around the caret
		let textBeforeCaret = text.prefix(cursorOffset)
		let textAfterCaret = text.suffix(text.count - cursorOffset)

		// Locate the start of the word
		let wordStart = textBeforeCaret.lastIndex(where: { $0.isWhitespace || $0.isNewline }) ?? text.startIndex
		let wordStartOffset = textBeforeCaret.distance(from: textBeforeCaret.startIndex, to: wordStart)

		// Locate the end of the word
		let wordEnd = textAfterCaret.firstIndex(where: { $0.isWhitespace || $0.isNewline }) ?? text.endIndex
		let wordEndOffset = cursorOffset + textAfterCaret.distance(from: textAfterCaret.startIndex, to: wordEnd)

		// Check if the caret lies within a word
		if wordStartOffset < cursorOffset && cursorOffset < wordEndOffset {
			return wordStartOffset..<wordEndOffset
		}
		return nil
	}

	/// Cleans up redundant spaces after deleting a word.
	private func cleanUpExtraSpaces(at textPosition: UITextPosition) {
		guard let text = self.text else { return }
		let positionOffset = offset(from: beginningOfDocument, to: textPosition)
		
		let textAfterCaret = text.suffix(text.count - positionOffset)
		let textBeforeCaret = text.prefix(positionOffset)
		
		// If there's a space both before and after the caret, remove one
		if textBeforeCaret.last == " " && textAfterCaret.first == " ", let end = self.position(from: textPosition, offset: 1) {
			if let range = textRange(from: textPosition, to: end) {
				replace(range, withText: "")
			}
		}
	}
	
	@objc func deleteLine() {
		guard let editorDelegate, let line = self.editorDelegate?.currentLine else { return }
		var range = line.range()
		if NSMaxRange(range) > editorDelegate.text().count {
			range.length = max(0, editorDelegate.text().count - range.location)
		}
		
		self.editorDelegate?.textActions.replace(range, with: "")

		self.selectedRange.length = 0
		self.selectedRange.location = range.location <= self.text.count ? range.location : self.text.count
	}

}


extension BeatUITextView {

	// MARK: - Menu

	override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
		var originalActions = suggestedActions
		var actions:[UIMenuElement] = []
		
		for m in suggestedActions {
			guard let menu = m as? UIMenu else { continue }
			
			if menu.identifier == .standardEdit ||
				menu.identifier == .replace ||
				menu.identifier == .find
			{
				actions.append(menu)
				originalActions.removeObject(object: menu)
			}
		}
		
		guard let line = editorDelegate?.currentLine else { return UIMenu(children: actions) }
		
		if line.isAnyDialogue() || line.type == .action {
			let formatMenu = UIMenu(image: UIImage(systemName: "bold.italic.underline"), options: [], children: [
				UIAction(image: UIImage(named: "button_bold")) { _ in
					self.editorDelegate?.formattingActions.makeBold(nil)
				},
				UIAction(image: UIImage(named: "button_italic")) { _ in
					self.editorDelegate?.formattingActions.makeItalic(nil)
				},
				UIAction(image: UIImage(systemName: "underline")) { _ in
					self.editorDelegate?.formattingActions.makeUnderlined(nil)
				}
			])
			
			actions.append(formatMenu)
		}
		
		if self.selectedRange.length > 0 {
			let revisionMenu = UIMenu(subtitle: "Revisions", image: UIImage(systemName: "asterisk"), options: [], children: [
				UIAction(title: "Mark As Revised") { _ in
					self.editorDelegate?.revisionTracking.markerAction(.addition)
				},
				UIMenu(options: [.destructive, .displayInline], children: [
					UIAction(title: "Clear Revisions") { _ in
						self.editorDelegate?.revisionTracking.markerAction(.none)
					}
				])
			])
			
			actions.append(revisionMenu)
		}
		
		let textIO = editorDelegate?.textActions
		let sceneMenu = UIMenu(title: "Scene...", options: [], children: [
			UIAction(title: "Omit Scene") { _ in
				self.editorDelegate?.formattingActions.omitScene(nil)
			},
			UIAction(title: "Make Non-Numbered") { _ in
				self.editorDelegate?.formattingActions.makeSceneNonNumbered(nil)
			},
			UIAction(image: UIImage(named:"color.red")) { _ in
				textIO?.setColor("red", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.blue")) { _ in
				textIO?.setColor("blue", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.green")) { _ in
				textIO?.setColor("green", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.pink")) { _ in
				textIO?.setColor("pink", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.brown")) { _ in
				textIO?.setColor("brown", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.cyan")) { _ in
				textIO?.setColor("cyan", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.orange")) { _ in
				textIO?.setColor("orange", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"color.magenta")) { _ in
				textIO?.setColor("magenta", for: self.editorDelegate?.currentScene)
			}
		])
		
		actions.append(sceneMenu)
				
		// Add remaining actions from original menu
		actions.append(contentsOf: originalActions)
		
		let menu = UIMenu(children: actions)
		
		return menu
	}
	
}

