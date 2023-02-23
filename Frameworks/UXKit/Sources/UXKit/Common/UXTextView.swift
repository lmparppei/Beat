//
//  UXTextView.swift
//  UXKit
//
//  Created by Helge Heß on 16.05.20.
//  Copyright © 2020-2021 ZeeZide GmbH. All rights reserved.
//

#if !os(macOS)
  import struct Foundation.NSRange
  import class  UIKit.NSTextStorage
  import class  UIKit.NSLayoutManager
  import class  UIKit.NSTextContainer
  import struct UIKit.NSTextStorageEditActions
  import class  UIKit.UITextView

  public typealias NSTextStorage   = UIKit.NSTextStorage
  public typealias NSLayoutManager = UIKit.NSLayoutManager
  public typealias NSTextContainer = UIKit.NSTextContainer

  public typealias NSTextStorageEditActions = UIKit.NSTextStorage.EditActions

  public extension UITextView {
    
    /// Make the storage optional to match up w/ AppKit.
    @inlinable
    var uxTextStorage : NSTextStorage? { return textStorage }
    
    @inlinable
    var string : String { // NeXTstep was right!
      set { text = newValue}
      get { return text }
    }

    /// AppKit compatibility (sets `selectedRange` to the argument)
    @inlinable
    func setSelectedRange(_ range: NSRange) { selectedRange = range }
    
    /// AppKit compatibility (returns the value of `selectedRange`)
    @inlinable
    func selectedRange() -> NSRange { return selectedRange }
  }

#else // macOS

  import class  AppKit.NSTextStorage
  import class  AppKit.NSLayoutManager
  import class  AppKit.NSTextContainer
  import struct AppKit.NSTextStorageEditActions
  import class  AppKit.NSTextView

  public typealias NSTextStorage   = AppKit.NSTextStorage
  public typealias NSLayoutManager = AppKit.NSLayoutManager
  public typealias NSTextContainer = AppKit.NSTextContainer

  @available(macOS 10.11, *)
  public typealias NSTextStorageEditActions = AppKit.NSTextStorageEditActions
  
  @available(macOS 10.11, *)
  public extension NSTextStorage {
    typealias EditActions = NSTextStorageEditActions
  }
  public extension NSTextView {

    /// Helper to hide the optionality differences between UIKit and AppKit
    @inlinable
    var uxTextStorage : NSTextStorage? { return textStorage }
  }
#endif // macOS
