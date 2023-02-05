//
//  DocumentViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import WebKit
import BeatCore
import BeatParsing
import BeatDefaults
import BeatPaginationCore
import BeatDynamicColor
import BeatThemes

class DocumentViewController: UIViewController, ContinuousFountainParserDelegate, BeatEditorDelegate, UITextViewDelegate, iOSDocumentDelegate {
	var hideFountainMarkup: Bool = false
	
	var exportSettings: BeatExportSettings {
		return BeatExportSettings()
	}
	
	func fileNameString() -> String! {
		return self.document?.fileURL.lastPathComponent ?? "Untitled"
	}
	
	func setAutomaticTextCompletionEnabled(_ value: Bool) {
		print("# Automatic text completion missing")
	}
	
	func attributedString() -> NSAttributedString! {
		if (Thread.isMainThread) {
			return self.textView.attributedText
		} else {
			return self.cachedText
		}
	}
	
	func add(_ string: String!, at index: UInt) {
		self.replace(NSMakeRange(Int(index), 0), with: string)
	}
	
	func remove(_ string: String!, at index: UInt) {
		self.replace(NSMakeRange(Int(index), string.count), with: "")
	}
	
	func replace(_ string: String!, with newString: String!, at index: UInt) {
		replace(NSMakeRange(Int(index), string.count), with: newString)
	}
	
	func contdString() -> String! {
		return BeatUserDefaults.shared().get(BeatSettingScreenplayItemContd)  as? String ?? ""
	}
	
	func moreString() -> String! {
		return BeatUserDefaults.shared().get(BeatSettingScreenplayItemMore) as? String ?? ""
	}
	
	var selectedRange: NSRange {
		get {
			return self.textView.selectedRange
		}
		set {
			self.textView.selectedRange = newValue
		}
	}
	
	func selectedTextRange() -> UITextRange! {
		return self.textView.selectedTextRange
	}
	
	func setSelectedTextRange(_ textRange: UITextRange!) {
		self.textView.selectedTextRange = textRange
	}
	
	func move(_ sceneToMove: OutlineScene!, from: Int, to: Int) {
		print("Implement move scene")
	}
	
	
	func returnToEditor() {
		print("Return to editor...")
	}
	
	func toggle(_ mode: BeatEditorMode) {
		self.mode = mode
	}
	
		
	var document: iOSDocument?
	var contentBuffer = ""
	
	@IBOutlet weak var textView: BeatUITextView!
	@IBOutlet weak var scrollView: UIScrollView!
	@IBOutlet weak var outlineView: BeatiOSOutlineView!
	@IBOutlet weak var sidebar: UIView!
	@IBOutlet weak var titleBar:UINavigationItem?
	
	var attrTextCache: NSAttributedString! {
		get { cachedText }
	}
	
	@objc var parser: ContinuousFountainParser?
	var cachedText:NSMutableAttributedString = NSMutableAttributedString()
	
	@objc var documentIsLoading = true
	
	@objc var documentSettings:BeatDocumentSettings! { get { return document?.settings } set {} }
	@objc var printSceneNumbers: Bool = true
	@objc var characterInputForLine: Line?
	@objc var formatting: BeatiOSFormatting = BeatiOSFormatting()

	@objc var showSceneNumberLabels: Bool = true
	@objc var typewriterMode: Bool = false
	@objc var magnification:CGFloat { return self.textView.enclosingScrollView.zoomScale }
	@objc var inset: CGFloat = 0.0
	@objc var documentWidth: CGFloat {
		if (self.pageSize == .A4) { return BeatFonts.characterWidth() * 59 }
		else { return BeatFonts.characterWidth() * 61 }
	}
	@objc var characterGenders: NSMutableDictionary = NSMutableDictionary()
	@objc var revisionColor: String = "blue"
	@objc var revisionMode: Bool = false
	
	@objc var courier: UIFont! = BeatFonts.shared().courier
	@objc var boldCourier: UIFont! = BeatFonts.shared().boldCourier
	@objc var boldItalicCourier: UIFont! = BeatFonts.shared().boldItalicCourier
	@objc var italicCourier: UIFont! = BeatFonts.shared().italicCourier
	
	@objc var paginator:BeatPaginator?
	
	@objc var characterInput: Bool = false
	@objc var headingStyleBold: Bool = true
	@objc var headingStyleUnderline: Bool = false
	@objc var showRevisions: Bool = true
	@objc var showTags: Bool = true
	@objc var sectionFont: UIFont! = UIFont.boldSystemFont(ofSize: 18.0)
	@objc var sectionFonts: NSMutableDictionary! = NSMutableDictionary()
	@objc var synopsisFont: UIFont! = UIFont.italicSystemFont(ofSize: 12.0)
	@objc var mode: BeatEditorMode = .EditMode
	
	@objc var automaticContd = true
	@objc var autoLineBreaks = true
	@objc var matchParentheses = true
	
	@objc var preview:BeatPreview?
	@objc var previewView:BeatPreviewView?
	@objc var previewUpdated = false
	@objc var previewHTML = ""
	@objc var previewTimer:Timer?
	
	@objc var sidebarVisible = false
	@objc @IBOutlet weak var sidebarConstraint:NSLayoutConstraint!
	
	var keyboardManager = KeyboardManager()
		//var documentWindow: UIWindow!
	
	@objc @IBOutlet weak var documentNameLabel: UILabel!
	
	
	// MARK: - Preparing the view
		
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// If we've already loaded the document, do nothing
		if !documentIsLoading { return }
		
		// Hide sidebar
		self.sidebarConstraint.constant = 0
		
		// Hide page view until loading is complete
		self.textView.pageView.layer.opacity = 0.0

		
		document?.open(completionHandler: { (success) in
			if success {
				// Display the content of the document, e.g.:
				//self.documentNameLabel.text = self.document?.fileURL.lastPathComponent
				self.titleBar?.title = self.document?.fileURL.lastPathComponent
				print("setting up document")
				
				self.setupDocument()
				self.renderDocument()
			} else {
				// Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
			}
		})
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Set text view size
		textView.resize()
		
		if documentIsLoading {
			// Loading is complete, show page view
			UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn) {
				self.textView.pageView.layer.opacity = 1.0
			} completion: { success in 	}
			
			// Loading complete
			documentIsLoading = false
		}
	}
	
	@IBAction func dismissDocumentViewController() {
		self.previewView?.webview?.removeFromSuperview()
		self.previewView?.webview = nil
		
		self.previewView?.nibBundle?.unload()
		self.previewView = nil
		
		dismiss(animated: true) {
			self.document?.close(completionHandler: nil)
		}
	}
	
	
	// MARK: - Setup document and associated classes
	
	func setupDocument () {
		if (self.document == nil) { return; }
		
		document?.delegate = self
		contentBuffer = document?.rawText ?? ""
		
		parser = ContinuousFountainParser(string: contentBuffer, delegate: self)
		formatting.delegate = self
		
		// Init preview
		preview = BeatPreview(document: self)
		previewView = self.storyboard?.instantiateViewController(withIdentifier: "Preview") as? BeatPreviewView
		previewView?.loadViewIfNeeded()
				
		// Fit to view here
		scrollView.zoomScale = 1.4
		
		// Keyboard manager
		keyboardManager.delegate = self
		
		// Text view settings
		textView.textStorage.delegate = self
	}
	
	// MARK: Render document for display
	func renderDocument () {
		textView?.text = contentBuffer
		cachedText.setAttributedString(NSAttributedString(string: contentBuffer))
		
		formatAllLines()
		outlineView.reloadData()
	}
	
	// MARK: - Return self for delegation
	
	@objc func documentForDelegation() -> Any {
		return self
	}
	
	
	// MARK: - Sidebar actions
	
	@IBAction func toggleSidebar () {
		sidebarVisible = !sidebarVisible
		
		var sidebarWidth = 0.0
		
		if (sidebarVisible) {
			sidebarWidth = 230.0
		}
		
		UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) {
			self.sidebarConstraint.constant = sidebarWidth
			self.view.layoutIfNeeded()
		}
	}
	
	// MARK: - Preview
	
	@IBAction func togglePreview(sender: Any?) {
		if (!previewUpdated) {
			updatePreview(sync: true)
		}
		
		self.present(previewView!, animated: true)
	}
	
	func updatePreview() {
		updatePreview(sync: false)
	}
	
	func updatePreview(sync:Bool) {
		// Update cache
		self.cachedText = NSMutableAttributedString(attributedString: self.textView.attributedText)
		
		previewTimer?.invalidate()
		previewUpdated = false
		
		// Wait 1 second after writing has ended to build preview
		let delay = (previewHTML.count == 0 || sync) ? 0 : 1.5
		
		previewTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { timer in
			let rawText = self.text()
			
			DispatchQueue.global(qos: .background).async {
				self.previewHTML = self.preview!.createPreview(for: rawText, type: .printPreview)
				DispatchQueue.main.async {
					self.previewView?.webview?.loadHTMLString(self.previewHTML, baseURL: nil)
					self.previewUpdated = true
				}
			}
		})
	}
	
	
	// MARK: - Random
	
	// Delegation
	func sceneNumberingStartsFrom() -> Int {
		return 1
	}
	
	
	// MARK: - Formatting
	
	func formatAllLines() {
		for line in parser!.lines {
			formatting.formatLine(line as! Line)
		}
	}
	
	func reformatLines(at indices: NSMutableIndexSet!) {
		indices.enumerate { index, stop in
			let line = parser?.lines[index]
			if (line != nil) { formatting.formatLine(line as! Line) }
		}
	}
	
	func applyFormatChanges() {
		parser?.changedIndices.enumerate({ idx, stop in
			if idx >= parser!.lines.count {
				stop.pointee = true
				return
			}
			
			formatting.formatLine(parser!.lines[idx] as! Line)
		})
		
		parser?.changedIndices.removeAllIndexes()
	}
	
	func renderBackground(for line: Line!, clearFirst clear: Bool) {
		formatting.renderBackground(for: line, clearFirst: clear)
	}
	
	func renderBackgroundForLines() {
		for line in parser!.lines {
			formatting.renderBackground(for: line as! Line, clearFirst: true)
		}
	}
	
	func renderBackground(for range: NSRange) {
		let lines = parser!.lines(in: range) as! [Line]
		
		for l in lines {
			formatting.renderBackground(for: l, clearFirst: true)
		}
	}
	
	func forceFormatChanges(in range: NSRange) {
		let lines = parser!.lines(in: range) as! [Line]
		
		for l in lines {
			formatting.formatLine(l)
		}
	}
	
	// MARK: - Print info
	
	func printInfo() -> UIPrintInfo! {
		return UIPrintInfo.printInfo()
	}
	
	var pageSize: BeatPaperSize {
		get {
			return BeatPaperSize(rawValue: documentSettings.getInt(DocSettingPageSize)) ?? .A4;
		}
		set {
			documentSettings.setInt(DocSettingPageSize, as:BeatPaperSize.A4.rawValue)
		}
	}
	
	
	// MARK: - Line and outline methods
		
	func scenes() -> NSMutableArray! {
		let scenes = parser!.scenes()
		return NSMutableArray(array: scenes!)
	}
	
	func getOutlineItems() -> NSMutableArray! {
		return parser?.outline
	}
	
	var currentScene: OutlineScene! {
		get {
			let scenes = parser?.scenes() as! [OutlineScene]
			for scene in scenes {
				let range = scene.range()
				if NSLocationInRange(NSMaxRange(range), range) {
					return scene
				}
			}
			return nil
		}
	}
	
	var cachedCurrentLine:Line?
	func currentLine() -> Line! {
		let loc = self.selectedRange.location
		if (loc >= textView.text.count) {
			return parser!.lines.lastObject as? Line
		}
		
		if (cachedCurrentLine != nil) {
			if (NSLocationInRange(loc, cachedCurrentLine!.range())) {
				return cachedCurrentLine
			}
		}
		
		cachedCurrentLine = parser?.line(atPosition: loc)
		return cachedCurrentLine
	}
	
	
	func lines() -> NSMutableArray! {
		let lines = parser!.lines
		return NSMutableArray(array: lines!)
	}
		
	func lines(for scene: OutlineScene!) -> [Any]! {
		return parser?.lines(for: scene)
	}
	
	func lineType(at index: Int) -> Int {
		return Int(parser!.lineType(at: index).rawValue)
	}
	
	func setSelectedRange(_ range: NSRange) {
		self.textView.selectedRange = range
	}
	
	func getOutline() -> [Any]! {
		let outline = parser!.outline
		return outline as? [Any]
	}
	
	
	// MARK: - Text I/o
	
	// Return raw text from text view
	func text() -> String! { return textView.text }
	
	func replace(_ range: NSRange, with newString: String!) {
		let textRange = formatting.getTextRange(for: range)
		textView.replace(textRange, withText: newString)
	}
	
	func addString(string: String, atIndex index:Int) {
		replaceCharacters(inRange: NSRange(location: index, length: 0), string: string)
		if let target = undoManager?.prepare(withInvocationTarget: self) as? DocumentViewController {
			target.removeString(string: string, atIndex: index)
			
		}
	}
		
	func removeString(string: String, atIndex index:Int) {
		replaceCharacters(inRange: NSRange(location: index, length: string.count), string: string)
	}
	
	func replaceRange(range: NSRange, withString string:String) {
		let oldString = self.textView.text.substring(range: range)
		replaceCharacters(inRange: range, string: string)
		
		if let target = undoManager?.prepare(withInvocationTarget: self) as? DocumentViewController {
			target.replaceString(string: string, withString: oldString, atIndex: range.location)
		}
	}
	
	func removeRange(range: NSRange) {
		let string = textView.text.substring(range: range)
		replaceCharacters(inRange: range, string: "")
		
		if let target = undoManager?.prepare(withInvocationTarget: self) as? DocumentViewController {
			target.addString(string: string, atIndex: range.location)
		}
	}
	
	func replaceString(string: String, withString newString:String, atIndex indx:Int) {
		let range = NSRange(location: indx, length: string.count)
		replaceCharacters(inRange: range, string: newString)
		
		if let target = undoManager?.prepare(withInvocationTarget: self) as? DocumentViewController {
			target.replaceString(string: newString, withString: string, atIndex: indx)
		}
	}
	
	/**
	 The main method for adding text to text view. Forces added text to be parsed, and **does not** invoke undo manager.
	 */
	func replaceCharacters(inRange range:NSRange, string:String) {
		if (textView(textView, shouldChangeTextIn: range, replacementText: string)) {
			textView.textStorage.replaceCharacters(in: range, with: string)
			textViewDidChange(textView)
		}
	}
	
	func setTypingAttributes(_ attrs: [AnyHashable : Any]!) {
		self.textView.typingAttributes = attrs as? Dictionary<NSAttributedString.Key, Any> ?? [:]
	}
	
	func addAttribute(_ key: String!, value: Any!, range: NSRange) {
		guard let attrValue = value else { return }
		self.textView.textStorage.addAttribute(NSAttributedString.Key(key), value: attrValue, range: range)
	}
	
	func removeAttribute(_ key: String!, range: NSRange) {
		self.textView.textStorage.removeAttribute(NSAttributedString.Key(key), range: range)
	}
	
	@objc func layoutManager() -> NSLayoutManager {
		return self.textView.layoutManager
	}
	@objc func textStorage() -> NSTextStorage {
		return self.textView.textStorage
	}
	
	// MARK: - Misc stuff
	
	func addStoryline(_ storyline: String!, to scene: OutlineScene!) {
		print("Add storyline")
	}
	
	func removeStoryline(_ storyline: String!, from scene: OutlineScene!) {
		print("Remove storyline")
	}
	
	func setColor(_ color: String!, for scene: OutlineScene!) {
		print("Set color")
	}
	
	func caretAtEnd() -> Bool {
		if textView.selectedRange.location == textView.text.count {
			return true
		} else {
			return false
		}
	}
	
	func isDark() -> Bool {
		return false
	}
	
	func showLockStatus() {
		print("Show lock status...")
	}
	
	func contentLocked() -> Bool {
		return false
	}
	
	func hasChanged() -> Bool {
		return document!.hasUnsavedChanges
	}
	
	func markers() -> [Any]! {
		print("Request markers")
		return []
	}
	
	func updateQuickSettings() {
		print("Update quick settings")
	}
	
	func scroll(to line: Line!) {
		textView.scrollRangeToVisible(line.range())
	}
	
	func scroll(to range: NSRange) {
		textView.scrollRangeToVisible(range)
	}
	
	func scroll(to range: NSRange, callback callbackBlock: (() -> Void)!) {
		textView.scrollRangeToVisible(range)
		callbackBlock()
	}
	
	func updateChangeCount(_ change: UIDocument.ChangeKind) {
		document?.updateChangeCount(change)
	}
	
	
	func refreshTextViewLayoutElements() {
		print("refresh all layout elements")
	}
	
	func refreshTextViewLayoutElements(from location: Int) {
		print("refresh text view layout elements")
	}
		
	func sectionFont(withSize size: CGFloat) -> UIFont! {
		return UIFont.systemFont(ofSize: size)
	}
	
	func registerEditorView(_ view: Any!) {
		print("Register editor view")
	}
		
	func addDualLineBreak(at range:NSRange) {
		addString(string: "\n\n", atIndex: range.location)
		textView.selectedRange = NSRange(location: range.location + 2, length: 0)
	}
	
	// MARK: - Font size
	
	func fontSize() -> CGFloat {
		return courier.pointSize
	}

}


// MARK: - Text view delegation

extension DocumentViewController {
	
	func textDidChange(_ notification: Notification!) {
		// Faux method for protocol compatibility
		textViewDidChange(textView)
	}
	
	func textViewDidChange(_ textView: UITextView) {
		applyFormatChanges()
		self.textView.resize()
		
		cachedText.setAttributedString(textView.attributedText)
		
		// Update preview
		updatePreview()
	}
	
	
	func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
		let currentLine = self.currentLine()
		if (!undoManager!.isUndoing && !undoManager!.isRedoing &&
			self.selectedRange.length == 0 && currentLine != nil) {
			
			if (range.length == 0 && text == "\n") {
				// Test if we'll add extra line breaks and exit the method
				if shouldAddLineBreak(currentLine: self.currentLine()!, range: range) {
					return false
				}
			}
			
			// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
			else if (self.matchParentheses) {
				tryToMatchParentheses(range: range, string: text)
			}
			
			// Jump over already-typed parentheses and other closures
			else if (shouldJumpOverParentehses(string: text, range: range)) {
				return false
			}
		}
				
		return true
	}
	
	func shouldJumpOverParentehses(string:String, range:NSRange) -> Bool {
		if range.location < textView.text.count {
			let currentChr = self.textView.text.substring(range: NSRange(location: range.location, length: 1))
			if ((currentChr == ")" && string == ")") ||
				(currentChr == "]" && string == "]")) {
				textView.selectedRange = NSRange(location: range.location + 1, length: 0)
				return true
			}
		}
		
		return false
	}
	
	func tryToMatchParentheses(range:NSRange, string:String) {
		/**
		 This method finds a matching closure for parenthesis, notes and omissions.
		 It works by checking the entered symbol and if the previous symbol in text
		 matches its counterpart (like with *, if the previous is /, terminator is appended.
		 */
		
		if string.count > 1 { return }
		
		let matches = [	"(": ")", "[[": "]]", "/*": "*/" ]

		var match:String = ""
		
		for key in matches.keys {
			let lastSymbol = key.suffix(1)
			
			if string == lastSymbol {
				match = key
				break
			}
		}
		
		if matches[match] == nil { return }
		
		print("Matching parentheses", match, matches[match]!)
	
		if match.count > 1 {
			// Check for dual symbol matches, and don't allow them if the previous char doesn't match
			if range.location == 0 { return } // We can't be at the beginning
			let chrBefore = textView.text.substring(range: NSRange(location: range.location-1, length: 1))
			if chrBefore != match.substring(range: NSMakeRange(0, 1)) { return }
		}
		
		self.addString(string: matches[match]!, atIndex: range.location)
		textView.selectedRange = range
	}
	
	func shouldAddLineBreak(currentLine:Line, range:NSRange) -> Bool {
		// Handle line breaks
			
		if currentLine.isAnyCharacter() {
			let nextLine = self.parser!.nextLine(currentLine) ?? nil
			
			if nextLine != nil {
				if (nextLine!.isAnyDialogue() || nextLine?.type == .empty) {
					print("do something...")
				}
			}
			
			if self.automaticContd {
				print("add cont'd")
			}
		}
		
		// When on a parenthetical, don't split it when pressing enter, but move downwards to next dialogue block element
		// Note: This logic is a bit faulty. We should probably just move on next line regardless of next character
		else if (currentLine.isAnyParenthetical() && textView.text.count > range.location) {
			let chr = textView.text.substring(range: NSRange(location: range.location, length: 1))
			
			if (chr == ")") {
				addString(string: "\n", atIndex: range.location + 1)
				let nextLine = parser!.nextLine(currentLine)
				if (nextLine != nil) { formatting.formatLine(nextLine!) }
				textView.selectedRange = NSRange(location: range.location + 2, length: 0)
				return true
			}
		}
		
		else if autoLineBreaks {
			if currentLine.string.count > 0 {
				
				// Auto line breaks after outline elements
				if (currentLine.isOutlineElement() || currentLine.isAnyDialogue()) {
					addDualLineBreak(at: range)
					return true
				}
				
				// Special rules for action lines
				else if currentLine.type == .action {
					let currentIndex = parser!.lines.index(of: currentLine)
					
					// WIP: Simplify this messy conditional
					if currentIndex < parser!.lines.count - 2 && currentIndex != NSNotFound {
						let nextLine = parser!.nextLine(currentLine)
						if (nextLine?.length == 0) {
							nextLine?.type = .empty
							addDualLineBreak(at: range)
							return true
						}
					} else {
						addDualLineBreak(at: range)
						return true
					}
				}
			}
		}
		
		return false
	}
	
	@objc func lineType(at index: Int) -> LineType {
		return self.parser?.lineType(at: index) ?? .empty
	}
}

// MARK: - Keyboard delegate
extension DocumentViewController:KeyboardManagerDelegate {
	func keyboardWillShow(with size: CGSize, animationTime: Double) {
		let insets = UIEdgeInsets(top: 0, left: 0, bottom: size.height, right: 0)
		
		UIView.animate(withDuration: animationTime, delay: 0.0, options: .curveLinear) {
			self.scrollView.contentInset = insets
		} completion: { finished in
			self.textView.resize()
			
			if (self.selectedRange.location != NSNotFound) {
				let rect = self.textView.rectForRange(range: self.selectedRange)
				let visible = self.textView.convert(rect, to: self.scrollView)
				self.scrollView.scrollRectToVisible(visible, animated: true)
			}
		}
	}
	
	func keyboardWillHide() {
		scrollView.contentInset = UIEdgeInsets()
	}
	
}

// MARK: - Zooming
/*
extension DocumentViewController: UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return nil
	}
}
 */


// MARK: - Text Storage delegation

extension DocumentViewController: NSTextStorageDelegate {

	func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
		
	}
	
	func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
		if (documentIsLoading) { return }
				
		// Don't parse anything when editing attributes
		if editedMask == .editedAttributes { return }
	
		var affectedRange = NSRange(location: NSNotFound, length: 0)
		var string = ""
		
		if (editedRange.length == 0 && delta < 0) {
			// Single removal. Note that delta is NEGATIVE.
			let removedRange = NSRange(location: editedRange.location, length: abs(delta))
			
			// Set the range
			affectedRange = removedRange
			string = ""
		}
		else if (editedRange.length > 0 && delta <= 0) {
			// Something was replaced. Note that delta is NEGATIVE.
			let addedRange = editedRange
			let replacedRange = NSRange(location: editedRange.location, length: editedRange.length + abs(delta))
			
			affectedRange = replacedRange
			string = textView.text.substring(range: addedRange)
		}
		else {
			// Addition
			if (delta > 1) {
				// Longer addition
				let addedRange = editedRange
				let replacedRange = NSRange(location: editedRange.location, length: editedRange.length - abs(delta))
				
				affectedRange = replacedRange
				string = textView.text.substring(range: addedRange)
			}
			else {
				// Single addition
				let addedRange = NSRange(location: editedRange.location, length: delta)
				affectedRange = NSRange(location: editedRange.location, length: 0)
				string = textView.text.substring(range: addedRange)
			}
		}
		
		print("Parsing change at ", affectedRange, "string:", string)
		parser?.parseChange(in: affectedRange, with: string)
	}
}
