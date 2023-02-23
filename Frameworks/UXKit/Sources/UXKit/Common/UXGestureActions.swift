//
//  UXGestureActions.swift
//  UXKit
//
//  Created by Helge Hess on 05.12.17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

public extension UXView {

  #if !os(tvOS)
  @discardableResult
  func onRotation(_ target: AnyObject, _ action: Selector) -> Self {
    return on(gesture: UXRotationGestureRecognizer(),
              target: target, action: action)
  }
  #endif
  
  @discardableResult
  func onPan(_ target: AnyObject, _ action: Selector) -> Self {
    return on(gesture: UXPanGestureRecognizer(), target: target, action: action)
  }
  
  @discardableResult
  func onTap(_ target: AnyObject, _ action: Selector) -> Self {
    return on(gesture: UXTapGestureRecognizer(), target: target, action: action)
  }
  
  /**
   * On macOS this reacts to the secondary mouse button, and on iOS to the
   * "long press".
   */
  @discardableResult
  func onSecondaryTap(_ target: AnyObject, _ action: Selector) -> Self {
    #if os(macOS)
      let gr = NSClickGestureRecognizer()
      gr.buttonMask = 0x2 // secondary button
      return on(gesture: gr, target: target, action: action)
    #else
      let gr = UILongPressGestureRecognizer()
      return on(gesture: gr, target: target, action: action)
    #endif
  }

#if !os(tvOS)
  @discardableResult
  func onPinch(_ target: AnyObject, _ action: Selector) -> Self {
    return on(gesture: UXPinchGestureRecognizer(),
              target: target, action: action)
  }
#endif
  
}
