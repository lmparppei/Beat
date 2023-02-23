//
//  UXKit
//
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//
#if os(macOS)
  import Cocoa
  
  public extension NSButton {
    
    @inlinable
    @discardableResult
    func onClick(_ target: AnyObject?, _ action: Selector) -> Self {
      self.target = target
      self.action = action
      return self
    }
  }

  public extension NSTextField {
    
    @inlinable
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      self.target = target
      self.action = action
      return self
    }
  }
  
  public extension NSPopUpButton {
    
    @inlinable
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      self.target = target
      self.action = action
      return self
    }
  }
  
  public extension NSSegmentedControl {
    
    @inlinable
    @discardableResult
    func onClick(_ target: AnyObject?, _ action: Selector) -> Self {
      // to support `momentary`
      self.target = target
      self.action = action
      return self
    }
    @inlinable
    @discardableResult
    func onChange(_ target: AnyObject?, _ action: Selector) -> Self {
      // to support `selectOne`/`selectAny`
      self.target = target
      self.action = action
      return self
    }
  }

  public extension NSTableView {
    
    @inlinable
    @discardableResult
    func onClick(_ target: AnyObject?, _ action: Selector) -> Self {
      self.target = target
      self.action = action
      return self
    }
    
    @inlinable
    @discardableResult
    func onDoubleClick(_ target: AnyObject?, _ action: Selector) -> Self {
      if self.target != nil && target !== self.target {
        print("setting different target for double-click action:", self,
              "\n  old:", self.target ?? "-",
              "\n  new:", target      ?? "-")
      }
      
      self.target       = target
      self.doubleAction = action
      return self
    }
  }
#endif // macOS
