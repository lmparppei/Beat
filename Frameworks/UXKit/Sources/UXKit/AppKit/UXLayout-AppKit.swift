//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if os(macOS)
  import Cocoa
  
  public typealias UXLayoutConstraint = NSLayoutConstraint
  
  @available(OSX 10.11, *)
  public typealias UXLayoutGuide      = NSLayoutGuide

#if swift(>=4.0)
  public extension NSStackView {
    typealias Alignment        = NSLayoutConstraint.Attribute
    typealias UXAlignment      = NSLayoutConstraint.Attribute
    typealias Axis             = NSUserInterfaceLayoutOrientation
  }
#else // Swift 3.2
  public extension NSLayoutConstraint {
    public typealias Attribute        = NSLayoutAttribute
    public typealias Relation         = NSLayoutRelation
    #if false // crashes 3.2 in Xcode 9 9A235 - Because it exists? in 3.2? But not in 3.1?
      public typealias Priority       = NSLayoutPriority
    #endif
  }
  public extension NSStackView {
    public typealias Distribution     = NSStackViewDistribution
    public typealias Alignment        = NSLayoutAttribute
    public typealias UXAlignment      = NSLayoutAttribute
  }
#endif
  public typealias UXStackViewAxis    = NSUserInterfaceLayoutOrientation
#endif
