//
//  DiffViewerView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

private enum DiffViewMode: Int {
	case compare = 0
	case fullText = 1
}


class DiffViewerViewController: NSViewController {
	
	weak var delegate: BeatEditorDelegate?
	
	private var vc: BeatVersionControl?
	private var viewMode: DiffViewMode = .compare {
		didSet {
			currentVersionMenu?.isHidden = viewMode != .compare
			refreshContent()
		}
	}
	
	private var originalText: String?
	private var modifiedText: String?
	
	private var originalTimestamp: String = "base" {
		didSet {
			otherVersionMenu?.selectCommit(originalTimestamp)
		}
	}
	
	private var modifiedTimestamp: String = "current" {
		didSet {
			currentVersionMenu?.selectCommit(modifiedTimestamp)
		}
	}
	
	// MARK: UI outlets
	
	@IBOutlet private weak var textView: DiffViewerTextView?
	@IBOutlet private weak var currentVersionMenu: DiffTimestampMenu?
	@IBOutlet private weak var otherVersionMenu: DiffTimestampMenu?
	@IBOutlet private weak var statusView: DiffViewerStatusView?
	@IBOutlet private weak var commitButton: NSButton?
	
	// MARK: Lifecycle
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		guard let delegate = delegate else { return }
		
		self.vc = BeatVersionControl(delegate: delegate)
		
		_ = compareToLatestCommit()
		populateVersions()
		setupTextView()
		updateCommitStatus()
	}
	
	// MARK: - Setup
	
	private func setupTextView() {
		guard let delegate = delegate, let textView = textView else { return }

		textView.setup(editorDelegate: delegate)
		textView.backgroundColor = ThemeManager.shared().backgroundColor.effectiveColor()
	}
	
	// MARK: - Version control actions
	
	@IBAction func commit(_ sender: Any?) {
		guard let delegate = delegate else { return }
		
		let vc = BeatVersionControl(delegate: delegate)
		vc.addCommit()
		updateCommitStatus()
	}
	
	private func updateCommitStatus() {
		let uncommitted = vc?.hasUncommittedChanges() ?? false
		
		statusView?.update(uncommitedChanges: uncommitted)
		commitButton?.isEnabled = uncommitted
	}
	
	// MARK: - Version selection
	
	private func populateVersions() {
		guard let vc = vc else { return }
		
		addTimestampMenuItems(menu: currentVersionMenu, versionControl: vc)
		addTimestampMenuItems(menu: otherVersionMenu, versionControl: vc)
		
		currentVersionMenu?.selectCommit(modifiedTimestamp)
		otherVersionMenu?.selectCommit(originalTimestamp)
	}
	
	private func addTimestampMenuItems(menu: DiffTimestampMenu?, versionControl: BeatVersionControl) {
		guard let menu = menu else { return }
		
		menu.removeAllItems()
		
		// Add base item
		let baseItem = DiffTimestampMenuItem(title: formatTimestamp("base"), action: nil, keyEquivalent: "")
		baseItem.timestamp = "base"
		menu.menu?.addItem(baseItem)
		
		// Add versioned items
		for timestamp in versionControl.timestamps() {
			let item = DiffTimestampMenuItem(title: formatTimestamp(timestamp), action: nil, keyEquivalent: "")
			item.timestamp = timestamp
			menu.menu?.addItem(item)
		}
		
		// Add current item
		let currentItem = DiffTimestampMenuItem(title: formatTimestamp("current"), action: nil, keyEquivalent: "")
		currentItem.timestamp = "current"
		menu.menu?.addItem(currentItem)
	}
	
	private func formatTimestamp(_ timestamp: String) -> String {
		// Special timestamps need to be localized
		if timestamp == "base" || timestamp == "current" {
			return BeatLocalization.localizedString(forKey: "versionControl." + timestamp)
		}
		
		// Try to parse the timestamp as a date and format according to user locale
		if let timeInterval = TimeInterval(timestamp) {
			let date = Date(timeIntervalSince1970: timeInterval)
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .short
			dateFormatter.doesRelativeDateFormatting = true
			return dateFormatter.string(from: date)
		}
		
		// Fallback to the original timestamp if parsing fails
		return timestamp
	}
	
	@IBAction func selectVersion(_ sender: NSPopUpButton?) {
		guard let button = sender,
			  let menuItem = button.selectedItem as? DiffTimestampMenuItem,
			  let timestamp = menuItem.timestamp.isEmpty ? button.selectedItem?.title : menuItem.timestamp
		else { return }
		
		if sender == currentVersionMenu {
			modifiedTimestamp = timestamp
		} else {
			originalTimestamp = timestamp
		}
		
		refreshContent()
	}
	
	/// Helper method to quickly select the latest commit at startup
	func compareToLatestCommit() -> Bool {
		guard let vc = vc, let latest = vc.latestTimestamp() else { return false }
		
		modifiedTimestamp = "current"
		originalTimestamp = latest
		loadDiff()
		
		return true
	}
	
	// MARK: - Content Loading
	
	private func refreshContent() {
		// Update both texts
		updateTexts()
		
		if viewMode == .compare {
			loadDiff()
		} else {
			loadText()
		}
	}
	
	private func updateTexts() {
		// Build texts for version controls
		originalText = getText(timestamp: originalTimestamp)
		modifiedText = getText(timestamp: modifiedTimestamp)
	}
	
	private func getText(timestamp: String) -> String? {
		guard let delegate, let vc else {
			print("Error fetching commit text")
			return nil
		}
		
		if timestamp == "current" {
			return delegate.text()
		} else {
			return vc.text(at: timestamp)
		}
	}
	
	func loadDiff() {
		guard let originalText = originalText, let modifiedText = modifiedText else { return }
		
		let dmp = DiffMatchPatch()
		guard let diffs = dmp.diff_main(ofOldString: originalText, andNewString: modifiedText) else { return }
		
		dmp.diff_cleanupSemantic(diffs)
		
		// Convert NSMutableArray to [Diff]
		var diffValues: [Diff] = []
		for d in diffs {
			if let diff = d as? Diff {
				diffValues.append(diff)
			}
		}
		
		let text = formatDiffedText(diffValues, isOriginal: false)
		textView?.textStorage?.setAttributedString(text)
	}
	
	func loadText() {
		guard let text = originalText else { return }
		
		let attributedString = formatFountain(text)
		textView?.textStorage?.setAttributedString(attributedString)
	}
	
	
	// MARK: - Text Formatting
	
	private func formatDiffedText(_ diffs: [Diff], isOriginal: Bool) -> NSAttributedString {
		let string = NSMutableString()
		
		let redColor = BeatColors.color("red").withAlphaComponent(0.2)
		let greenColor = BeatColors.color("green").withAlphaComponent(0.2)
		
		let indices: [String: NSMutableIndexSet] = [
			"delete": NSMutableIndexSet(),
			"insert": NSMutableIndexSet()
		]
		
		// Create an attributed string from diffs
		for diff in diffs {
			let text = diff.text ?? ""
			let range = NSMakeRange(string.length, text.count)
					
			switch diff.operation.rawValue {
			case 1: // Delete
				indices["delete"]?.add(in: range)
			case 2: // Insert
				indices["insert"]?.add(in: range)
			default: // Equal
				break
			}

			string.append(text)
		}
		
		// Create a string, parse content and load document settings
		let attributedString = formatFountain(string as String)
		
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
	
	private func formatFountain(_ string: String) -> NSMutableAttributedString {
		let attributedString = NSMutableAttributedString(string: string)
		let formatting = BeatEditorFormatting(textStorage: attributedString)
		let documentSettings = delegate?.documentSettings
				
		formatting.staticParser = ContinuousFountainParser(staticParsingWith: attributedString.string, settings: documentSettings)
		formatting.formatAllLines()
		
		return attributedString
	}
	
	
	// MARK: - View mode control
	
	@IBAction func switchMode(_ sender: NSSegmentedControl) {
		if let mode = DiffViewMode(rawValue: sender.selectedSegment) {
			viewMode = mode
		}
	}
	
	// MARK: - Window actions
	
	@IBAction func close(_ sender: Any?) {
		view.window?.close()
	}
	
	override func cancelOperation(_ sender: Any?) {
		close(sender)
	}
	
	func showVersion(originalTimestamp: String) {
		self.originalTimestamp = originalTimestamp
		otherVersionMenu?.selectCommit(originalTimestamp)
		loadText()
	}
}


// MARK: - Supporting Classes

class DiffViewerTextView: NSTextView {
	weak var editor: BeatEditorDelegate?
	var magnification = 1.3
	
	override var frame: NSRect {
		didSet {
			updateTextLayout()
		}
	}
	
	func setup(editorDelegate: BeatEditorDelegate) {
		editor = editorDelegate
		
		textContainer?.widthTracksTextView = false
		scaleUnitSquare(to: CGSize(width: magnification, height: magnification))
		textContainer?.lineFragmentPadding = BeatTextView.linePadding()
		updateTextLayout()
	}
	
	private func updateTextLayout() {
		guard let editor = editor else { return }
		
		let scrollWidth = enclosingScrollView?.frame.size.width ?? 0.0
		let documentWidth = editor.documentWidth
		
		let insetWidth = (scrollWidth / 2 - documentWidth * magnification / 2) / magnification
		
		textContainerInset = CGSize(width: insetWidth, height: 10.0)
		textContainer?.containerSize = CGSize(width: documentWidth, height: .greatestFiniteMagnitude)
	}
}

class DiffViewerStatusView: NSView {
	@IBOutlet weak var icon: NSImageView?
	@IBOutlet weak var text: NSTextField?
	
	func update(uncommitedChanges: Bool) {
		if uncommitedChanges {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemYellow
			}
			
			text?.stringValue = "Uncommitted changes"
		} else {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemGreen
			}
			
			text?.stringValue = "Up to date"
		}
	}
}

class DiffTimestampMenu: NSPopUpButton {
	func selectCommit(_ timestamp: String) {
		guard let menu = menu else { return }
		
		for item in menu.items {
			if let timestampItem = item as? DiffTimestampMenuItem,
			   timestampItem.timestamp == timestamp {
				select(item)
				break
			}
		}
	}
}

class DiffTimestampMenuItem: NSMenuItem {
	var timestamp: String = ""
}
