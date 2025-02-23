//
//  DiffViewerView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

class DiffViewerViewController: NSViewController {

	weak var delegate:BeatEditorDelegate?
	
	@IBOutlet weak var textView:DiffViewerTextView?
	
	@IBOutlet weak var currentVersionMenu:NSPopUpButton?
	@IBOutlet weak var otherVersionMenu:NSPopUpButton?
	
	var originalText:String?
	var modifiedText:String?
	
	var modifiedTimestamp:String = "current"
	var originalTimestamp:String = "base"
	
	var vc:BeatVersionControl?
	
	@IBAction func close(_ sender:Any?) {
		self.view.window?.close()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		if let delegate {
			self.vc = BeatVersionControl(delegate: delegate)
			populateVersions()
			diffVersions(originalTimestamp: originalTimestamp, modifiedTimestamp: modifiedTimestamp)
			
			setupTextView()
		}
	}
	
	func setupTextView() {
		guard let delegate else { return }
		textView?.setup(editorDelegate: delegate)
	}
	
	/// Function to load and compare two versions of text
	func loadDiff() {
		let dmp = DiffMatchPatch()
		if let diffs = dmp.diff_main(ofOldString: self.originalText, andNewString: self.modifiedText) {
			dmp.diff_cleanupSemantic(diffs)
			
			// We need to convert NSMutableArray manually, no idea why
			var diffValues:[Diff] = []
			for d in diffs {
				if let diff = d as? Diff {
					diffValues.append(diff)
				}
			}
			
			let text = formatDiffedText(diffValues, isOriginal: false)
			self.textView?.textStorage?.setAttributedString(text)
		}
	}

	/// Highlights differences using NSAttributedString
	private func formatDiffedText(_ diffs: [Diff], isOriginal: Bool) -> NSAttributedString {
		let attributedString = NSMutableAttributedString()
		
		let redColor = BeatColors.color("red").withAlphaComponent(0.2)
		let greenColor = BeatColors.color("green").withAlphaComponent(0.2)
		
		let indices:[String:NSMutableIndexSet] = [
			"delete": NSMutableIndexSet(),
			"insert": NSMutableIndexSet()
		]
		
		// Create an attributed string from diffs
		for diff in diffs {
			let text = diff.text ?? ""
			let range = NSMakeRange(attributedString.length, text.count)
					
			switch diff.operation.rawValue {
			case 1: // Delete
				indices["delete"]?.add(in: range)
			case 2: // Insert
				indices["insert"]?.add(in: range)
			default: // Equal
				break
			}

			attributedString.append(NSAttributedString(string: text, attributes: [:]))
		}
		
		// Parse content and load document settings
		let formatting = BeatEditorFormatting(textStorage: attributedString)
		let documentSettings = self.delegate?.documentSettings
		/*
		// For future generations
		let content = attributedString.string
		let documentSettings = BeatDocumentSettings()
		let range = documentSettings.readAndReturnRange(content)
		content = content.substring(range: range)
		 */
		
		formatting.staticParser = ContinuousFountainParser(staticParsingWith: attributedString.string, settings: documentSettings)
		formatting.formatAllLines()
		
		// Apply diff colors
		indices["delete"]?.enumerateRanges(using: { range, stop in
			attributedString.addAttribute(.backgroundColor, value: redColor, range: range)
			attributedString.addAttribute(.strikethroughColor, value: NSColor.red, range: range)
			attributedString.addAttribute(.strikethroughStyle, value: 1, range: range)
		})
		indices["insert"]?.enumerateRanges(using: { range, stop in
			attributedString.addAttribute(.backgroundColor, value: greenColor, range: range)
		})
		
		return attributedString
	}
		
	func populateVersions() {
		guard let vc else { return }
		
		currentVersionMenu?.removeAllItems()
		otherVersionMenu?.removeAllItems()
		
		currentVersionMenu?.addItem(withTitle: "base")
		otherVersionMenu?.addItem(withTitle: "base")
		
		for timestamp in vc.timestamps() {
			currentVersionMenu?.addItem(withTitle: timestamp)
			otherVersionMenu?.addItem(withTitle: timestamp)
		}
		
		currentVersionMenu?.addItem(withTitle: "current")
		otherVersionMenu?.addItem(withTitle: "current")
		
		currentVersionMenu?.selectItem(withTitle: modifiedTimestamp.lowercased())
		otherVersionMenu?.selectItem(withTitle: originalTimestamp.lowercased())
	}
	
	@IBAction func selectVersion(_ sender:NSPopUpButton?) {
		guard let button = sender,
			  let timestamp = button.selectedItem?.title
		else { return }
		
		if sender == currentVersionMenu {
			modifiedTimestamp = timestamp
		} else {
			originalTimestamp = timestamp
		}
		
		diffVersions(originalTimestamp:self.originalTimestamp, modifiedTimestamp:self.modifiedTimestamp)
	}
	
	func diffVersions(originalTimestamp:String, modifiedTimestamp:String) {
		self.originalText = getText(timestamp: originalTimestamp)
		self.modifiedText = getText(timestamp: modifiedTimestamp)
		
		loadDiff()
	}
	
	func getText(timestamp:String) -> String? {
		if timestamp == "current" {
			return self.delegate?.text()
		} else {
			return vc?.text(at: timestamp)
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		self.close(sender)
	}
	
}


class DiffViewerTextView:NSTextView {
	weak var editor:BeatEditorDelegate?
	var magnification = 1.3
	
	override var frame: NSRect {
		didSet {
			if let editor {
				let scrollW = self.enclosingScrollView?.frame.size.width ?? 0.0
				let docW = editor.documentWidth
				
				let width = (scrollW / 2 - docW * magnification / 2) / magnification
				
				self.textContainerInset = CGSizeMake(width, 10.0)
				textContainer?.containerSize = CGSizeMake(editor.documentWidth, .greatestFiniteMagnitude)
			}
		}
	}
	
	func setup(editorDelegate:BeatEditorDelegate) {
		self.editor = editorDelegate
		
		textContainer?.widthTracksTextView = false
		scaleUnitSquare(to: CGSizeMake(magnification, magnification))
		textContainer?.lineFragmentPadding = BeatTextView.linePadding()
		textContainer?.containerSize = CGSizeMake(editorDelegate.documentWidth, .greatestFiniteMagnitude)
	}
}
