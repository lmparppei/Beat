//
//  UXAlert.swift
//  UXKit
//
//  Created by Helge Heß on 09.10.19.
//  Copyright © 2019 ZeeZide GmbH. All rights reserved.
//

#if os(macOS)
  import AppKit

  public typealias UXAlert = NSAlert

#elseif os(iOS)
  import UIKit

  public typealias UXAlert = UIAlertController

  public extension UIAlertController {
    
    /// AppKit NSAlert version of `title`
    var messageText : String? {
      set { title = newValue }
      get { return title }
    }
    
    /// AppKit NSAlert version of `message`
    var informativeText : String? {
      set { message = newValue }
      get { return message }
    }
  }

#endif
