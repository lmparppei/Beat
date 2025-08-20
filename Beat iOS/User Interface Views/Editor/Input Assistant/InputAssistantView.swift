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
	
	public let menu:UIMenu?
	
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
			} else if ((currentResults.count > 0 && currentResults.first! == line.string) ||
					(currentResults.count == 0 && line.length > 0)) {
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


// MARK: - Input assistant view

/// UIInputView that displays custom suggestions, as well as leading and trailing actions.
open class InputAssistantView: UIInputView {
	public var fullActions:[InputAssistantAction] = []
	
	/// Returns the number of currently visible suggestions
	@objc
	public var numberOfSuggestions:Int {
		return self.suggestionsCollectionView.numberOfItems(inSection: 0)
	}
	
	/// Actions to display on the leading side of the suggestions.
	public var leadingActions: [InputAssistantAction] = [] {
		didSet {
			self.updateActions(leadingActions, leadingStackView)
		}
	}
	
	/// Actions to display on the trailing side of the suggestions
	public var trailingActions: [InputAssistantAction] = [] {
		didSet { self.updateActions(trailingActions, trailingStackView) }
	}
	
	/// Set this to receive notifications when things happen in the assistant view.
	public weak var delegate: InputAssistantViewDelegate?
	
	/// Set this to provide data to the input assistant view
	public weak var dataSource: InputAssistantViewDataSource? {
		didSet { suggestionsCollectionView.reloadData() }
	}
	
	public var fullMenu:[InputAssistantAction] = []
	public var rightMenu:[InputAssistantAction] = []
	
	var dSource:AutocompletionDataSource?
	
	/// Stack view on the leading side of the collection view. Contains actions.
	private let leadingStackView: UIStackView
	
	/// Stack view on the trailing side of the collection view. Contains actions.
	private let trailingStackView: UIStackView
	
	/// Collection view, with a horizontally scrolling set of suggestions.
	private let suggestionsCollectionView: InputAssistantCollectionView
		
	
	public init(editorDelegate:BeatEditorDelegate, inputAssistantDelegate:InputAssistantViewDelegate?) {
		self.leadingStackView = UIStackView()
		self.trailingStackView = UIStackView()
		self.suggestionsCollectionView = InputAssistantCollectionView()
		
		super.init(frame: .init(origin: .zero, size: .init(width: 0, height: 55)), inputViewStyle: .default)
		
		self.suggestionsCollectionView.inputAssistantView = self
		self.suggestionsCollectionView.delegate = self
		
		for stackView in [leadingStackView, trailingStackView] {
			stackView.spacing = 0.0
			stackView.distribution = .equalCentering
			stackView.alignment = .center
			stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
			stackView.tintColor = .white
			updateActions([], stackView)
		}

		// suggestions stretch to fill
		suggestionsCollectionView.setContentHuggingPriority(.defaultLow, for: .horizontal)
		
		// The stack views are embedded into a container, which lays them out horizontally
		let containerStackView = UIStackView(arrangedSubviews: [leadingStackView, suggestionsCollectionView, trailingStackView])
		containerStackView.alignment = .fill
		containerStackView.axis = .horizontal
		containerStackView.distribution = .equalCentering

		// Stretch to fill bounds
		containerStackView.frame = self.bounds
		self.addSubview(containerStackView)
		containerStackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		
		self.dSource = AutocompletionDataSource(editorDelegate: editorDelegate)
		self.dataSource = self.dSource
		
		self.delegate = inputAssistantDelegate
		
		// iOS 26 won't have an opaque background
		self.layer.backgroundColor = UIColor.black.withAlphaComponent(0.85).cgColor
	}
	
	public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	public func reloadData() {
		guard let delegate else { return }

		suggestionsCollectionView.reloadData()
		
		if suggestionsCollectionView.numberOfItems(inSection: 0) > 0, delegate.shouldShowSuggestions() {
			self.leadingStackView.isHidden = true
		} else {
			self.leadingStackView.isHidden = false
		}
	}

	/// The keyboard appearance of the attached text input
	internal var keyboardAppearance: UIKeyboardAppearance = .default {
		didSet {
			switch keyboardAppearance {
			case .dark: self.tintColor = .white
			default: self.tintColor = .black
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

		// Disable built-in autocomplete
		// textInput.autocorrectionType = .no

		// Add the input assistant view as an accessory view
		textInput.inputAccessoryView = self

		keyboardAppearanceObserver = textInput.observe(\UITextView.keyboardAppearance) { [weak self] textInput, _ in
			self?.keyboardAppearance = textInput.keyboardAppearance
		}
	}

	open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateActions(leadingActions, leadingStackView)
		updateActions(trailingActions, trailingStackView)
	}
	
	/// Remove existing actions, and add new ones to the given leading/trailing stack view.
	private func updateActions(_ actions: [InputAssistantAction], _ stackView: UIStackView) {
		for view in stackView.arrangedSubviews {
			view.removeFromSuperview()
		}

		if actions.isEmpty {
			let emptyView = UIView()
			emptyView.widthAnchor.constraint(equalToConstant: 0).isActive = true
			stackView.addArrangedSubview(emptyView)
		} else {
			let itemWidth: CGFloat = self.traitCollection.horizontalSizeClass == .regular ? 60 : 40
			for action in actions {
				let button = UIButton(type: .system)
				if action.title.count > 0 { button.setTitle(action.title, for: .normal) }
				
				if let image = action.image {
					let width = (image.size.width / image.size.height) * 25
					button.setImage(image.scaled(toSize: CGSize(width: width, height: 25)), for: .normal)
				}
				
				// Add target
				if let target = action.target, let action = action.action {
					button.addTarget(target, action: action, for: .touchUpInside)
				}
				
				// Add menu if available
				if let menu = action.menu {
					button.menu = menu
					button.showsMenuAsPrimaryAction = true
				}

				// If possible, the button should be at least 40px wide for a good sized tap target
				let widthConstraint = button.widthAnchor.constraint(equalToConstant: itemWidth)
				widthConstraint.priority = .defaultHigh
				widthConstraint.isActive = true
				
				stackView.addArrangedSubview(button)
			}
		}
	}
}

extension InputAssistantView: UICollectionViewDelegate {
	/// Manually trigger selection in the suggestions list.
	@objc public func selectItem(at index:Int) {
		if self.suggestionsCollectionView.numberOfItems(inSection: 0) > 0 {
			self.collectionView(self.suggestionsCollectionView, didSelectItemAt: IndexPath(item: index, section: 0))
		}
	}
	
	/// Select a suggestion item using hardware keyboard
	@objc public func selectHighlightedItem() {
		let index = self.suggestionsCollectionView.highlightedItem
		guard index >= 0 else { return }
		
		selectItem(at: index)
	}
	
	@objc public func deselectHighlightedItem() {
		self.suggestionsCollectionView.highlightedItem = -1
	}
	
	/// Collection view delegate method for picking items. Sent forward to input assistant view delegate.
	public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		UIDevice.current.playInputClick()
		collectionView.deselectItem(at: indexPath, animated: true)
		
		if let item = self.dataSource?.inputAssistantView(self, nameForSuggestionAtIndex: indexPath.last ?? NSNotFound) as? String {
			self.delegate?.inputAssistantView(self, didSelectSuggestion: item)
		}
	}
	
	public func highlightNextSuggestion() {
		self.suggestionsCollectionView.highlightNext()
	}
	
	public func highlightPreviousSuggestion() {
		self.suggestionsCollectionView.highlightPrevious()
	}
	
	var highlightedSuggestion:Int {
		return self.suggestionsCollectionView.highlightedItem
	}
}

extension InputAssistantView: UIInputViewAudioFeedback {
	
	public var enableInputClicksWhenVisible: Bool { return true }
}


extension UIImage {
	/// Scales the image to the given CGSize
	func scaled(toSize size: CGSize) -> UIImage {
		if self.size == size { return self }
				
		let newImage = UIGraphicsImageRenderer(size: size).image { context in
			self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
		}
		return newImage.withRenderingMode(self.renderingMode)
	}
}
