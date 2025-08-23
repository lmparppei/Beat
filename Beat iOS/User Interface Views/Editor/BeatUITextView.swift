//
//  BeatUITextView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 A port of sorts of the sprawling and messy `BeatTextView` class for iOS.
 Conforms to `BeatTextEditor` protocol and provides some cross-platform stuff such as `documentWidth` and scrolling methods.
 
 */

import UIKit
import BeatCore
import BeatParsing

@objc protocol BeatTextEditorDelegate:BeatEditorDelegate {
	@objc var revisionTracking:BeatRevisions { get }
	@objc var formattingActions:BeatEditorFormattingActions { get }
	@objc var textActions:BeatTextIO { get }
	@objc var formatting:BeatEditorFormatting { get }
	
	//@property (nonatomic, weak) IBOutlet UIBarButtonItem* screenplayButton;
	@objc var screenplayButton:UIBarButtonItem? { get }
	@objc var dismissKeyboardButton:UIBarButtonItem? { get }
	
	@objc func textViewDidEndSelection(_ textView:UITextView, selectedRange:NSRange)
	
	func loadFonts()
}

@objc class BeatUITextView: UITextView, BeatTextEditor, UIEditMenuInteractionDelegate {
	
	@IBOutlet weak var editorDelegate:BeatTextEditorDelegate?
	@IBOutlet weak var enclosingScrollView:BeatScrollView!
	@IBOutlet weak var pageView:UIView!
		
	/// Modifier flags are set during key press events and cleared afterwards. This helps with macOS class interop.
	@objc public var modifierFlags:UIKeyModifierFlags = []
	/// The input assistant view on top of keyboard
	@objc public var assistantView:InputAssistantView?
	
	@objc public var floatingCursor = false
	
	var insets:UIEdgeInsets = UIEdgeInsets(top: 50, left: 0, bottom: 50, right: 0)
	var pinchRecognizer = UIGestureRecognizer()
	var customLayoutManager:BeatLayoutManager
	
	var mobileMode:Bool { return UIDevice.current.userInterfaceIdiom == .phone }
	var mobileKeyboardManager:KeyboardManager?
	
	var mobileDismissButton:UIBarButtonItem?
	
	@IBOutlet weak var viewController:UIViewController?
	var lastOffsetY:CGFloat = 0.0
		
	var inputAssistantMode:BeatInputAssistantMode = .writing {
		didSet {
			self.setupInputAssistantButtons()
			self.assistantView?.reloadData()
		}
	}
	
	override var typingAttributes: [NSAttributedString.Key : Any] {
		get {
			return super.typingAttributes
		}
		set {
			if self.textStorage.isEditing { self.textStorage.endEditing() }
			super.typingAttributes = newValue
		}
	}
	
	/// Input assistant buttons for different modes. Set in an extension.
	var inputAssistantButtons:[BeatInputAssistantMode:[InputAssistantAction]] = [:]
	
	class func linePadding() -> CGFloat {
		// We'll use very tight padding for iPhone
		if UIDevice.current.userInterfaceIdiom == .phone {
			return 30.0
		} else {
			return 70.0
		}
	}
	
	// MARK: - Initializers
	
	/// This class function creates and sets up the main editor text view. We can't create a text view in IB, because layout manager can't be replaced when initializing through `NSCoder`.
	@objc class func createTextView(editorDelegate:BeatEditorDelegate, frame:CGRect, pageView:BeatPageView, scrollView:BeatScrollView) -> BeatUITextView {
		// First create core text system
		let textContainer = NSTextContainer()
		let layoutManager = BeatLayoutManager(delegate: editorDelegate)
		let textStorage = NSTextStorage(string: "")
		
		// Set up layout manager & text storage
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)
		layoutManager.delegate = layoutManager
		
		// Create the text view and connect the container + layout manager
		let textView = BeatUITextView(frame: frame, textContainer: textContainer, layoutManager: layoutManager)
		textView.autoresizingMask = [.flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		
		// Set up the container views
		textView.pageView = pageView
		textView.enclosingScrollView = scrollView
		
		// Set up assistant view
		textView.assistantView = InputAssistantView(editorDelegate: editorDelegate, inputAssistantDelegate: textView)
		textView.assistantView?.attach(to: textView)
		
		// The same object will be responsible for all of these delegations
		textView.editorDelegate = editorDelegate as? BeatTextEditorDelegate
		textView.delegate = editorDelegate as? UITextViewDelegate
		textView.inputDelegate = editorDelegate as? UITextInputDelegate
		
		textView.setup()
		
		return textView
	}
	
	init(frame: CGRect, textContainer: NSTextContainer?, layoutManager:BeatLayoutManager) {
		customLayoutManager = layoutManager
		super.init(frame: frame, textContainer: textContainer)
	}
		
	/// This initializer is useless. For some reason, you can't replace the layout manager when using `NSCoder`.
	required init?(coder: NSCoder) {
		customLayoutManager = BeatLayoutManager()
		super.init(coder: coder)
		
		self.textStorage.removeLayoutManager(self.textStorage.layoutManagers.first!)
		
		customLayoutManager.addTextContainer(self.textContainer)
		customLayoutManager.textStorage = self.textStorage
		
		self.textContainer.replaceLayoutManager(customLayoutManager)
	}
	
	
	// MARK: - Layout manager
	
	/// Returns TextKit 1 layout manager
	override var layoutManager: NSLayoutManager {
		return customLayoutManager
	}
	
	/// Returns `nil` to force TextKit 1 compatibility mode. Why? Because we're using the same `NSLayoutManager` on both iOS and macOS, and the desktop version tries to stay compatible all the way down to 10.14.
	override var textLayoutManager: NSTextLayoutManager? {
		return nil
	}

	
	
	// MARK: - Setup
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setup()
	}
	
	func setup() {
		// Delegates
		enclosingScrollView?.delegate = self
		
		self.enclosingScrollView.keyboardDismissMode = .onDrag
		
		// Text container setup
		self.textContainer.widthTracksTextView = false
		self.textContainer.heightTracksTextView = false
		
		// Set text container size. Note that in mobile mode, this varies!
		self.textContainer.size = CGSize(width: self.documentWidth, height: self.textContainer.size.height)
		self.textContainer.lineFragmentPadding = BeatUITextView.linePadding()
		
		// Text view behavior
		self.smartDashesType = .no
		self.smartQuotesType = .no
		self.smartInsertDeleteType = .no
		self.keyboardAppearance = .dark
		
		resizePaper()
		resize()
		
		setupInputAssistantButtons()
		
		if !mobileMode {
			// Tablet setup. We'll have an external scroll view on iPad, so let's disable scroll for text view.
			isScrollEnabled = false
			self.textContainerInset = insets
		} else {
			// Mobile mode setup
			self.contentInsetAdjustmentBehavior = .automatic
			
			self.mobileKeyboardManager = KeyboardManager()
			self.mobileKeyboardManager?.delegate = self
			
			// Disable pinch gesture recognizer
			let pinchGestureRecognizer = UIPinchGestureRecognizer(target: nil, action: nil)
			pinchGestureRecognizer.delegate = self
			self.addGestureRecognizer(pinchGestureRecognizer)
		}
		
		// Set a new frame for this view for mobile mode
		if mobileMode, let contentView = self.enclosingScrollView.superview {
			self.frame = CGRectMake(0.0, 0.0, contentView.frame.width, contentView.frame.height)
			self.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
			
			self.maximumZoomScale = 2.0
			self.minimumZoomScale = 1.0
		}
	}
	
	
	// MARK: - Document view width
	
	@objc var documentWidth:CGFloat {
		var width = 0.0
		let padding = BeatUITextView.linePadding()
		
		guard let delegate = self.editorDelegate else { return 0.0 }
		
		if delegate.pageSize == .A4 {
			width = BeatFontManager.characterWidth * 60
		} else {
			width = BeatFontManager.characterWidth * 62
		}
		
		width += padding * 2
		
		// For iPhone, we'll fit the viewport to view
		if mobileMode {
			let availableWidth = self.frame.size.width * (1/self.zoomScale)
			width = min(availableWidth, width)
		}
		
		return width
	}
	
	private var isUpdatingLayout = false
	override func layoutSubviews() {
		super.layoutSubviews()
		
		// Avoid infinite loop
		guard !isUpdatingLayout else { return }
		
		isUpdatingLayout = true
		mobileViewResize()
		isUpdatingLayout = false
	}
	
	
	// MARK: - Caret drawing
	
	/// Because iOS draws the caret to fill line fragment rects, we need to do some additional math. We'll need to get both font and paragraph styles at given position and do some additional calculations.
	override func caretRect(for position: UITextPosition) -> CGRect {
		var rect = super.caretRect(for: position)
		let offset = offset(from: beginningOfDocument, to: position)
		
		guard let text = self.attributedText,
			  offset < text.length,
			  let line = self.editorDelegate?.parser.line(at: offset)
		else { return rect }
	
		
		let attrs = text.attributes(at: line.position, effectiveRange: nil)
		
		// Adjust the rect using font and paragraph style
		if let pStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
			// Caret should be a little higher than the line itself
			let caretHeight = pStyle.maximumLineHeight * 1.1
			let yOffset = caretHeight - pStyle.maximumLineHeight
			
			rect.origin.y += pStyle.paragraphSpacingBefore + (yOffset / 2)
			rect.size.height = caretHeight
		}
		
		return rect
	}
	
	
	// MARK: - Scroll to range
	
	@objc func scroll(to line: Line!) {
		selectAndScroll(to: line.textRange())
	}
	
	func scroll(to range: NSRange) {
		self.scroll(to:range, animated: true)
	}
	
	func scroll(to range: NSRange, animated:Bool = true) {
		if mobileMode {
			super.scrollRangeToVisible(range)
			return
		}
		
		// Current bounds
		let bounds = self.enclosingScrollView.bounds
		
		// The *actually* visible frame (why won't iOS give this automatically?)
		let visible = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.width, bounds.height - self.enclosingScrollView.adjustedContentInset.bottom - self.enclosingScrollView.contentInset.bottom)
		
		// Current selection frame
		var selectionRect = self.rectForRange(range: self.selectedRange)
		if selectionRect.size.width < 1.0 { selectionRect.size.width += 1.0 }
		
		// Account for top margin
		selectionRect.origin.y += self.textContainerInset.top
		
		let scaledRect = convert(selectionRect, to: self.enclosingScrollView)
		
		// If the rect is not visible, scroll to that range
		if CGRectIntersection(scaledRect, visible).height < 16.0 {
			self.enclosingScrollView.safelyScrollRectToVisible(scaledRect, animated: animated)
		}
		
	}
	
	override func scrollRangeToVisible(_ range: NSRange) {
		self.scroll(to:range)
		//super.scrollRangeToVisible(range)
	}
	
	func scroll(to range: NSRange, callback callbackBlock: (() -> Void)!) {
		scroll(to: range)
		callbackBlock()
	}
	
	func scroll(to scene: OutlineScene!) {
		selectAndScroll(to: scene.line.textRange())
	}
	
	@objc func selectAndScroll(to range:NSRange) {
		self.selectedRange = NSMakeRange(NSMaxRange(range), 0)
		self.scroll(to: range)
	}

	
	// MARK: - Dialogue input
	
	func shouldCancelCharacterInput() -> Bool {
		guard let editorDelegate = self.editorDelegate,
			  let line = editorDelegate.currentLine
		else { return true }
		
		/// We'll return `true` when current line is empty (what is this)
		return (editorDelegate.characterInput && line.string.count == 0)
	}
	
	@objc func cancelCharacterInput() {
		guard let editorDelegate = self.editorDelegate, let currentLine = editorDelegate.currentLine else { return }

		let line = editorDelegate.characterInputForLine

		var shouldCancel = true
		
		if editorDelegate.characterInputForLine != nil, currentLine.position == NSMaxRange(editorDelegate.characterInputForLine.range()) {
			shouldCancel = false
		}
		
		editorDelegate.characterInput = false
		editorDelegate.characterInputForLine = nil
		
		// Uh... well, yeah.
		if !shouldCancel { return }
				
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.firstLineHeadIndent = 0.0
		paragraphStyle.minimumLineHeight = self.editorDelegate?.editorStyles.page().lineHeight ?? 12.0
		
		let attributes:[NSAttributedString.Key:Any] = [
			NSAttributedString.Key.font: editorDelegate.fonts.regular,
			NSAttributedString.Key.paragraphStyle: paragraphStyle
		]
		
		self.updateAssistingViews()
		
		self.typingAttributes = attributes
		self.setNeedsDisplay()
		self.setNeedsLayout()
		
		if line?.length == 0 {
			editorDelegate.setTypeAndFormat(line, type: .empty)
		}
	}
		
	// MARK: - Rects for ranges
	
	@objc func rectForRange (range: NSRange) -> CGRect {
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		let rect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
		
		return rect
	}
	
	
	// MARK: - Touch events
	
	var selectedRangeBeforeTouch = NSRange(location: -1, length: 0)
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		if !mobileMode {
			for touch in touches {
				touch.location(in: self.enclosingScrollView)
			}
		}
		
		super.touchesBegan(touches, with: event)
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		if !mobileMode {
			for touch in touches {
				touch.location(in: self.enclosingScrollView)
			}
		}
		
		super.touchesMoved(touches, with: event)
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		// Convert to enclosing scroll view coordinate
		if !mobileMode {
			for touch in touches {
				touch.location(in: self.enclosingScrollView)
			}
		}
		
		super.touchesEnded(touches, with: event)
	}
	
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesCancelled(touches, with: event)
	}
	
	override func beginFloatingCursor(at point: CGPoint) {
		super.beginFloatingCursor(at: point)
		
		floatingCursor = true
		self.selectedRangeBeforeTouch = self.selectedRange
	}
	
	override func endFloatingCursor() {
		super.endFloatingCursor()
		
		floatingCursor = false
		
		if self.selectedRangeBeforeTouch != self.selectedRange {
			self.editorDelegate?.textViewDidEndSelection(self, selectedRange: self.selectedRange)
		}
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
				
		var frame = pageView.frame
		frame.origin.x = x
		
		var zoom = scrollView.zoomScale
		
		// Page view will always be at least the height of the screen
		if (frame.height < scrollView.frame.height) {
			let factor = frame.height / scrollView.frame.height
			zoom = scrollView.zoomScale / factor
		}
		
		// Set content scale factor (see UIView+Scale extension)
		// We'll multiply the value with screen native scale. Not sure if this is wise or not.
		let scale = scrollView.zoomScale * UIScreen.main.nativeScale
		scrollView.scaleView(view: scrollView, scale: scale)
		scrollView.scaleLayer(layer: scrollView.layer, scale: scale)
		
		self.scaleView(view: self, scale: scale)
		self.scaleLayer(layer: self.layer, scale: scale)
		
		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) {
			self.pageView.frame.origin.x = frame.origin.x
			
			self.enclosingScrollView.zoomScale = zoom
			self.resizeScrollViewContent()
		} completion: { _ in
			
		}
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }
		
		// First check possible assistant view status and move highlight if needed
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
		} else {
			forceCharacterInput()
		}
	}
	
	func forceCharacterInput() {
		if self.editorDelegate?.characterInput ?? false { return }
		self.editorDelegate?.formattingActions.addCue()
	}
	
	
	//Delegate Methods
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView){
		lastOffsetY = scrollView.contentOffset.y
	}
	
	func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView){
		/*
		let hide = scrollView.contentOffset.y > self.lastOffsetY
		if let vc = self.getViewController() {
			let nc = vc.navigationController
			vc.navigationController?.setToolbarHidden(hide, animated: true)
		}
		*/
	}
}


// MARK: - Gesture recognizer delegate for mobile

extension BeatUITextView:UIGestureRecognizerDelegate {
	override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		if gestureRecognizer is UIPinchGestureRecognizer, mobileMode {
			return false // Disable pinch zoom
		}

		return true
	}
	
	private func adjustTouchPoint(_ point: CGPoint) -> CGPoint {
		return CGPoint(x: point.x / zoomScale, y: point.y / zoomScale)
	}
}


// MARK: - Mobile keyboard manager

extension BeatUITextView:KeyboardManagerDelegate {
	func keyboardWillShow(with size: CGSize, animationTime: Double) {
		let animator = UIViewPropertyAnimator(duration: animationTime, curve: .easeInOut) {
			self.contentInset.bottom = self.keyboardLayoutGuide.layoutFrame.height + self.insets.bottom
		}
		animator.startAnimation()
		//self.contentInset.bottom = self.keyboardLayoutGuide.layoutFrame.height
				
		self.editorDelegate?.dismissKeyboardButton?.isHidden = false
		self.editorDelegate?.screenplayButton?.isHidden = true
	}
	func keyboardDidShow() {
		//self.scroll(to: self.selectedRange, animated: false)
	}
	func keyboardWillHide() {
		self.contentInset.bottom = self.insets.bottom
		self.editorDelegate?.dismissKeyboardButton?.isHidden = true
		self.editorDelegate?.screenplayButton?.isHidden = false
	}
		
	@objc func dismissKeyboard() {
		self.endEditing(true)
	}
}


