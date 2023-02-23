//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import UIKit
  
  public typealias UXFont           = UIFont
  public typealias NSUnderlineStyle = UIKit.NSUnderlineStyle

  public extension UXFont {
    
    /**
     * macOS compat. Only works on iOS 13+ (otherwise returns nil).
     *
     * NOT: Calls into `UIFont.monospacedSystemFont()`.
     * `monospacedSystemFont` seems to render crap in UITextView on iOS 15?
     * Hence using "Menlo-Regular", and only if this is missing, fallback to
     * `UIFont.monospacedSystemFont()`.
     */
    static func userFixedPitchFont(ofSize size: CGFloat) -> UXFont? {
      if #available(iOS 13.0, *) {
        #if true
          return UIFont(name: "Menlo-Regular", size: size)
              ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #else
          return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
      }
      else {
        return nil
      }
    }
  }
#endif // !os(macOS)
