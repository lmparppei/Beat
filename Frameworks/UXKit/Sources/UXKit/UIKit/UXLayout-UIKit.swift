//
//  UXKit
//
//  Copyright © 2016-2019 ZeeZide GmbH. All rights reserved.
//
#if os(iOS)
  import UIKit

  public typealias UXLayoutConstraint = NSLayoutConstraint
  public typealias UXLayoutGuide      = UILayoutGuide

  public extension UIStackView {
    typealias UXAlignment             = NSLayoutConstraint.Attribute
  }
  public extension NSLayoutConstraint {
    typealias Priority                = UILayoutPriority
  }

  public typealias UXStackViewAxis    = NSLayoutConstraint.Axis
#endif
