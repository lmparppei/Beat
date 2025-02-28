//
//  CommitMessagePopover.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

class CommitMessagePopover: NSViewController {
	private var commitAction: ((String) -> Void)?
	
	private lazy var messageField: NSTextField = {
		let field = NSTextField(frame: NSRect(x: 5, y: 35, width: 210, height: 48))
		field.placeholderString = "Commit message (Optional)"
		field.action = #selector(commitClicked)
		field.formatter = CommitFieldFormatter(maxLength: 140)
		field.focusRingType = .none
		return field
	}()
	
	private lazy var commitButton: NSButton = {
		let button = NSButton(frame: NSRect(x: 2, y: 5, width: 100, height: 24))
		button.title = "Add Commit"
		button.bezelStyle = .rounded
		button.setButtonType(.momentaryPushIn)
		button.target = self
		button.action = #selector(commitClicked)
		button.controlSize = .small
		return button
	}()
	
	init(commitAction: @escaping (String) -> Void) {
		self.commitAction = commitAction
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadView() {
		self.view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 90))
		self.view.addSubview(messageField)
		self.view.addSubview(commitButton)
	}
	
	@objc private func commitClicked() {
		commitAction?(messageField.stringValue)
		dismiss(nil)
	}
}

fileprivate class CommitFieldFormatter: Formatter {
	var maxLength: UInt
	
	init(maxLength: UInt) {
		self.maxLength = maxLength
		super.init()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func string(for obj: Any?) -> String? {
		return obj as? String
	}
	
	override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
		obj?.pointee = string as AnyObject
		return true
	}
	
	override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>, proposedSelectedRange proposedSelRangePtr: NSRangePointer?, originalString origString: String, originalSelectedRange origSelRange: NSRange, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
		
		return !(partialStringPtr.pointee.length > maxLength)
	}
	
	override func attributedString(for obj: Any, withDefaultAttributes attrs: [NSAttributedString.Key : Any]? = nil) -> NSAttributedString? {
		return nil
	}
}
