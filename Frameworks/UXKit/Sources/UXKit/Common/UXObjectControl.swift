//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
import Foundation

@objc public protocol UXObjectControl : AnyObject {
  var formatter   : Formatter? { get set }
  var objectValue : Any?       { get set }
}

#if os(macOS)
  import Cocoa
  
  extension NSControl : UXObjectControl {}
#else
  import UIKit
  
  private var uilFmt  : UInt8 = 42
  private var uitfFmt : UInt8 = 42

  extension UILabel : UXObjectControl {

    public var intValue : Int32 { // yeah, it is Int32 in Cocoa :-)
      set { text = String(newValue) }
      get {
        guard let s = text else { return 0 }
        return Int32(s) ?? 0
      }
    }

    public final var stringValue : String {
      set { text = newValue }
      get { return text ?? "" }
    }

    public final var attributedStringValue: NSAttributedString {
      // TBD: could embed font and color information?
      set { attributedText = newValue }
      get { return attributedText ?? NSAttributedString(string: text ?? "") }
    }
    
    @objc open var formatter : Formatter? {
      set {
        objc_setAssociatedObject(self, &uilFmt, newValue,
                                 objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
      }
      get {
        return objc_getAssociatedObject(self, &uilFmt) as? Formatter
      }
    }
    
    @objc open var objectValue : Any? {
      set {
        if let fmt = formatter {
          // TODO: we could also support attributed strings?!
          text = fmt.string(for: newValue)
        }
        else if let s = newValue as? NSAttributedString {
          // TODO: support colors and such?
          text = s.string
        }
        else if let v = newValue {
          text = "\(v)"
        }
        else { // TBD: <nil>?
          text = ""
        }
      }
      get {
        if let fmt = formatter {
          var value : AnyObject? = nil
          _ = fmt.getObjectValue(&value, for: text ?? "", errorDescription: nil)
          return value
        }
        else {
          return text
        }
      }
    }
    
  }

  extension UITextField : UXObjectControl {
    // TODO: We need something better here. Supporting 'editingString',
    //       partial completion and all the cool stuff of AppKit.
    // Also: We should store the object value.
    
    public var intValue : Int32 { // yeah, it is Int32 in Cocoa :-)
      set { text = String(newValue) }
      get {
        guard let s = text else { return 0 }
        return Int32(s) ?? 0
      }
    }

    public final var stringValue : String {
      set { text = newValue }
      get { return text ?? "" }
    }

    public final var attributedStringValue: NSAttributedString {
      // TBD: could embed font and color information?
      set { attributedText = newValue }
      get { return attributedText ?? NSAttributedString(string: text ?? "") }
    }
    
    @objc open var formatter : Formatter? {
      set {
        objc_setAssociatedObject(self, &uitfFmt, newValue,
                                 objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
      }
      get {
        return objc_getAssociatedObject(self, &uitfFmt) as? Formatter
      }
    }
    
    @objc open var objectValue : Any? {
      set {
        if let fmt = formatter {
          // TODO: we could also support attributed strings?!
          text = fmt.string(for: newValue)
        }
        else if let s = newValue as? NSAttributedString {
          // TODO: support colors and such?
          text = s.string
        }
        else if let v = newValue {
          text = "\(v)"
        }
        else { // TBD: <nil>?
          text = ""
        }
      }
      get {
        if let fmt = formatter {
          var value : AnyObject? = nil
          _ = fmt.getObjectValue(&value, for: text ?? "", errorDescription: nil)
          return value
        }
        else {
          return text
        }
      }
    }
    
  }
#endif // iOS
