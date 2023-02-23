//
//  UXKit
//
//  Copyright © 2016-2019 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import UIKit

  public extension UIButton {
    
    @discardableResult
    func onClick(_ target: AnyObject?, _ action: Selector) -> Self {
      addTarget(target, action: action, for: .touchUpInside)
      return self
    }
  }

  public extension UITextField {
    
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      addTarget(target, action: action, for: .editingChanged)
      return self
    }
  }

  #if !os(tvOS)
  public extension UISwitch {
    
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      addTarget(target, action: action, for: .valueChanged)
      return self
    }
  }

  public extension UISlider {
    
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      addTarget(target, action: action, for: .valueChanged)
      return self
    }
  }
  #endif

#endif
