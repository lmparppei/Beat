//
//  UXView.swift
//  UXKit
//
//  Created by Helge Heß on 14.03.19.
//  Copyright © 2019-2021 ZeeZide GmbH. All rights reserved.
//

/**
 * This is useful when you want to derive another protocol from
 * UXView, but you can't ;-)
 */
public protocol UXViewType : AnyObject {

  var frame  : UXRect { get set }
  var bounds : UXRect { get set }

  // MARK: - Superview
  
  var superview : UXView?    { get }
  
  // MARK: - Subviews
  
  var subviews  : [ UXView ] { get }
  
  func addSubview(_ view: UXView)
  func removeFromSuperview()
}

extension UXView : UXViewType {}
