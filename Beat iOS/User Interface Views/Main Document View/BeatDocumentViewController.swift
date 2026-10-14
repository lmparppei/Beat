//
//  BeatDocumentViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 26.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

/**
 Preliminary rewrite of the document view controller in Swift. Let's forget about it and fix the old one.
 */

import Foundation
import BeatCore
import UXKit

@objcMembers
public class BeatDocumentViewController:BeatDocumentBaseController, BeatPluginDelegate {

	@IBOutlet weak var scrollView:BeatScrollView?
	@IBOutlet var pageView:BeatPageView?
	@IBOutlet weak var outlineView:BeatiOSOutlineView?
	@IBOutlet weak var splitViewContainer:UIView?
	weak var editorSplitView:BeatEditorSplitViewController?
	
	@IBOutlet weak var sidebar:UIView?
	@IBOutlet weak var topContainerLayoutConstraint:NSLayoutConstraint?
	
	@IBOutlet weak var titleBar:UINavigationItem?
	@IBOutlet weak var screenplayButton:UIBarButtonItem?
	@IBOutlet weak var dismissKeyboardButton:UIBarButtonItem?
	
	public override var pageSize: BeatPaperSize {
		didSet {
			if let textView = textView as? BeatUITextView {
				textView.resize()
			}
		}
	}
	
	var formattingActions:BeatEditorFormattingActions?
	
	/// A lot of things in the current iteration use document from background threads, so we are maintaining a shadow instance.
	override public var document:UIDocument? {
		didSet {
			__fountainDocument = document as? iOSDocument
		}
	}
	
	var fountainDocument:iOSDocument? {
		get {
			return Thread.isMainThread ? self.document as? iOSDocument : self.__fountainDocument
		}
	}
	fileprivate var __fountainDocument:iOSDocument?

	
	// MARK: Editor flags
	public var revisionMode:Bool = false
	public var mode:BeatEditorMode = .EditMode
	/// Set to true in delegate method when text storage is processing an edit
	var processingEdit:Bool = false
	/// The range where that processed __edit to text content__ took place (not attribute changes or anything else)
	public var lastEditedRange:NSRange = NSMakeRange(NSNotFound, 0)
	
	
	// MARK: Preview
	public var previewView:BeatPageViewController?
	var previewTimer:Timer?
	var previewUpdated:Bool = false

	
	// MARK: Private flags
	public var disableFormatting:Bool = false
	
	
	// MARK: Outline
	var outlineProvider:BeatOutlineDataProvider?
	
	
	// MARK: Text
	var formattedTextBuffer:NSMutableAttributedString?
	var typingAttributes:NSDictionary? {
		didSet {
			let attrs = self.typingAttributes as? [NSAttributedString.Key: Any]
			self.textView?.typingAttributes = attrs ?? [:]
		}
	}
	
	var initialFormattingInAction:Bool = false

		
	// MARK: - UI getters
	
	public override func text() -> String {
		guard let textView else { return self.formattedTextBuffer?.string ?? "" }
		
		return Thread.isMainThread ? textView.string : self.attrTextCache?.string ?? ""
	}
		
	@objc public func sidebarVisible() -> Bool {
		return false
	}
	
	public var documentWindow:UXWindow? {
		return self.view.window
	}
	
	
	// MARK: Change count management for cross-platform support
	
	public override func addToChangeCount() {
		self.document?.updateChangeCount(.done)
	}

	public func updateChangeCount(_ change: UIDocument.ChangeKind) {
		self.document?.updateChangeCount(change)
	}
	
	
	// MARK: Editor text view helpers
	
	public var documentWidth:CGFloat {
		if let textView = self.textView as? BeatUITextView {
			return textView.documentWidth
		} else {
			return 0.0
		}
	}
	
	
	// MARK: - Scrolling. This should not be here, but this is how I've decided to live my life.
	
	public func scroll(to scene: OutlineScene) {
		
	}
	
	public func scroll(to line: Line?) {
		if let line {
			self.selectAndScrollTo(range: NSMakeRange(line.position, 0))
		}
	}
	
	public func scroll(toLineIndex index: Int) {
		if let line = self.parser?.line(at: index) {
			self.selectAndScrollTo(range: NSMakeRange(line.position, 0))
		}
	}
	
	public func scroll(toSceneIndex index: Int) {
		if let parser, index < parser.outline.count, let scene = parser.outline[index] as? OutlineScene {
			self.selectAndScrollTo(range: NSMakeRange(NSMaxRange(scene.line.textRange()), 0))
		}
	}
	
	func selectAndScrollTo(range:NSRange) {
		guard let textView = self.textView as? BeatUITextView  else { return }
	
		textView.setSelectedRange(range)
		textView.scroll(to: range, animated: true)
		textView.becomeFirstResponder()
	}
	
	
	
	/*
	 - (void)scrollToSceneNumber:(NSString*)sceneNumber {
		 // Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
		 OutlineScene *scene = [self.parser sceneWithNumber:sceneNumber];
		 if (scene != nil) [self scrollToScene:scene];
	 }
	 - (void)scrollToScene:(OutlineScene*)scene {
		 [self selectAndScrollTo:scene.line.textRange];
	 }
	 /// Legacy method. Use selectAndScrollToRange
	 - (void)scrollToRange:(NSRange)range {
		 [self selectAndScrollTo:range];
	 }

	 - (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock {
		 // BeatTextView *textView = (BeatTextView*)self.textView;
		 // [textView scrollToRange:range callback:callbackBlock];
	 }

	 /// Scrolls the given position into view
	 - (void)scrollTo:(NSInteger)location {
		 NSRange range = NSMakeRange(location, 0);
		 [self selectAndScrollTo:range];
	 }
	 /// Selects the given line and scrolls it into view
	 - (void)scrollToLine:(Line*)line {
		 if (line != nil) [self selectAndScrollTo:NSMakeRange(NSMaxRange(line.textRange), 0)];
	 }
	 /// Selects the line at given index and scrolls it into view
	 - (void)scrollToLineIndex:(NSInteger)index {
		 Line *line = [self.parser.lines objectAtIndex:index];
		 if (line != nil) [self selectAndScrollTo:line.textRange];
	 }
	 /// Selects the scene at given index and scrolls it into view
	 - (void)scrollToSceneIndex:(NSInteger)index {
		 OutlineScene *scene = [self.parser.outline objectAtIndex:index];
		 if (!scene) return;
		 
		 NSRange range = NSMakeRange(scene.line.position, scene.string.length);
		 [self selectAndScrollTo:range];
	 }

	 /// Selects the given range and scrolls it into view
	 - (void)selectAndScrollTo:(NSRange)range
	 {
		 [self focusEditor];
		 
		 self.textView.selectedRange = range;
		 [self.textView scrollToRange:range];
	 }
	 */
	
	
	// MARK: Apply user settings
	
	public func applySettingsAndRefresh() {
		self.formatting?.formatAllLines(of: .heading)
		self.resetPreview()
	}
	
	
	// MARK: Formatting
	
	public override func applyFormatChanges() {
		super.applyFormatChanges()
		//self.textView?.typingAttributes
	}
	
	
	// MARK: Preview
	
	public func resetPreview() {
		
	}
	
	
	// MARK: Printing
	
	public func documentForDelegation() -> Any? {
		return self.fountainDocument
	}
	
	public func printInfo() -> UIPrintInfo {
		return UIPrintInfo()
	}
	
	
	// MARK: General editor stuff
	
	public override func focusEditor() {
		self.textView?.becomeFirstResponder()
	}
	
	public func toggle(_ mode:BeatEditorMode) {
		self.mode = mode
	}
	
	public func hasChanged() -> Bool {
		print("WARNING: Implement hasChanged() on iOS if needed")
		return true
	}
	
	@IBAction public func toggleCards(_ sender:Any?) {
		self.performSegue(withIdentifier: "Cards", sender: sender)
	}
	
	
	// MARK: - Plugin support stub
	
	@IBAction func runPlugin(_ sender:Any?) {
		//
	}
	
	
	// MARK: - Segues
	
	public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "Cards" {
			let vc = segue.destination as? BeatPluginContainerViewController
			vc?.delegate = self
			vc?.pluginName = "Index Card View"
		} else if segue.identifier == "ToEditorSplitView" {
			self.editorSplitView = segue.destination as? BeatEditorSplitViewController
		}
	}
	

}
