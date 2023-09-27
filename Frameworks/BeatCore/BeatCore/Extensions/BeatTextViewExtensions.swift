//
//  BeatTextViewExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 6.7.2023.
//


import UXKit

extension UXTextView {
    /// Returns X/Y insets for the text view for cross-platform compatibility.
    func getInsets() -> CGSize {
        #if os(macOS)
        return CGSizeMake(self.textContainerInset.width, self.textContainerInset.height)
        #else
        return CGSizeMake(self.textContainerInset.left, self.textContainerInset.top)
        #endif
    }
    
    func setInsets(_ size:CGSize) {
        #if os(macOS)
        self.textContainerInset = CGSizeMake(size.width, size.height)
        #else
        self.textContainerInset = UIEdgeInsets(top: size.height, left: size.width, bottom: size.height, right: size.width)
        #endif
    }

    // MARK: Compatibility for .text and .attributedString() between macOS and iOS
    
    #if os(iOS)
    func attributedString() -> NSAttributedString {
        return self.attributedText
    }
    
    #elseif os(macOS)
    var text:String {
        get { return self.string }
        set { self.string = newValue }
    }

    var textContainerOrigin: CGPoint {
        return CGPoint(x: getInsets().width, y: getInsets().height)
    }
    
    public func boundingRect(for range: NSRange? = nil) -> CGRect? {
        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer,
              let textStorage = self.textStorage
        else { return nil }
        
        let charRange = range ?? NSRange(location: 0, length: textStorage.length)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
        
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }
    
    #endif
    
    // MARK: Easy rects for iOS
    func frameOfTextRange(range: NSRange) -> CGRect {
        #if os(macOS)
        var rect = self.firstRect(forCharacterRange: range, actualRange: nil)
        guard var textRect = self.window?.convertFromScreen(rect) else { return CGRectZero }
        textRect = self.convert(textRect, from: nil)
        return textRect
        
        #elseif os(iOS)
        let beginning = self.beginningOfDocument
        if let start = self.position(from: beginning, offset: range.location),
           let end = self.position(from: start, offset: range.length),
           let textRange = self.textRange(from: start, to: end) {
            let rect = self.firstRect(for: textRange)
            return self.convert(rect, from: self.textInputView)
        }
        return CGRect.zero
        #endif
    }
    
    
}
