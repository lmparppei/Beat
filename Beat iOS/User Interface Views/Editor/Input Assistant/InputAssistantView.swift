//
//  InputAssistantView.swift
//  InputAssistant
//
//  Created by Ian McDowell on 1/28/18.
//  Copyright © 2018 Ian McDowell. All rights reserved.
//  Modified for Beat iOS, Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

enum BeatInputAssistantMode {
	case writing
	case editing
}

/// A button to be displayed in on the leading or trailing side of an input assistant.
public struct InputAssistantAction {
	
	/// Image to display to the user. Will be resized to fit the height of the input assistant.
	public let image: UIImage?
	
	public let title: String
	
	public weak var target: AnyObject?
	public let action: Selector?
	
	public var menu:UIMenu?
	
	public init(title:String = "", image: UIImage?, target: AnyObject? = nil, action: Selector? = nil, menu:UIMenu? = nil) {
		self.image = image; self.target = target; self.action = action; self.title = title; self.menu = menu;
	}
}

public protocol InputAssistantViewDataSource:NSObject {
	
	/// Text to display when there are no suggestions.
	func textForEmptySuggestionsInInputAssistantView() -> String?
	
	/// Number of suggestions to display
	func numberOfSuggestionsInInputAssistantView() -> Int
	
	/// Return information about the suggestion at the given index
	func inputAssistantView(_ inputAssistantView: InputAssistantView, nameForSuggestionAtIndex index: Int) -> String
}

/// Delegate to receive notifications about user actions in the input assistant view.
public protocol InputAssistantViewDelegate:NSObject {
	/// When the user taps on a suggestion
	func inputAssistantView(_ inputAssistantView: InputAssistantView, didSelectSuggestion suggestion: String)
	func shouldShowSuggestions() -> Bool
}


// MARK: - Autocomplete data source

/// Data source for autocomplete suggestions
public class AutocompletionDataSource:NSObject, InputAssistantViewDataSource {
	var autocompletion:BeatAutocomplete
	weak var delegate:BeatEditorDelegate?
	
	var currentResults:[String] = []
	var prevLine:Line?
	var prevLineType:LineType = .empty
	
	public init(editorDelegate:BeatEditorDelegate) {
		self.autocompletion = BeatAutocomplete()
		self.autocompletion.delegate = editorDelegate
		self.delegate = editorDelegate
		
		super.init()
	}
		
	public func textForEmptySuggestionsInInputAssistantView() -> String? {
		return nil
	}
	
	public func numberOfSuggestionsInInputAssistantView() -> Int {
		guard let line = delegate?.currentLine, let delegate = self.delegate else { return 0 }
		
		// If the currently edited line has changed, we'll refresh the results
		if line != prevLine || prevLineType != line.type {
			currentResults.removeAll()
			
			if line.isAnyCharacter() {
				autocompletion.collectCharacterNames()
			} else {
				autocompletion.collectHeadings()
			}
		}
		
		// Get partial results
		let range = NSMakeRange(line.position, NSMaxRange(delegate.selectedRange) - line.position)
		currentResults = autocompletion.completions(forPartialWordRange: range)
		
		// Special character cue rules
		if line.isAnyCharacter() {
			var showExtensions = false
			if currentResults.count == 0 && line.length == 0 {
				// Display every character
				currentResults = self.autocompletion.characterNames.swiftArray()
			} else if (delegate.selectedRange.length == 0 &&
					   ((currentResults.count > 0 && currentResults.first! == line.string) ||
						(currentResults.count == 0 && line.length > 0))) {
				// If results were empty and/or there was a single result which is the same as the current line, show extensions
				showExtensions = true
			}
			
			// No results, let's add some convenience stuff
			if showExtensions {
				currentResults = ["(CONT'D)", "(V.O.)", "(O.S.)"]
			}
		}
		
		prevLine = line
		prevLineType = line.type
		return currentResults.count
		
	}
	public func inputAssistantView(_ inputAssistantView: InputAssistantView, nameForSuggestionAtIndex index: Int) -> String {
		return currentResults[index]
	}
}


// MARK: - Input assistant toolbar

/// UIToolbar that displays custom suggestions, as well as leading and trailing actions.
open class InputAssistantView: UIToolbar {
	public var fullActions: [InputAssistantAction] = []
	
	deinit {
		print("Input assistant toolbar deinit")
		self.keyboardAppearanceObserver = nil
		self.dSource = nil
	}
	
	/// Returns the number of currently visible suggestions
	@objc
	public var numberOfSuggestions: Int {
		return self.suggestionsCollectionView?.numberOfItems(inSection: 0) ?? 0
	}
	
	/// Actions to display on the leading side of the suggestions.
	public var leadingActions: [InputAssistantAction] = [] {
		didSet {
			self.updateToolbarItems(force: true)
		}
	}
	
	/// Actions to display on the trailing side of the suggestions
	public var trailingActions: [InputAssistantAction] = [] {
		didSet {
			self.updateToolbarItems(force: true)
		}
	}
		
	/// Set this to receive notifications when things happen in the assistant toolbar.
	public weak var assistantDelegate: InputAssistantViewDelegate?
	
	/// Set this to provide data to the input assistant toolbar
	public weak var dataSource: InputAssistantViewDataSource? {
		didSet {
			suggestionsCollectionView?.reloadData()
			updateToolbarItems()
		}
	}
	
	/// The type of display we're currently using. It's either a collection view or buttons.
	private enum InputAssistantType {
		case none
		case buttons
		case suggestions
	}
	
	private var displayMode:InputAssistantType = .none
	
	/// Auto completion data source
	var dSource: AutocompletionDataSource?
	
	/// Collection view, with a horizontally scrolling set of suggestions.
	private var suggestionsCollectionView: InputAssistantCollectionView?
	
	/// Container view for the collection view (used as custom bar button item)
	private var suggestionsContainerView: UIView?
	
	/// Bar button item that holds the suggestions collection view
	private var suggestionsBarItem: UIBarButtonItem?

	/// Tracked suggestion view constraint
	private var suggestionsWidthConstraint: NSLayoutConstraint?

	
	public init(editorDelegate: BeatEditorDelegate, inputAssistantDelegate: InputAssistantViewDelegate?) {
		super.init(frame: .init(origin: .zero, size: .init(width: 0, height: 55)))
		
		self.assistantDelegate = inputAssistantDelegate
				
		// Set up suggestions collection view
		setupSuggestionsView()
		
		// Initialize data source (what's the trick here? retain issues?)
		self.dSource = AutocompletionDataSource(editorDelegate: editorDelegate)
		self.dataSource = self.dSource
		
		// Initial toolbar setup
		updateToolbarItems()
	}
	
	public required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupSuggestionsView() {
		// Create collection view
		let collectionView = InputAssistantCollectionView()
		collectionView.inputAssistantView = self
		collectionView.delegate = self
		collectionView.setContentHuggingPriority(.defaultLow, for: .horizontal)
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		
		// Use the subclass instead of plain UIView
		let containerView = SuggestionsContainerView()
		containerView.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(collectionView)
		
		NSLayoutConstraint.activate([
			collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			collectionView.topAnchor.constraint(equalTo: containerView.topAnchor),
			collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
		])
		
		// No height constraint needed — intrinsicContentSize handles it
		self.suggestionsCollectionView = collectionView
		self.suggestionsContainerView = containerView
		// Create bar button item with the container
		self.suggestionsBarItem = UIBarButtonItem(customView: containerView)
		
	}
	
	public func reloadData() {
		guard let suggestionsCollectionView else { return }
		
		suggestionsCollectionView.reloadData()
		updateToolbarItems()
	}
	
	/// The keyboard appearance of the attached text input
	internal var keyboardAppearance: UIKeyboardAppearance? = .default {
		didSet {
			switch keyboardAppearance {
			case .dark:
				self.tintColor = .white
				self.barTintColor = .black.withAlphaComponent(0.85)
			default:
				self.tintColor = .black
				self.barTintColor = .white.withAlphaComponent(0.85)
			}
		}
	}
	
	private var keyboardAppearanceObserver: NSKeyValueObservation?
	
	/// Attach the inputAssistant to the given UITextView.
	public func attach(to textInput: UITextView) {
		self.keyboardAppearance = textInput.keyboardAppearance
		
		// Hide default undo/redo/etc buttons
		textInput.inputAssistantItem.leadingBarButtonGroups = []
		textInput.inputAssistantItem.trailingBarButtonGroups = []
		
		// Add the input assistant toolbar as an accessory view
		textInput.inputAccessoryView = self
		
		keyboardAppearanceObserver = textInput.observe(\UITextView.keyboardAppearance) { [weak self] textInput, _ in
			self?.keyboardAppearance = textInput.keyboardAppearance
		}
	}
	
	public func detach(from textInput: UITextView) {
		NotificationCenter.default.removeObserver(self)
		if let suggestionsCollectionView {
			NotificationCenter.default.removeObserver(suggestionsCollectionView)
		}
		
		self.leadingActions.removeAll()
		self.trailingActions.removeAll()
		
		self.suggestionsCollectionView?.dataSource = nil
		self.dataSource = nil
		self.dSource = nil
		
		self.suggestionsCollectionView?.delegate = nil
		self.suggestionsCollectionView?.dataSource = nil
		self.suggestionsCollectionView?.inputAssistantView = nil
		self.suggestionsCollectionView?.widthConstraint?.isActive = false
		self.suggestionsCollectionView?.widthConstraint = nil
		self.suggestionsCollectionView?.removeFromSuperview()
		self.suggestionsCollectionView = nil
		
		self.suggestionsContainerView?.removeFromSuperview()
		self.suggestionsContainerView = nil
		self.suggestionsBarItem = nil
		
		self.keyboardAppearanceObserver?.invalidate()
		self.keyboardAppearanceObserver = nil
	}
	
	open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateToolbarItems()
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()
		updateSuggestionsWidth()
	}

	private func updateSuggestionsWidth() {
		guard let containerView = suggestionsContainerView else { return }
		let padding: CGFloat = 16
		let availableWidth = bounds.width - padding
		guard availableWidth > 0 else { return }

		suggestionsWidthConstraint?.isActive = false
		let widthConstraint = containerView.widthAnchor.constraint(equalToConstant: availableWidth)
		widthConstraint.priority = UILayoutPriority(999)
		widthConstraint.isActive = true
		suggestionsWidthConstraint = widthConstraint
	}
			
	/// Update the toolbar items based on current actions and suggestions visibility.
	private func updateToolbarItems(force: Bool = false) {
		// Determine if we should show suggestions or not. We'll also update the display mode to determine if we should update all the items or not.
		let hasSuggestions = (suggestionsCollectionView?.numberOfItems(inSection: 0) ?? 0) > 0
		let shouldShowSuggestions = hasSuggestions && (assistantDelegate?.shouldShowSuggestions() ?? false)
				
		var items: [UIBarButtonItem]?
		var empty = true
		
		if shouldShowSuggestions {
			items = []
			
			if let suggestionsBarItem = suggestionsBarItem {
				items?.append(suggestionsBarItem)
				items?.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)) // Fill the rest with empty space. Seems to fix some positioning problems.
			}
			
			empty = false
			displayMode = .suggestions
			
		} else if force || self.items == nil || self.items?.count == 0 || displayMode != .buttons {
			// Show leading and trailing actions (no suggestions)
			items = []
			
			// Leading actions
			if !leadingActions.isEmpty {
				let leadingButtons = createBarButtonItems(from: leadingActions)
				items?.append(contentsOf: leadingButtons)
				empty = false
			}
			
			// Flexible space between leading and trailing
			items?.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
			
			// Trailing actions
			if !trailingActions.isEmpty {
				let trailingButtons = createBarButtonItems(from: trailingActions)
				items?.append(contentsOf: trailingButtons)
				empty = false
			}
			
			displayMode = .buttons
		}
		
		if let items, items.count > 0, !empty {
			self.setItems(items, animated: false)
		} else {
			//self.items?.removeAll()
			//displayMode = .none
		}
	}
	
	/// Create UIBarButtonItems from InputAssistantActions
	private func createBarButtonItems(from actions: [InputAssistantAction]) -> [UIBarButtonItem] {
		return actions.map { action in
			let barItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
			
			if action.title.count > 0 {
				// Text button
				barItem.title = action.title
			} else if let image = action.image {
				// Image button
				let width = (image.size.width / image.size.height) * 25
				let scaledImage = image.scaled(toSize: CGSize(width: width, height: 25))
				barItem.image = scaledImage
			}
			
			if let menu = action.menu {
				barItem.menu = menu
			} else {
				barItem.action = action.action
				barItem.target = action.target
			}
			
			return barItem
		}
	}
}

extension InputAssistantView: UICollectionViewDelegate {
	/// Manually trigger selection in the suggestions list.
	@objc public func selectItem(at index:Int) {
		guard let suggestionsCollectionView else { return }
		if suggestionsCollectionView.numberOfItems(inSection: 0) > 0 {
			self.collectionView(suggestionsCollectionView, didSelectItemAt: IndexPath(item: index, section: 0))
		}
	}
	
	/// Select a suggestion item using hardware keyboard
	@objc public func selectHighlightedItem() {
		guard let suggestionsCollectionView else { return }
		let index = suggestionsCollectionView.highlightedItem
		guard index >= 0 else { return }
		
		selectItem(at: index)
	}
	
	@objc public func deselectHighlightedItem() {
		guard let suggestionsCollectionView else { return }
		suggestionsCollectionView.highlightedItem = -1
	}
	
	/// Collection view delegate method for picking items. Sent forward to input assistant view delegate.
	public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		UIDevice.current.playInputClick()
		collectionView.deselectItem(at: indexPath, animated: true)
		
		if let item = self.dataSource?.inputAssistantView(self, nameForSuggestionAtIndex: indexPath.last ?? NSNotFound) as? String {
			self.assistantDelegate?.inputAssistantView(self, didSelectSuggestion: item)
		}
	}
	
	public func highlightNextSuggestion() {
		self.suggestionsCollectionView?.highlightNext()
	}
	
	public func highlightPreviousSuggestion() {
		self.suggestionsCollectionView?.highlightPrevious()
	}
	
	var highlightedSuggestion:Int {
		return self.suggestionsCollectionView?.highlightedItem ?? 0
	}
}

extension InputAssistantView: UIInputViewAudioFeedback {
	
	public var enableInputClicksWhenVisible: Bool { return true }
}

// A container that defers width to layout but declares its height
final class SuggestionsContainerView: UIView {
	override var intrinsicContentSize: CGSize {
		// Width is flexible (noIntrinsicMetric), height is fixed
		return CGSize(width: UIView.noIntrinsicMetric, height: 44)
	}
}
