//
//  UXKit
//
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//
#if os(macOS)
  import class Cocoa.NSPasteboard
  
  public typealias UXPasteboard = NSPasteboard
  
  public extension NSPasteboard {

    func canReadItem(withDataConformingToType type: NSPasteboard.PasteboardType)
         -> Bool
    {
      return canReadItem(withDataConformingToTypes: [ type.rawValue ])
    }

    func canReadItem(withDataConformingToTypes types:
                        [ NSPasteboard.PasteboardType ]) -> Bool
    {
      // The default function does not work w/ PasteboardType ...
      return canReadItem(withDataConformingToTypes: types.map { $0.rawValue })
    }
  }
#elseif !os(tvOS) // !os(macOS)
  import class UIKit.UIPasteboard
  
  public typealias UXPasteboard = UIPasteboard
  
  public extension UIPasteboard {
    
    typealias PasteboardType = String
    
    /**
     * Before you can provide new content to the pasteboard on AppKit, you need
     * to clear it.
     * Not quite sure why this doesn't exist on iOS? Are we supposed to reset
     * specific pasteboards?
     */
    @discardableResult
    func clearContents() -> Int {
      return changeCount
    }
  }
#endif // !os(macOS)
