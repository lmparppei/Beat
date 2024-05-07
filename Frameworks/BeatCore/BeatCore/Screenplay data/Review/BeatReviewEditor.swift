//
//  BeatReviewEditor.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 6.7.2023.
//
/**
 
 THIS IS NOT A PLACE OF HONOR
 no highly esteemed deed is commemorated here
 nothing valued is here
 
 
 
 
 OK, now that you've read that, this class is a __complete__ mess. It aims to be cross-platform compatbile without really understanding MVVM design.
 
 You should be able to create a `BeatReviewEditor` instance and on both iOS and macOS and ignore this class altogether.
 `BeatReviewEditorView` is the actual popup content view,
 
 Both classes are filled with tons of target conditionals, and parts of the code are very overlapping and messy.
 I guess the editor should be detached from the actual review class.
 
 */

import Foundation
import UXKit

protocol BeatReviewEditorDelegate:AnyObject {
    func applyReview(item:BeatReviewItem)
    func deleteReview(item:BeatReviewItem)
    func saveReview(item:BeatReviewItem)
        
    func close()
    
    //func editorDidClose(for item:BeatReviewItem)
    
    #if os(macOS)
    var popover:NSPopover? { get }
    #else
    func presentForEditing(item:BeatReviewItem)
    #endif
}

@objc public class BeatReviewEditor:NSObject, BeatReviewEditorDelegate {
    
    var delegate:BeatReview
    var item:BeatReviewItem
    var editor:BeatReviewEditorView?
    
    #if os(macOS)
    var popover:NSPopover?
    #endif
    
    init(review:BeatReviewItem, delegate:BeatReview, editable:Bool) {
        self.delegate = delegate
        self.item = review
        super.init()
        
        self.editor = BeatReviewEditorView(reviewItem: review, delegate: self, editable: editable)
    }
    
    func show(range:NSRange, editable:Bool, sender:UXView?) {
        let rect = rectForRange(range: range)
    
        #if os(macOS)
            self.popover = NSPopover()
            self.popover?.contentViewController = self.editor
            self.popover?.behavior = .transient
            
            if #available(macOS 10.14, *) {
                popover?.appearance = NSAppearance(named: .aqua)
            }
            
            popover?.show(relativeTo: rect, of:sender!, preferredEdge: NSRectEdge.maxY)
            
        #elseif os(iOS)
        
            guard let editor = self.editor,
                  let vc = self.delegate.delegate as? UIViewController
            else { return }

            if (!editable) {
                // Non-editable view
                if UIDevice.current.userInterfaceIdiom == .pad {
                    editor.modalPresentationStyle = .popover
                    
                    let popoverController = editor.popoverPresentationController
                    
                    var sourceRect = rect
                    sourceRect.origin.y += 5.0
                    sourceRect.origin.x += rect.size.width / 2
                    sourceRect.size.width = rect.size.width / 2
                    
                    popoverController?.sourceView = sender
                    popoverController?.sourceRect = sourceRect
                    
                    popoverController?.permittedArrowDirections = [.up]
                } else {
                    self.editor?.modalPresentationStyle = .pageSheet
                    self.editor?.sheetPresentationController?.detents = [.medium()]
                }
            } else {
                // Editable view
                self.editor?.modalPresentationStyle = .formSheet
            }
                
            vc.present(editor, animated: true)
        #endif
    }
    
    #if os(iOS)
    func presentForEditing(item: BeatReviewItem) {
        
        self.editor?.dismiss(animated: false)
        self.editor = BeatReviewEditorView(reviewItem: self.item, delegate: self, editable: true)
        
        show(range: self.delegate.delegate?.selectedRange ?? NSRange(), editable: true, sender: nil)
    }
    #endif
    
    func rectForRange(range:NSRange) -> CGRect {
        guard let textView = delegate.delegate?.getTextView() as? UXTextView
        else { return CGRectZero }

        var rect = textView.frameOfTextRange(range: range)
        
        // Rect has to be at least 1px wide the popover to display correctly
        if rect.width < 1.0 { rect.size.width = 1.0 }
        return rect
    }

    func close() {
        #if os(macOS)
        self.popover?.close()
        #else
        self.editor?.dismiss(animated: true)
        #endif
    }
    
    func applyReview(item: BeatReviewItem) {
        self.delegate.applyReview(item: item)
    }
    
    func deleteReview(item: BeatReviewItem) {
        self.delegate.deleteReview(item: item)
    }
    
    func saveReview(item: BeatReviewItem) {
        self.delegate.saveReview(item: item)
    }

}

#if os(macOS)
extension BeatReviewEditor:NSPopoverDelegate {
    public func popoverDidClose(_ notification: Notification) {
        self.delegate.editorDidClose(for: self.item)
    }
}
#endif

// MARK: - The actual editor view
// Please help me with this code.

public protocol BeatReviewDelegate: AnyObject {
    func confirm(sender:Any?)

}

@objc public class BeatReviewEditorViewBase:UXViewController, BeatReviewDelegate, UXTextViewDelegate {
    @IBOutlet weak var textView:BeatReviewTextView?
    @IBOutlet weak var editButton:UXButton?

    weak var delegate:BeatReviewEditorDelegate?
    var item:BeatReviewItem
    var shown:Bool = false
    
    var editorContentSize:CGSize { return CGSizeMake(250, 160) }
    
    var editable = false {
        didSet { updateEditorMode() }
    }
    
    init(reviewItem:BeatReviewItem, delegate:BeatReviewEditorDelegate, editable:Bool) {
        self.item = reviewItem
        self.delegate = delegate
        self.editable = editable
        
        #if os(macOS)
            let nibName = "BeatReviewEditor macOS"
        #else
            let nibName = "BeatReviewEditor iOS"
        #endif

        
        let bundle = Bundle(for: type(of: self))
        super.init(nibName: nibName, bundle: bundle)
    }
    
    required public init?(coder: NSCoder) {
        self.item = BeatReviewItem(reviewString: "")
        super.init(coder: coder)
    }
    
    deinit {
        self.textView = nil
        self.editButton = nil
    }
}

#if os(macOS)
@objc class BeatReviewEditorView: BeatReviewEditorViewBase {
}
#elseif os(iOS)
@objc public class BeatReviewEditorView: BeatReviewEditorViewBase {
    // The iOS version requires more setup
    @IBOutlet weak var closeButton:UXButton?
        
    override var editorContentSize:CGSize { return CGSizeMake(250, 160) }
        
    override init(reviewItem:BeatReviewItem, delegate:BeatReviewEditorDelegate, editable:Bool) {
        super.init(reviewItem: reviewItem, delegate: delegate, editable: editable)

        let view = self.view as? BeatReviewEditorActualView
        view?.viewController = self
        
        self.view.insetsLayoutMarginsFromSafeArea = true
        self.textView?.textContainerInset = UIEdgeInsets.zero
        
        // Setting the delegate will automatically make this class save the changes
        self.textView?.delegate = self
        
        if editable {
            self.setContentSize(CGSizeMake(400.0, 300.0))
            self.textView?.becomeFirstResponder()
        }
        
        if UIDevice.current.userInterfaceIdiom != .phone { closeButton?.removeFromSuperview() }
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        guard let direction = self.popoverPresentationController?.arrowDirection else { return }
        if (direction != .up) {
            self.additionalSafeAreaInsets = UIEdgeInsets(top: -20.0, left: 0.0, bottom: 20.0, right: 0.0)
        }
    }
    
    @IBAction public func editReviewNote(sender:Any?) {
        if self.editable {
            // In edit mode, this button dismisses the view
            self.dismiss(animated: true)
        } else {
            self.delegate?.presentForEditing(item: self.item)
        }
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        self.textDidChange(Notification(name: Notification.Name("")))
    }
}

class BeatReviewEditorActualView:UIView {
    weak var viewController:UIViewController?
    
    @IBAction func dismiss() {
        self.viewController?.dismiss(animated: true)
    }
}

#endif

extension BeatReviewEditorViewBase {
    override public func viewDidLoad() {
        // Set up the text view once view loads
        textView?.delegate = self
        textView?.reviewDelegate = self
        textView?.setInsets(CGSizeMake(5.0, 8.0))
                
        // Load content from the review
        textView?.text = item.string as? String ?? ""
                
        updateEditorMode()
        
        #if os(macOS)
        if editable { textView?.window?.makeFirstResponder(textView) }
        #endif
    }
    
    /// Update editor mode when setting `editable` property
    func updateEditorMode() {
        textView?.isEditable = editable
        editButton?.isHidden = editable
        
        if (!editable) {
            adjustTextViewToContent()
        } else {
            focusTextView()
        }
        
        #if os(iOS)
        editButton?.isHidden = false
        editButton?.title = (editable) ? NSLocalizedString("review.editor.done", comment: "Done") : NSLocalizedString("review.editor.edit", comment: "Edit")
        #endif
    }
    
    /// Adjusts text view to non-editable note content
    func adjustTextViewToContent() {
        guard let textView = self.textView else { return }
        let insetHeight = textView.getInsets().height
        
        // Calculate appropriate size for the content
        let size = adjustedSize()
        
        #if os(macOS)
        let contentSize = CGSizeMake(size.width, size.height + 40.0 + insetHeight * 2)
        #else
        // iOS needs to account for the arrow
        let contentSize = CGSizeMake(size.width, size.height + 100.0 + insetHeight * 2)
        #endif
        
        self.setContentSize(contentSize)
    }
    
    func adjustedSize() -> CGSize {
        // Calculate appropriate size for the content
        guard let textView = self.textView else { return CGSizeMake(0.0, 0.0) }
        
        var width = editorContentSize.width
        var height = textView.attributedString().height(containerWidth: width)
        
        #if os(macOS)
            // For longer reviews we'll want to make the width a bit bigger
            if height > width * 1.5 {
                if height > width * 2 { width = 500 }
                else if height > width * 1.5 { width = 400 }
                height = textView.attributedString().height(containerWidth: width)
            }
        #endif
        
        return CGSizeMake(width, min(height, 800.0))
    }
    
    /// Focuses the editable text view
    func focusTextView() {
        self.setContentSize(editorContentSize)
                    
        #if os(macOS)
        textView?.window?.makeFirstResponder(self.textView)
        var contentSize = self.editorContentSize
        let adjustedSize = self.adjustedSize()
        
        if adjustedSize.width > editorContentSize.width || adjustedSize.height > editorContentSize.height { contentSize = adjustedSize }
        delegate?.popover?.contentSize = contentSize
        #else
        self.textView?.becomeFirstResponder()
        #endif
    }
    
    @IBAction public func confirm(sender:Any?) {
        item.string = textView?.string as? NSString
        delegate?.applyReview(item: item)
    }
    
    @IBAction public func edit(sender:Any?) {
        self.editable = true
    }
        
    @IBAction public func delete(sender:Any?) {
        delegate?.deleteReview(item: item)
    }
    
    
    // MARK: Text view delegation
    public func textDidChange(_ notification: Notification) {
        item.string = textView?.text as? NSString
        delegate?.saveReview(item: item)
    }
    
    func setContentSize(_ size:CGSize) {
        #if os(macOS)
        delegate?.popover?.contentSize = size
        #elseif os(iOS)
        self.preferredContentSize = size
        #endif
    }
}


// MARK: - Popover view delegate methods for iOS

#if os(iOS)
extension BeatReviewEditorView:UIPopoverPresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    public func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
}
#endif



// MARK: - Text view

@objc public class BeatReviewTextView:UXTextView {
    weak var reviewDelegate: BeatReviewDelegate?

#if os(macOS)
    override public func keyDown(with event: NSEvent) {
        // Close on esc or shift-enter
        if (event.keyCode == 53 ||
            event.keyCode == 36 && event.modifierFlags.contains(.shift)) {
            reviewDelegate?.confirm(sender: self)
            return
        }
        
        super.keyDown(with: event)
    }
#endif
}


// MARK: - Popover views
class BeatReviewEditorContentView:UXView {
    var backgroundView:BeatReviewEditorBackgroundView?
    
#if os(macOS)
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let frameView = self.window?.contentView?.superview {
            if backgroundView == nil {
                backgroundView = BeatReviewEditorBackgroundView(frame: frameView.bounds)
                backgroundView!.autoresizingMask = UXView.AutoresizingMask([.width, .height]);
                frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
            }
        }
    }
#endif
}

class BeatReviewEditorBackgroundView:UXView {
    #if os(macOS)
    override func draw(_ dirtyRect: NSRect) {
        BeatReview.reviewColor().set()
        self.bounds.fill()
    }
    #else
    override func awakeFromNib() {
        self.layer.backgroundColor = BeatReview.reviewColor().cgColor
    }
    #endif
}

