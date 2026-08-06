//
//  BeatVersionControl+CommitView.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 17.4.2026.
//

#if os(macOS)
import AppKit

extension BeatVersionControl {
    public class func commitPrompt(delegate:BeatEditorDelegate, afterCommit: @escaping (BeatVersionControl) -> Void) -> NSPopover {
        
        let popover = NSPopover()
        popover.behavior = .transient
        
        let popoverVC = CommitMessagePopover { message in
            popover.close()
            
            // Create version control and add commit with message
            let vc = BeatVersionControl(delegate: delegate)
            vc.addCommit(withMessage: message)
            
            afterCommit(vc)
        }
        
        popover.contentViewController = popoverVC
        
        return popover
    }
    
    /// New modal window presentation, reusing the same view controller
    public class func commitPromptModal(delegate: BeatEditorDelegate,
                                         callback: @escaping (BeatVersionControl?) -> Void) {
        let modalVC = CommitMessagePopover { message in
            let vc = BeatVersionControl(delegate: delegate)
            vc.addCommit(withMessage: message)
        }
        
        if let window = delegate.documentWindow {
            let modalWindow = NSWindow(contentViewController: modalVC)
            modalWindow.styleMask = [.titled, .closable]
            modalWindow.title = BeatLocalization.localizedString(forKey: "versionControl.commitChanges")
            
            modalVC.closeAction = {
                window.endSheet(modalWindow)
            }
            
            delegate.documentWindow.beginSheet(modalWindow) { _ in
                callback(nil)
            }
            
        } else {
            // As a fallback, do whatever the closure told
            callback(nil)
        }
    }
}

class CommitMessagePopover: NSViewController {
    private var commitAction: ((String) -> Void)?
    // Add this when calling as a modal
    var closeAction: (() -> Void)? {
        didSet {
            if closeAction != nil {
                skipButton.isHidden = false
            }
        }
    }
    
    private lazy var messageField: NSTextField = {
        let field = NSTextField(frame: NSRect(x: 5, y: 35, width: 210, height: 48))
        field.placeholderString = BeatLocalization.localizedString(forKey: "versionControl.commitMessage")
        field.action = #selector(commitClicked)
        field.formatter = CommitFieldFormatter(maxLength: 140)
        field.focusRingType = .none
        return field
    }()
    
    private lazy var commitButton: NSButton = {
        let button = NSButton(frame: NSRect(x: 2, y: 5, width: 100, height: 24))
        button.title = BeatLocalization.localizedString(forKey: "versionControl.addCommit")
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = #selector(commitClicked)
        button.controlSize = .small
        button.keyEquivalent = "\r"
        return button
    }()
    
    private lazy var skipButton: NSButton = {
        let button = NSButton(frame: NSRect(x: 2, y: 5, width: 100, height: 24))
        button.title = BeatLocalization.localizedString(forKey: "versionControl.skip")
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
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 90))
        
        messageField.frame.size.width = self.view.frame.width - 10
        
        commitButton.sizeToFit()
        commitButton.frame.origin.x = self.view.frame.width - commitButton.frame.width - 2
        
        skipButton.sizeToFit()
        skipButton.isHidden = true
        
        self.view.addSubview(messageField)
        self.view.addSubview(commitButton)
        self.view.addSubview(skipButton)
    }
    
    @objc private func commitClicked() {
        commitAction?(messageField.stringValue)
        close()
    }
    
    override func cancelOperation(_ sender: Any?) {
        close()
    }
    
    private func close() {
        if let closeAction = closeAction {
            closeAction()
        } else {
            dismiss(nil)
        }
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

#endif
