//
//  BeatUITextView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore
import BeatParsing

@objc protocol BeatTextEditorDelegate:BeatEditorDelegate {
	@objc var revisionTracking:BeatRevisions { get }
	@objc var formattingActions:BeatEditorFormattingActions { get }
	@objc var textActions:BeatTextIO { get }
}

class BeatUITextView: UITextView, UIEditMenuInteractionDelegate, InputAssistantViewDelegate {

	//@IBInspectable var documentWidth:CGFloat = 640
	@IBOutlet weak var editorDelegate:BeatTextEditorDelegate?
	@IBOutlet weak var enclosingScrollView:UIScrollView!
	@IBOutlet weak var pageView:UIView!
	
	@objc public var assistantView:InputAssistantView?
	
	var insets = UIEdgeInsets(top: 50, left: 30, bottom: 50, right: 30)
	var pinchRecognizer = UIGestureRecognizer()
	var customLayoutManager:BeatLayoutManager
	
	class func linePadding() -> CGFloat {
		return 40.0
	}
	
	// MARK: - Initializers
	
	/// This class function creates and sets up the main editor text view. We can't create a text view in IB, because layout manager can't be replaced when initializing through `NSCoder`.
	@objc class func createTextView(editorDelegate:BeatEditorDelegate, frame:CGRect, pageView:BeatPageView, scrollView:BeatScrollView) -> BeatUITextView {
		// First create core text system
		let textContainer = NSTextContainer()
		let layoutManager = BeatLayoutManager()
		let textStorage = NSTextStorage(string: "")
		
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		
		// Create the text view and connect the container + layout anager
		let textView = BeatUITextView(frame: frame, textContainer: textContainer, layoutManager: layoutManager)
		textView.autoresizingMask = [.flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		textView.textContainer.widthTracksTextView = false
		textView.autocorrectionType = .no
		
		// Set up the container views
		textView.pageView = pageView
		textView.enclosingScrollView = scrollView
		
		// Set up assistant view
		textView.assistantView = InputAssistantView(editorDelegate: editorDelegate, inputAssistantDelegate: textView)
		textView.assistantView?.attach(to: textView)
		
		layoutManager.editorDelegate = editorDelegate
		textView.setup()
		
		return textView
	}
	
	init(frame: CGRect, textContainer: NSTextContainer?, layoutManager:BeatLayoutManager) {
		customLayoutManager = layoutManager
		super.init(frame: frame, textContainer: textContainer)
	}
	
	override var textLayoutManager: NSTextLayoutManager? {
		return nil
	}
	
	required init?(coder: NSCoder) {
		customLayoutManager = BeatLayoutManager()
		super.init(coder: coder)

		self.textStorage.removeLayoutManager(self.textStorage.layoutManagers.first!)
		
		customLayoutManager.addTextContainer(self.textContainer)
		customLayoutManager.textStorage = self.textStorage
		
		self.textContainer.replaceLayoutManager(customLayoutManager)
	}
	
	
	// MARK: - Layout manager
	
	override var layoutManager: NSLayoutManager {
		return customLayoutManager
	}
	
	
	// MARK: - Setup
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setup()
	}
	
	func setup() {
		self.textContainerInset = insets
		self.isScrollEnabled = false
		
		// Delegates
		enclosingScrollView?.delegate = self
		layoutManager.delegate = self
		
		// View setup
		self.textContainer.widthTracksTextView = false
		self.textContainer.heightTracksTextView = false
		
		self.textContainer.size = CGSize(width: self.documentWidth, height: self.textContainer.size.height)
		self.textContainer.lineFragmentPadding = BeatUITextView.linePadding()
		
		self.keyboardAppearance = .dark
		
		resizePaper()
		resize()
		
		setupInputAssistantButtons()
	}
		
	override func layoutSubviews() {
		super.layoutSubviews()
		resize()
	}
	
	
	// MARK: - Scroll to range
	
	@objc func scrollToRange(_ range:NSRange) {
		var rect = self.rectForRange(range: range)
		rect.origin.y += self.insets.top
		rect.size.height += self.insets.bottom
		rect.origin.y = self.enclosingScrollView.zoomScale * rect.origin.y
		
		self.enclosingScrollView.scrollRectToVisible(rect, animated: true)
	}
	
	
	// MARK: - Resize scroll view and text view
	/**
	 
	 To achieve the "page-like" view, we need to do some trickery.
	 
	 Instead of using the built-in scroll view of `UITextView`, we're wrapping `UITextView` inside an `NSView` placed inside a `UIScrollView`.
	 Whenever the text view content changes, we'll need to resize the wrapping view and content size of the enclosing scroll view.
	 
	 */
	
	@objc var documentWidth:CGFloat {
		var width = 0.0
		let padding = self.textContainer.lineFragmentPadding
		
		guard let delegate = self.editorDelegate else { return 0.0 }
		
		if delegate.pageSize == .A4 {
			width = BeatFonts.characterWidth() * 60
		} else {
			width = BeatFonts.characterWidth() * 62
		}
		
		return width + padding * 2
	}
	
	@objc func resizePaper() {
		var frame = pageView.frame
		frame.size.height = textContainer.size.height
		frame.size.width = self.documentWidth + textContainerInset.left + textContainerInset.right + BeatUITextView.linePadding()
		
		pageView.frame = frame
	}
	
	@objc func resize() {
		guard let enclosingScrollView = self.enclosingScrollView else {
			print("WARNING: No scroll view set for text view")
			return
		}
		
		let containerHeight = textContainer.size.height + textContainerInset.top + textContainerInset.bottom
		
		self.textContainer.size = CGSize(width: self.documentWidth, height: containerHeight)
		self.textContainerInset = insets
		
		var frame = pageView.frame
		var zoom = enclosingScrollView.zoomScale
		
		if (frame.height * zoom < enclosingScrollView.frame.height) {
			var targetHeight = frame.height
			if (self.frame.height < enclosingScrollView.frame.height) {
				targetHeight = enclosingScrollView.frame.height
			}
			let factor = targetHeight / enclosingScrollView.frame.height
			zoom = enclosingScrollView.zoomScale / factor
		}
		
		// Center the page view
		var x = (enclosingScrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0 }
		frame.origin.x = x
		
		resizeScrollViewContent()
				
		frame.size.width = zoom * (self.documentWidth + self.insets.left + self.insets.right)
		frame.size.height = enclosingScrollView.contentSize.height
		
		self.pageView.frame = frame
		
		var textViewFrame = self.frame
		textViewFrame.origin.x = 0.0
		textViewFrame.size.width = self.documentWidth + self.insets.left + self.insets.right
		self.frame = textViewFrame
		
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.enclosingScrollView.zoomScale = zoom
		} completion: { _ in
		}
	}
	
	
	// MARK: - Dialogue input
	
	func shouldCancelCharacterInput() -> Bool {
		guard let editorDelegate = self.editorDelegate else { return false }
		let line = editorDelegate.currentLine()
		
		/// We'll return `true` when the current line is empty
		if editorDelegate.characterInput && line!.string.count == 0 {
			return true
		} else {
			return false
		}
	}
	
	@objc func cancelCharacterInput() {
		guard let editorDelegate = self.editorDelegate else { return }
		
		let line = editorDelegate.characterInputForLine
		
		editorDelegate.characterInput = false
		editorDelegate.characterInputForLine = nil
		
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.firstLineHeadIndent = 0.0
		paragraphStyle.minimumLineHeight = BeatEditorFormatting.editorLineHeight()
		
		let attributes:[NSAttributedString.Key:Any] = [
			NSAttributedString.Key.font: editorDelegate.courier!,
			NSAttributedString.Key.paragraphStyle: paragraphStyle
		]
		
		self.typingAttributes = attributes
		self.setNeedsDisplay()
		self.setNeedsLayout()
		
		editorDelegate.setTypeAndFormat(line, type: .empty)
	}
		

	// MARK: - Rects for ranges
	
	@objc func rectForRange (range: NSRange) -> CGRect {
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		let rect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
		
		return rect
	}
	
	
	// MARK: - Touch events
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesBegan(touches, with: event)
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesMoved(touches, with: event)
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		for touch in touches {
			touch.location(in: self.enclosingScrollView)
		}
		super.touchesEnded(touches, with: event)
	}

	
	// MARK: - Update assisting views
	
	@objc func updateAssistingViews () {
		guard let editorDelegate = self.editorDelegate
		else { return }
		
		if (editorDelegate.currentLine().isAnyParenthetical()) {
			self.autocapitalizationType = .none
		} else {
			self.autocapitalizationType = .sentences
		}
		
		assistantView?.reloadData()
	}
	
	
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
		
		guard let line = editorDelegate?.currentLine() else { return UIMenu(children: actions) }
		
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
		
		let sceneMenu = UIMenu(title: "Scene...", options: [], children: [
			UIAction(title: "Omit Scene") { _ in
				self.editorDelegate?.formattingActions.omitScene(nil)
			},
			UIAction(title: "Make Non-Numbered") { _ in
				self.editorDelegate?.formattingActions.makeSceneNonNumbered(nil)
			},
			UIAction(image: UIImage(named:"Color_Red")) { _ in
				self.editorDelegate?.setColor("red", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Blue")) { _ in
				self.editorDelegate?.setColor("blue", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Green")) { _ in
				self.editorDelegate?.setColor("green", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Pink")) { _ in
				self.editorDelegate?.setColor("pink", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Brown")) { _ in
				self.editorDelegate?.setColor("brown", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Cyan")) { _ in
				self.editorDelegate?.setColor("cyan", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Orange")) { _ in
				self.editorDelegate?.setColor("orange", for: self.editorDelegate?.currentScene)
			},
			UIAction(image: UIImage(named:"Color_Magenta")) { _ in
				self.editorDelegate?.setColor("magenta", for: self.editorDelegate?.currentScene)
			}
		])
		
		actions.append(sceneMenu)
				
		// Add remaining actions from original menu
		actions.append(contentsOf: originalActions)
		
		let menu = UIMenu(children: actions)
		
		return menu
	}
		
}

// MARK: - Layout manager delegate

// Manual memory management ahead, dread lightly.

extension BeatUITextView: NSLayoutManagerDelegate {
	func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: UIFont, forGlyphRange glyphRange: NSRange) -> Int {
		if self.editorDelegate?.documentIsLoading ?? false { return 0 }
		
		let line = editorDelegate?.parser.line(atPosition: charIndexes[0])
		if line == nil {
			return 0
		}
		
		let type = line?.type
		if type == .section { return 0; }

		// Markdown indices
		let mdIndices:NSMutableIndexSet = NSMutableIndexSet(indexSet: line!.formattingRanges(withGlobalRange: true, includeNotes: false))
		
		// Add scene number range to markup indices
		if line!.sceneNumberRange.length > 0 {
			let sceneNumberRange = NSMakeRange(Int(line!.position) + Int(line!.sceneNumberRange.location), line!.sceneNumberRange.length)
			mdIndices.add(in: sceneNumberRange)
		}
		
		// Add possible color range to markup indices
		if line!.colorRange.length > 0 {
			let colorRange = NSMakeRange(Int(line!.position) + line!.colorRange.location, line!.colorRange.length)
			mdIndices.add(in: colorRange)
		}
				
		// perhaps do nothing
		if mdIndices.count == 0 &&
			!(type == .heading || type == .transitionLine || type == .character) &&
			!(line!.string.containsOnlyWhitespace() && line!.string.count > 1) {
			return 0
		}
		
		let location = charIndexes[0]
		let length = glyphRange.length
		
		let start = text.index(text.startIndex, offsetBy: location)
		let end = text.index(text.startIndex, offsetBy: location + length)
		let strRange = start..<end
		let subString = String(textStorage.string[strRange])
		let str = subString as CFString
		
		if subString == "\n" {
			return 0
		}
		
		// Create a mutable copy
		var modifiedStr = CFStringCreateMutable(nil, CFStringGetLength(str));
		CFStringAppend(modifiedStr, str);
		
		if (type == .heading || type == .transitionLine) {
			// Uppercase
			CFStringUppercase(modifiedStr, nil)
		}
				
		//let glyphProperty = NSLayoutManager.GlyphProperty()
		
		if line!.string.containsOnlyWhitespace() {
			CFStringFindAndReplace(modifiedStr, " " as CFString, "•" as CFString, CFRangeMake(0, CFStringGetLength(modifiedStr)), CFStringCompareFlags.init(rawValue: 0))
			let newGlyphs = GetGlyphsForCharacters(font: aFont as CTFont, string: modifiedStr!)
			layoutManager.setGlyphs(newGlyphs, properties:props, characterIndexes:charIndexes, font:aFont, forGlyphRange: glyphRange)
			
			free(newGlyphs)
		}
		else {
			let newGlyphs = GetGlyphsForCharacters(font: aFont as CTFont, string: modifiedStr!)
			layoutManager.setGlyphs(newGlyphs, properties: props, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
			newGlyphs.deallocate()
		}
		
		modifiedStr = nil
		return glyphRange.length
	}
	
	func GetGlyphsForCharacters(font:CTFont, string:CFString) -> UnsafeMutablePointer<CGGlyph> {
		let count = CFStringGetLength(string)

		let characters = UnsafeMutablePointer<unichar>.allocate(capacity: count)
		let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: count)
				
		CFStringGetCharacters(string, CFRangeMake(0, count), characters)
		CTFontGetGlyphsForCharacters(font, characters, glyphs, count);
		
		characters.deallocate()
		
		return glyphs
	}
}


// MARK: - Scroll view delegation

extension BeatUITextView: UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return pageView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		//
	}
	
	func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		var x = (scrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0; }
		
		var frame = pageView!.frame
		frame.origin.x = x
		
		var zoom = scrollView.zoomScale
		
		if (frame.height < scrollView.frame.height) {
			let factor = frame.height / scrollView.frame.height
			zoom = scrollView.zoomScale / factor
		}
		
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.pageView.frame = frame
			self.enclosingScrollView.zoomScale = zoom
		} completion: { _ in
			
		}
	}
	
	@objc func resizeScrollViewContent() {
		let layoutManager = self.layoutManager
		let inset = self.textContainerInset
		
		// Calculate the index of the last glyph that fits within the available height
		var lastGlyphIndex = layoutManager.numberOfGlyphs - 1
		if (lastGlyphIndex < 0) { lastGlyphIndex = 0 }

		// Get the rectangle of the line fragment that contains the last glyph
		var lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
		var lastLineY = lastLineRect.maxY
		if lastLineRect.origin.y == 0.0 {
			lastLineRect = layoutManager.extraLineFragmentRect
			lastLineY = lastLineRect.maxY * -1
		}
		
		let factor = self.enclosingScrollView.zoomScale
		let contentSize = CGSize(width: self.documentWidth, height: lastLineY)
		var scrollSize = CGSize(width: (contentSize.width + inset.left + inset.right) * factor,
								height: (contentSize.height + inset.top + inset.bottom) * factor)

		if scrollSize.height * factor < self.enclosingScrollView.frame.height {
			scrollSize.height = self.enclosingScrollView.frame.height - ((inset.top - inset.bottom) * factor)
		}
		
		let heightNow = self.enclosingScrollView.contentSize.height
		
		// Adjust the size to fit, if the size differs more than 5.0 points
		if (scrollSize.height < heightNow - 5.0 || scrollSize.height > heightNow + 5.0) {
			scrollSize.height += 12.0
			self.enclosingScrollView.contentSize = scrollSize
		}
		
	}
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }
		
		if key.keyCode == .keyboardTab {
			editorDelegate?.handleTabPress()
			return
		}
		else if key.keyCode == .keyboardDeleteOrBackspace {
			// Check if we should cancel character input
			if self.shouldCancelCharacterInput() {
				self.cancelCharacterInput()
				return
			}
		}
		
		super.pressesBegan(presses, with: event)
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }

		switch key.keyCode {
		case .keyboardTab:
			return
			
		default:
			super.pressesEnded(presses, with: event)
		}
	}
}


// MARK: - Input assistant buttons

extension BeatUITextView {
	func setupInputAssistantButtons() {
		self.assistantView?.leadingActions = [
			InputAssistantAction(image: UIImage(systemName: "bubble.left.fill")!, target: self, action: #selector(addCue)),
			InputAssistantAction(image: UIImage(named: "Shortcut.INT")!, target: self, action: #selector(addINT)),
			InputAssistantAction(image: UIImage(named: "Shortcut.EXT")!, target: self, action: #selector(addEXT))
		]
		self.assistantView?.trailingActions = [
			InputAssistantAction(image: UIImage(systemName: "arrow.uturn.backward")!, target: self, action: #selector(undo))
		]
	}
	
	@objc func addINT() {
		self.editorDelegate?.textActions.addNewParagraph("INT.")
	}
	
	@objc func addEXT() {
		self.editorDelegate?.textActions.addNewParagraph("EXT.")
	}
	
	@objc func addCue() {
		self.editorDelegate?.formattingActions.addCue()
	}
	
	@objc func undo() {
		self.editorDelegate?.undoManager.undo()
	}
	
	@objc func redo() {
		self.editorDelegate?.undoManager.redo()
	}
	
	func inputAssistantView(_ inputAssistantView: InputAssistantView, didSelectSuggestion suggestion: String) {
		guard let editorDelegate = self.editorDelegate else { return }
		
		if suggestion[0] == "(" && editorDelegate.currentLine().isAnyCharacter() {
			// This is a character extension
			editorDelegate.textActions.addCueExtension(suggestion, on: editorDelegate.currentLine())
		} else {
			// This is something else
			let r = NSMakeRange(editorDelegate.currentLine().position, editorDelegate.currentLine().length)
			editorDelegate.replace(r, with: suggestion)
		}
	}
}


// MARK: - Assisting views

class BeatPageView:UIView {
	override func awakeFromNib() {
		super.awakeFromNib()
		
		layer.shadowRadius = 3.0
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.2
		layer.shadowOffset = .zero
	}
}

class BeatScrollView: UIScrollView {
	
}
