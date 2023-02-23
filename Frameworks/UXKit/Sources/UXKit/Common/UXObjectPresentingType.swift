//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
import Foundation

@objc public protocol UXObjectPresentingType : AnyObject {
  
  @objc var representedObject : Any? { get set }
  
}

#if os(macOS)
  import Cocoa
  
  extension NSViewController : UXObjectPresentingType {
  }
  
#else // iOS
  import UIKit

  private var uivcRO : UInt8 = 42
  
  extension UIViewController : UXObjectPresentingType {
    
    /// Add represented object to UIViewController.
    @objc open var representedObject : Any? {
      set {
        objc_setAssociatedObject(self, &uivcRO, newValue,
                                 objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
      }
      get {
        return objc_getAssociatedObject(self, &uivcRO)
      }
    }
  }
  
#endif // iOS
