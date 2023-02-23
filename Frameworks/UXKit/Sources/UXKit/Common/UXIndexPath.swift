//
//  UXKit
//
//  Copyright © 2016-2017 ZeeZide GmbH. All rights reserved.
//
import Foundation

#if os(macOS)
  #if swift(>=4.0)
    // Hm. It does seem to have it (produces ambiguities). But maybe not.
    import AppKit
  #else
    public extension IndexPath {
    
      public init(row: Int, section: Int) {
        self.init(indexes: [ section, row ])
      }
      public var section : Int { return self[0] }
      public var row     : Int { return self[1] }
    }
  #endif
#endif

public extension IndexSet {
  
  init(range: NSRange) {
    self.init(integersIn: range.lowerBound..<range.upperBound)
  }

  static func setForRowsInPathes(_ ips: [ IndexPath ]) -> IndexSet {
    var set = IndexSet()
    for ip in ips { set.insert(ip[1] /* row */) }
    return set
  }
  
}
