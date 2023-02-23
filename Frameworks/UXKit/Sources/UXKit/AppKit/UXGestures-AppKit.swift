//
//  UXKit
//
//  Copyright © 2016-2017 ZeeZide GmbH. All rights reserved.
//
#if os(macOS)
  import Cocoa
  
  public typealias UXGestureRecognizer         = NSGestureRecognizer
  public typealias UXRotationGestureRecognizer = NSRotationGestureRecognizer
  public typealias UXPanGestureRecognizer      = NSPanGestureRecognizer
  public typealias UXTapGestureRecognizer      = NSClickGestureRecognizer
  public typealias UXPinchGestureRecognizer = NSMagnificationGestureRecognizer
  // No Swipe?
  //   but AppKit has a 'Press' in addition to 'Click'

  public extension NSView {
    
    @discardableResult
    func on(gesture gr: UXGestureRecognizer,
            target: AnyObject, action: Selector) -> Self
    {
      gr.target = target // UIKit requires a target
      gr.action = action
      addGestureRecognizer(gr)
      return self
    }
    
  }
  
  public extension UXTapGestureRecognizer {
    // Note: NSClickGestureRecognizer
    // - numberOfClicksRequired
    // - numberOfTouchesRequired (10.12.2)
    
    var numberOfTapsRequired: Int {
      set { numberOfClicksRequired = newValue }
      get { return numberOfClicksRequired }
    }
  }
#endif
