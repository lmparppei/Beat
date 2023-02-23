//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import UIKit

  public typealias UXWindow           = UIWindow
  public typealias UXView             = UIView
  public typealias UXResponder        = UIResponder
  public typealias UXControl          = UIControl
  public typealias UXLabel            = UILabel
  public typealias UXTextField        = UITextField
  public typealias UXSecureTextField  = UITextField
  public typealias UXScrollView       = UIScrollView
  public typealias UXCollectionView   = UICollectionView
  public typealias UXSearchField      = UISearchBar // TBD
  public typealias UXSpinner          = UIActivityIndicatorView
  public typealias UXProgressBar      = UIProgressView
  public typealias UXButton           = UIButton
  public typealias UXTextView         = UITextView
  public typealias UXTextViewDelegate = UITextViewDelegate
  // public typealias UXPopUp         = TODO
  public typealias UXStackView        = UIStackView
  public typealias UXImageView        = UIImageView
  #if !os(tvOS)
  public typealias UXCheckBox         = UISwitch
  public typealias UXSlider           = UISlider
  #endif
  
  
  // MARK: - UXUserInterfaceItemIdentification
  
  public typealias UXUserInterfaceItemIdentifier = String
    // FIXME: maybe we should change it to the new Raw type in AppKit Swift 4
  
  @objc public protocol UXUserInterfaceItemIdentification {
    var identifier: UXUserInterfaceItemIdentifier? { get set }
  }
  
  
  // MARK: - NSView Compatibility
  
  public extension UIActivityIndicatorView {
    
    /// Use this instead of `start[stop]Animating` for AppKit compatibility.
    var isSpinning : Bool {
      set {
        guard newValue != isAnimating else { return }
        if newValue { startAnimating() }
        else        { stopAnimating()  }
      }
      get {
        return isAnimating
      }
    }
    
    /// AppKit compatibility. Prefer: `hidesWhenStopped`.
    /// Note: It's the other way around!
    var isDisplayedWhenStopped : Bool {
      set { hidesWhenStopped = !newValue }
      get { return !hidesWhenStopped }
    }
  }
  
  public extension UIButton {
    
    var title : String? {
      set { setTitle(newValue, for: .normal) }
      get { return title(for: .normal)       }
    }
    
  }

#if !os(tvOS)
  public extension UISlider {
    // UISlider base value is a `Float`
    
    var intValue : Int32 { // yeah, it is Int32 in Cocoa :-)
      set { value = Float(newValue) }
      get { return Int32(value) }
    }
    
  }
#endif

  public extension UXView {
    
    func inOwnContext(execute: () -> ()) {
      let context = UIGraphicsGetCurrentContext()
      context?.saveGState()
      defer { context?.restoreGState() }
      
      execute()
    }

  }
#endif // !os(macOS)
