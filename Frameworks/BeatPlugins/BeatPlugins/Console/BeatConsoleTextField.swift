//
//  BeatConsoleTextField.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 13.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

public class BeatConsoleTextField: NSTextField {
	private var commandHistory: [String] = []
	private var commandIndex = -1
	
	private var syntaxHighlighter = JSSyntaxHighlighter()

	override public func performKeyEquivalent(with event: NSEvent) -> Bool {
		switch event.keyCode {
		case 125: // Down arrow
			showNextCommand()
			return true
		case 126: // Up arrow
			showPreviousCommand()
			return true
		default:
			return super.performKeyEquivalent(with: event)
		}
	}

	private func showNextCommand() {
		// Sorry for this code, I can't bother to clean it up
		if (commandIndex == -1) { return }
		
		if commandIndex >= 0 { commandIndex -= 1 }
		
		if commandIndex >= 0 {
			stringValue = commandHistory[commandIndex]
			self.syntaxHighlighter.colorize(self.currentEditor() as! NSTextView)
		} else {
			stringValue = ""
		}
	}

	private func showPreviousCommand() {
		if commandIndex < commandHistory.count - 1 {
			commandIndex += 1
			stringValue = commandHistory[commandIndex]
			self.syntaxHighlighter.colorize(self.currentEditor() as! NSTextView)
		}
	}
	
	override public func sendAction(_ action: Selector?, to target: Any?) -> Bool {
		let command = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let result = super.sendAction(action, to: target)
		if result {
			if !command.isEmpty {
				addToCommandHistory(command)
			}
		}
		
		commandIndex = -1
		return result
	}
	override public func textDidChange(_ notification: Notification) {
		// Highlight
		self.syntaxHighlighter.colorize(self.currentEditor() as! NSTextView)
		
		super.textDidChange(notification)
	}
	
	private func addToCommandHistory(_ command: String) {
		commandHistory.insert(command, at: 0)
	}
}

class JSSyntaxHighlighter {
	
	struct color {
		static let normal     = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)] // light grey
		static let beat       = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 1.0)] // blue
		static let ruleName   = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.40, green: 0.60, blue: 0.90, alpha: 1.0)] // cyan
		static let number     = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.60, green: 0.60, blue: 0.90, alpha: 1.0)] // blue
		static let arguments  = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.75, green: 0.20, blue: 0.75, alpha: 1.0)] // magenta
		static let expression = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.95, green: 0.75, blue: 0.10, alpha: 1.0)] // yellow
		static let string     = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.95, green: 0.50, blue: 0.20, alpha: 1.0)] // orange
		static let property   = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.30, green: 0.75, blue: 0.50, alpha: 1.0)] // greenish
		static let comment    = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0)] // gray
		static let keyword    = [NSAttributedString.Key.foregroundColor: NSColor(red: 0.90, green: 0.40, blue: 0.80, alpha: 1.0)]
	}
	
	struct regex {
		static let beat 	     = "(Beat)"
		static let keywords	     = "(var|const|let|function|for|while|do|try|catch|await|sync|class)"
		static let arguments     = "\\(|)\\)"
		static let expression 	 = "(\\#[a-zA-Z][a-zA-Z0-9,\\.\\(\\)]*\\#)"
		static let numberLiteral = "\\b([0-9]*(\\.[0-9]*)?)\\b"
		static let commentLine   = "(^//.*)"
		static let stringLiteral = "(\"([^\"]*)\")"
		static let property 	 = "(?<=\\.)([a-z][^\\s|\\(\\.|\\[]*)"
	}
	
	let patterns = [
		regex.commentLine   : color.comment,
		regex.keywords      : color.keyword,
		regex.numberLiteral : color.number,
		regex.arguments     : color.arguments,
		regex.expression	: color.expression,
		regex.beat			: color.beat,
		//regex.symbols       : color.ruleName,
		regex.stringLiteral : color.string,
		regex.property      : color.property,
	]
	
	init() {
	}
	
	// Colorize all
	func colorize(_ textView: NSTextView) {
		if textView.string.count == 0 { return }
		
		let all = textView.string
		let range = NSString(string: textView.string).range(of: all)
		colorize(textView, range: range)
	}
	
	// Colorize range
	func colorize(_ textView: NSTextView, range: NSRange) {
		var extended = NSUnionRange(range, NSString(string: textView.string).lineRange(for: NSMakeRange(range.location, 0)))
		extended = NSUnionRange(range, NSString(string: textView.string).lineRange(for: NSMakeRange(NSMaxRange(range), 0)))
		
		for (pattern, attribute) in patterns {
			applyStyles(textView.textStorage!, range: extended, pattern: pattern, attribute: attribute)
		}
	}
	
	func applyStyles(_ attributedString: NSMutableAttributedString, range: NSRange, pattern: String, attribute: [NSAttributedString.Key: Any]) {
		let regex = try? NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.anchorsMatchLines])
		regex?.enumerateMatches(in: attributedString.string, options: [], range: range) {
			match, flags, stop in
			
			let matchRange = match?.range(at: 1)
			attributedString.addAttributes(attribute, range: matchRange!)
		}
	}
}
