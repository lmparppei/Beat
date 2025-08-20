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

struct VersionItem {
	var timestamp:String = ""
	var URL:URL?
}

/**
 
 A DIFF viewer for macOS version of Beat.
 We use a struct called `VersionItem` to deliver the version data. Internal version control data uses timestamps, but you can also provide a URL to the struct to use external files for diffing.
 
 */
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
	
	private var externalFiles:[URL] = []
	
	private var originalTarget: VersionItem = VersionItem(timestamp: "base") {
		didSet {
			otherVersionMenu?.selectCommit(originalTarget)
		}
	}
	
	private var modifiedTarget: VersionItem = VersionItem(timestamp: "current") {
		didSet {
			currentVersionMenu?.selectCommit(modifiedTarget)
		}
	}
	
	// MARK: UI outlets
	
	/// A view that notes that there is currently no version control available
	@IBOutlet weak var versionControlNotificationView:NSView?
	/// Main text view
	@IBOutlet private weak var textView: DiffViewerTextView?
	/// Left side version menu
	@IBOutlet private weak var currentVersionMenu: DiffTimestampMenu?
	/// Right side version menu
	@IBOutlet private weak var otherVersionMenu: DiffTimestampMenu?
	/// Bottom view with commit status
	@IBOutlet private weak var statusView: DiffViewerStatusView?
	
	@IBOutlet private weak var commitButton: NSButton?
	@IBOutlet private weak var generateRevisionsButton: NSButton?
	@IBOutlet private weak var restoreButton:NSButton?
	
	@IBOutlet private weak var actionTabs:NSTabView?
	
	// MARK: Lifecycle
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		guard let delegate = delegate else { return }
		
		self.vc = BeatVersionControl(delegate: delegate)

		// Health check (for future generations)
		if let health = vc?.doHealthCheck() {
			print("Version control dictionary is healthy:", health)
		}
		
		setupTextView()
		populateVersions()
		
		if let vc, vc.hasVersionControl() {
			_ = compareToLatestCommit()
		}
		
		refreshView()
	}
	
	
	// MARK: - Setup
	
	private func refreshView(updateCommitStatus:Bool = true) {
		guard let vc else { return }
		
		if updateCommitStatus {
			self.updateCommitStatus()
		}
		
		// All views to enable
		let viewsToEnable = [textView, currentVersionMenu, otherVersionMenu, restoreButton, generateRevisionsButton]
		// A subset of views that should be enabled for mixed state (not full VC, just external files)
		let mixedStateViews = [textView, otherVersionMenu, generateRevisionsButton]
		let viewsToHideInMixedState = [currentVersionMenu, statusView]
		
		let hasVersionControl = vc.hasVersionControl() // Full version control available
		let mixedState = externalFiles.count > 0 // Some version controls available (no VC, only an external file loaded)
		
		versionControlNotificationView?.isHidden = hasVersionControl || mixedState
		statusView?.isHidden = !hasVersionControl
		textView?.isHidden = !hasVersionControl && !mixedState
		actionTabs?.isHidden = !hasVersionControl
		
		for view in viewsToEnable {
			guard let ctrl = view as? NSControl else { continue }
			ctrl.isEnabled = hasVersionControl
			
			if mixedStateViews.contains(ctrl) {
				ctrl.isEnabled = hasVersionControl || mixedState
			}
			if mixedState, !hasVersionControl, viewsToHideInMixedState.contains(ctrl) {
				ctrl.isHidden = true
			}
		}
		
		// Certain things are only available for current timestamp.
		// You can't restore or generate markers for anything else than the latest version.
		restoreButton?.isEnabled = (
			(restoreButton?.isEnabled ?? false) && hasVersionControl && modifiedTarget.timestamp == "current") &&
			originalTarget.URL == nil
		
		generateRevisionsButton?.isEnabled = mixedState || ((generateRevisionsButton?.isEnabled ?? false) && hasVersionControl && modifiedTarget.timestamp == "current")
	}
	
	private func setupTextView() {
		guard let delegate = delegate, let textView = textView else { return }

		textView.setup(editorDelegate: delegate)
		textView.backgroundColor = if self.view.effectiveAppearance == NSAppearance(named: .aqua) { ThemeManager.shared().backgroundColor.lightColor } else { ThemeManager.shared().backgroundColor.darkColor! }
		
		// Set up custom scroller
		if let scrollView = textView.enclosingScrollView {
			let customScroller = DiffScrollerView()
			customScroller.controlSize = .regular
			customScroller.scrollerStyle = .overlay
			scrollView.verticalScroller = customScroller
			scrollView.hasVerticalScroller = true
		}
	}
	
	
	// MARK: - Version control actions
	
	@IBAction func beginVersionControl(_ sender:Any?) {
		guard let vc else { return }
		
		vc.createInitialCommit()
		refreshView()
		_ = compareToLatestCommit()
	}
	
	@IBAction func commit(_ sender: Any?) {
		guard let delegate = delegate,
			  let button = sender as? NSButton else { return }
		
		// Show a popover
		let popover = NSPopover()
		popover.behavior = .transient
		
		let popoverVC = CommitMessagePopover { [weak self] message in
			popover.close()
			
			// Create version control and add commit with message
			let vc = BeatVersionControl(delegate: delegate)
			vc.addCommit(withMessage: message)
			self?.updateCommitStatus()
			
			// After committing, select the latest commit to be displayed
			if let latest = vc.latestTimestamp() {
				self?.originalTarget = VersionItem(timestamp: latest)
			}
			
			self?.populateVersions()
			self?.refreshContent()
		}
		
		popover.contentViewController = popoverVC
		
		// Show the popover
		popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}
	
	@IBAction func revertToCurrentVersion(_ sender:Any?) {
		guard let delegate, let vc, let window = view.window else { return }
		let revertedVersion = self.originalTarget
		let timestamp = formatTimestamp(revertedVersion.timestamp)
		
		let alert = NSAlert()
		alert.messageText = "Restore Version"
		alert.informativeText = "Are you sure you want to revert the document to the state from \(timestamp)? This can't be undone and any newer commits will be removed."
		alert.addButton(withTitle: NSLocalizedString("general.ok", comment: "OK"))
		alert.addButton(withTitle: NSLocalizedString("general.cancel", comment: "Cancel"))
		
		alert.beginSheetModal(for: window) { response in
			guard response == .alertFirstButtonReturn else { return }
			
			let text = vc.revert(to: revertedVersion.timestamp)
			delegate.revert(toText: text)
			self.close(nil)
		}
	}
	
	
	// MARK: - Version selection
	
	private func populateVersions() {
		guard let vc = vc else { return }
		
		addTimestampMenuItems(menu: currentVersionMenu, versionControl: vc)
		addTimestampMenuItems(menu: otherVersionMenu, versionControl: vc, allowAddingExternalFiles: true)
		
		currentVersionMenu?.selectCommit(modifiedTarget)
		otherVersionMenu?.selectCommit(originalTarget)
	}
	
	private func addTimestampMenuItems(menu: DiffTimestampMenu?, versionControl: BeatVersionControl, allowAddingExternalFiles:Bool = false) {
		guard let menu = menu else { return }
		let hasVC = if let vc, vc.hasVersionControl() { true } else { false }
		
		menu.removeAllItems()
		
		// Add base item
		if (hasVC) {
			let baseItem = DiffTimestampMenuItem(title: formatTimestamp("base"), action: nil, keyEquivalent: "")
			baseItem.version = VersionItem(timestamp: "base")
			menu.menu?.addItem(baseItem)
		}
		
		// Add versioned items
		for commit in versionControl.commits() {
			guard let timestamp = commit["timestamp"] as? String else { return }
			let item = DiffTimestampMenuItem(title: formatTimestamp(timestamp), action: nil, keyEquivalent: "")
			item.version = VersionItem(timestamp: timestamp)
			
			if #available(macOS 14.4, *) {
				if let message = commit["message"] as? String {
					item.subtitle = message
				}
			}
			
			menu.menu?.addItem(item)
		}
		
		// Add item for current version
		if (hasVC) {
			let currentItem = DiffTimestampMenuItem(title: formatTimestamp("current"), action: nil, keyEquivalent: "")
			currentItem.version = VersionItem(timestamp: "current")
			menu.menu?.addItem(currentItem)
		}
		
		// Add any external files last
		if !externalFiles.isEmpty {
			// Add a separator if there actual commits were added before this
			if let items = menu.menu?.items, items.count > 0 {
				menu.menu?.addItem(NSMenuItem.separator())
			}
			for url in externalFiles {
				let filename = url.deletingPathExtension().lastPathComponent
				let item = DiffTimestampMenuItem(title: filename, action: nil, keyEquivalent: "")
				item.version = VersionItem(URL: url)
				
				menu.menu?.addItem(item)
			}
		}
		
		// Add a separator if there actual commits were added before this
		if allowAddingExternalFiles {
			if let items = menu.menu?.items, items.count > 0 { menu.menu?.addItem(NSMenuItem.separator()) }
			let addFileItem = NSMenuItem(title: BeatLocalization.localizedString(forKey: "versionControl.addExternalFile"), action: #selector(openExternalFile), keyEquivalent: "")
			menu.menu?.addItem(addFileItem)
		}
	}
	
	private func formatTimestamp(_ timestamp: String) -> String {
		// Special timestamps need to be localized
		if timestamp == "base" || timestamp == "current" {
			return BeatLocalization.localizedString(forKey: "versionControl." + timestamp)
		}
		
		// Timestamps are stored in shortened ISO format
		let inputFormatter = DateFormatter()
		inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		
		// Output formatter for user-friendly display
		let outputFormatter = DateFormatter()
		outputFormatter.dateStyle = .medium
		outputFormatter.timeStyle = .short
		outputFormatter.doesRelativeDateFormatting = true
		
		if let date = inputFormatter.date(from: timestamp) {
			return outputFormatter.string(from: date)
		}
		
		// Fallback to the original timestamp if parsing fails
		return timestamp
	}
	
	@IBAction func selectVersion(_ sender: NSPopUpButton?) {
		guard let button = sender,
			  let menuItem = button.selectedItem as? DiffTimestampMenuItem
			  //let timestamp = menuItem.version.timestamp.isEmpty ? button.selectedItem?.title : menuItem.version.timestamp // wtf is this?
		else { return }
		
		let version = menuItem.version
		
		if sender == currentVersionMenu {
			modifiedTarget = version
		} else {
			originalTarget = version
		}
		
		refreshContent()
	}
	
	@IBAction func openExternalFile(_ sender: AnyObject?) {
		let openDialog = NSOpenPanel()
		if #available(macOS 11.0, *) {
			if let fountain = UTType(filenameExtension: "fountain") { openDialog.allowedContentTypes.append(fountain) }
			if let txt = UTType(filenameExtension: "txt") { openDialog.allowedContentTypes.append(txt) }
		} else {
			openDialog.allowedFileTypes = ["fountain", "txt"]
		}
		
		openDialog.begin { response in
			guard response == .OK, let url = openDialog.url else { return }
			self.externalFiles.append(url)
			
			// Set the original target to the URL immediately, so the UI doesn't panic.
			self.originalTarget = VersionItem(URL: url)
			
			self.populateVersions()
			self.refreshContent()
		}
	}
	
	/// Helper method to quickly select the latest commit at startup
	func compareToLatestCommit() -> Bool {
		guard let vc else { return false }
		
		let latest = vc.latestTimestamp() ?? "base"
		
		modifiedTarget = VersionItem(timestamp: "current")
		originalTarget = VersionItem(timestamp: latest)
		
		refreshContent()
		
		return true
	}
	
	// MARK: - Content Loading
	
	private func refreshContent() {
		refreshView(updateCommitStatus: false)
		
		// Update both texts
		updateTexts()
		
		if viewMode == .compare {
			loadDiff()
		} else {
			loadText()
		}
		
		updateScrollerWithDiffMarkers()
	}
	
	private func updateCommitStatus() {
		let uncommitted = vc?.hasUncommittedChanges() ?? false
		
		statusView?.update(uncommitedChanges: uncommitted)
		commitButton?.isEnabled = uncommitted
	}

	/// Build both texts for version control
	private func updateTexts() {

		// If we have external files loaded AND NO VC, we need to do some trickery
		if let vc, !vc.hasVersionControl(), !externalFiles.isEmpty {
			modifiedTarget = VersionItem(timestamp: "current")
			// The "original" target has been set by the open dialog, let's hope
		}
		
		originalText = getText(version: originalTarget)
		modifiedText = getText(version: modifiedTarget)
	}
	
	private func getText(version: VersionItem) -> String? {
		guard let delegate, let vc else {
			print("Error fetching commit text")
			return nil
		}
		
		if let url = version.URL {
			// Handle external files first
			if var text = try? String(contentsOf: url, encoding: .utf8) {
				let settings = BeatDocumentSettings()
				let range = settings.readAndReturnRange(text)
				text = String(text.prefix(range.location))
				return text
			} else {
				return ""
			}
		} else {
			// This is an internal timestamp
			if version.timestamp == "current" {
				return delegate.text()
			} else {
				return vc.text(at: version.timestamp)
			}
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
		textView?.needsDisplay = true
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
			guard NSMaxRange(range) <= attributedString.length else { return }
			
			attributedString.addAttribute(.backgroundColor, value: redColor, range: range)
			attributedString.addAttribute(.strikethroughColor, value: NSColor.red, range: range)
			attributedString.addAttribute(.strikethroughStyle, value: 1, range: range)
			attributedString.addAttribute(NSAttributedString.Key("DIFF"), value: "delete", range: range)
		})
		indices["insert"]?.enumerateRanges(using: { range, stop in
			guard NSMaxRange(range) <= attributedString.length else { return }
			
			attributedString.addAttribute(.backgroundColor, value: greenColor, range: range)
			attributedString.addAttribute(NSAttributedString.Key("DIFF"), value: "add", range: range)
		})
		
		return attributedString
	}
	
	private func formatFountain(_ string: String) -> NSMutableAttributedString {
		let settings = BeatDocumentSettings()
		
		let settingRange = settings.readAndReturnRange(string)
		
		var content = string
		if settingRange.location != NSNotFound && settingRange.length != 0 {
			content = String(string.prefix(settingRange.location))
		}

		let attributedString = NSMutableAttributedString(string: content)
		let formatting = BeatEditorFormatting(textStorage: attributedString)

		formatting.staticParser = ContinuousFountainParser(staticParsingWith: attributedString.string, settings: settings)
		formatting.formatAllLines()
		
		return attributedString
	}
	
	
	// Call this after the text is set in textView
	func updateScrollerWithDiffMarkers() {
		guard let textView = textView,
			  let textStorage = textView.textStorage,
			  let scrollView = textView.enclosingScrollView,
			  let scroller = scrollView.verticalScroller as? DiffScrollerView else { return }
		
		var insertRanges: [NSRange] = []
		var deleteRanges: [NSRange] = []
		
		// Scan through the entire text storage to find diff markers
		textStorage.enumerateAttribute(NSAttributedString.Key("DIFF"), in: textStorage.range) { value, range, stop in
			guard let attr = value as? String else { return }
			if attr == "delete" {
				deleteRanges.append(range)
			} else {
				insertRanges.append(range)
			}
		}
				
		// Update the scroller with the found ranges
		scroller.updateDiffRanges(
			insertRanges: insertRanges,
			deleteRanges: deleteRanges,
			totalLength: textStorage.length
		)
	}
	
	// MARK: - View mode control
	
	@IBAction func switchMode(_ sender: NSSegmentedControl) {
		if let mode = DiffViewMode(rawValue: sender.selectedSegment) {
			viewMode = mode
			actionTabs?.selectTabViewItem(at: mode.rawValue)
		}
	}
	
	// MARK: - Revision menu
	
	func generateRevisions(generation:Int) {
		guard let vc else { return }
		
		if let _ = originalTarget.URL, let text = originalText, text.count > 0 {
			// This is an external diff file
			vc.generateRevisedRanges(fromText: text, generation: generation)
		} else {
			// This is a timestamp from internal VC
			vc.generateRevisedRanges(from: self.originalTarget.timestamp, generation: generation)
		}
		
		self.close(nil)
	}
	
	
	// MARK: - Window actions
	
	@IBAction func close(_ sender: Any?) {
		if let sheetParent = view.window?.sheetParent, let window = view.window {
			sheetParent.endSheet(window)
		}
	}
	
	override func cancelOperation(_ sender: Any?) {
		close(sender)
	}
	
	fileprivate func showVersion(version: VersionItem) {
		self.originalTarget = version
		otherVersionMenu?.selectCommit(version)
		loadText()
	}
	
	
	
	// MARK: -  Segues

	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		guard let delegate else { return }
		
		if segue.identifier == "GenerateMarkers", let vc = segue.destinationController as? DiffViewerGenerateMarkersViewController {
			vc.loadView()
			vc.diffView = self
			vc.generationMenu?.menu?.items = BeatRevisionMenuItem.revisionItems(currentGeneration: delegate.revisionLevel, handler: { menuItem in })
		}
	}
	
}


class DiffViewerGenerateMarkersViewController:NSViewController {
	@IBOutlet weak var generationMenu:NSPopUpButton?
	weak var diffView:DiffViewerViewController?
	
	@IBAction func generate(_ sender:Any?) {
		if let generation = generationMenu?.indexOfSelectedItem {
			diffView?.generateRevisions(generation: generation)
		}
		self.view.window?.contentViewController?.dismiss(self)
	}
}
